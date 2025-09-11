# modules/ocp-compact/iam.tf

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
    ]
    resources = ["*"]
  }
}

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

resource "aws_iam_role_policy" "master_readonly" {
  name   = "${var.cluster}-master-ccm-readonly"
  role   = aws_iam_role.master.id
  policy = data.aws_iam_policy_document.ccm_readonly.json
}
