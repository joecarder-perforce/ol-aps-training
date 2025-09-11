# EC2 trust so instances can assume the role
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

# Read-only EC2 describes used widely (incl. CCM)
data "aws_iam_policy_document" "ccm_readonly" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeRouteTables",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeInternetGateways",
    ]
    resources = ["*"]
  }
}

# ELBv2 + supporting EC2/IAM calls needed for Service type=LoadBalancer (router)
data "aws_iam_policy_document" "ccm_elbv2" {
  # ELBv2 lifecycle + describe
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancerPolicy",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DeleteLoadBalancerPolicy",
      "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
      "elasticloadbalancing:CreateLoadBalancerListeners",
      "elasticloadbalancing:DeleteLoadBalancerListeners",
      "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
      "elasticloadbalancing:ConfigureHealthCheck",
    ]
    resources = ["*"]
  }

  # Service-linked role creation (first time per account/region)
  statement {
    effect    = "Allow"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

  # Supporting EC2 calls the controller uses while wiring the LB
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = ["*"]
  }
}

# ----- Role & instance profile for masters -----

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

# Attach policies to the master role
resource "aws_iam_role_policy" "master_readonly" {
  name   = "${var.cluster}-master-ccm-readonly"
  role   = aws_iam_role.master.id
  policy = data.aws_iam_policy_document.ccm_readonly.json
}

resource "aws_iam_role_policy" "master_elbv2" {
  name   = "${var.cluster}-master-elbv2"
  role   = aws_iam_role.master.id
  policy = data.aws_iam_policy_document.ccm_elbv2.json
}