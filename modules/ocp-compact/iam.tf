# --- Trust policy for EC2 instances (unchanged) ---
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# --- Read/Describe + basic EC2 edits used by the KCM service-controller ---
data "aws_iam_policy_document" "ccm_readonly" {
  statement {
    effect = "Allow"
    actions = [
      # EC2 discovery
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",

      # SG + Tag management sometimes used with LB wiring
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }
}

# --- Route53 perms for ingress-operator DNS management (zone-scoped) ---
# If you prefer to keep it generic first time, set the resource to ["*"]
# and tighten to the hosted zone ARN later.
data "aws_iam_policy_document" "master_route53" {
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ListHostedZonesByVPC",
      "route53:ListResourceRecordSets",
      "route53:GetHostedZone",
      "route53:GetChange",
    ]
    resources = ["*"] # or ["arn:aws:route53:::hostedzone/${var.apps_private_zone_id}"]
  }
}

resource "aws_iam_role_policy" "master_route53" {
  name   = "${var.cluster}-master-route53"
  role   = aws_iam_role.master.id
  policy = data.aws_iam_policy_document.master_route53.json
}

# --- Full ELB (classic) + ELBv2 set for Service type=LoadBalancer from Ingress ---
data "aws_iam_policy_document" "master_elb" {
  statement {
    sid    = "ClassicELB"
    effect = "Allow"
    actions = [
      # Classic ELB lifecycle
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:DescribeTags",

      # Classic ELB health checks & registration
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:DescribeInstanceHealth",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",

      # Classic ELB listeners & backend policies (needed for proxy protocol, etc.)
      "elasticloadbalancing:CreateLoadBalancerListeners",
      "elasticloadbalancing:DeleteLoadBalancerListeners",
      "elasticloadbalancing:CreateLoadBalancerPolicy",
      "elasticloadbalancing:DeleteLoadBalancerPolicy",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ELBv2NLB"
    effect = "Allow"
    actions = [
      # ELBv2 lifecycle
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:DescribeTags",

      # Listeners
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DescribeListeners",

      # Target groups
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetHealth",
    ]
    resources = ["*"]
  }

  # Service-linked role for ELB if it doesn't exist yet
  statement {
    sid       = "ELBServiceLinkedRole"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }
}

# --- Role & Instance Profile (unchanged names) ---
resource "aws_iam_role" "master" {
  name               = "${var.cluster}-master-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = merge(local.tags_base, { Resource = "iam-role-master" })
}

resource "aws_iam_instance_profile" "master" {
  name = "${var.cluster}-master-profile"
  role = aws_iam_role.master.name
  tags = merge(local.tags_base, { Resource = "iam-instance-profile-master" })
}

# --- Attach policies to the role (existing, unchanged) ---
resource "aws_iam_role_policy" "master_readonly" {
  name   = "${var.cluster}-master-ccm-readonly"
  role   = aws_iam_role.master.id
  policy = data.aws_iam_policy_document.ccm_readonly.json
}

resource "aws_iam_role_policy" "master_elb" {
  name   = "${var.cluster}-master-elb"
  role   = aws_iam_role.master.id
  policy = data.aws_iam_policy_document.master_elb.json
}

# --- Extra ELB permissions (additive-only; keeps existing policies untouched) ---
data "aws_iam_policy_document" "master_elb_extra" {
  statement {
    sid    = "ELBAllExtra"
    effect = "Allow"
    actions = [
      # Classic ELB lifecycle
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:DescribeTags",

      # Classic ELB health checks & registration
      "elasticloadbalancing:ConfigureHealthCheck",
      "elasticloadbalancing:DescribeInstanceHealth",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",

      # Classic ELB listeners & backend policies
      "elasticloadbalancing:CreateLoadBalancerListeners",
      "elasticloadbalancing:DeleteLoadBalancerListeners",
      "elasticloadbalancing:CreateLoadBalancerPolicy",
      "elasticloadbalancing:DeleteLoadBalancerPolicy",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",

      # ELBv2 (NLB/ALB) lifecycle
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DescribeListeners",

      # ELBv2 target groups
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetHealth",
    ]
    resources = ["*"]
  }

  # Service-linked role for ELB (harmless if it already exists)
  statement {
    sid       = "ELBServiceLinkedRoleExtra"
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "master_elb_extra" {
  name   = "${var.cluster}-master-elb-extra"
  role   = aws_iam_role.master.id
  policy = data.aws_iam_policy_document.master_elb_extra.json
}
