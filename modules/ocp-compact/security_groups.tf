# Masters SG (used by masters and bootstrap if you share SG)
resource "aws_security_group" "masters" {
  name   = "${var.cluster}-masters"
  vpc_id = aws_vpc.cluster.id
  tags   = { Cluster = var.cluster, Role = "masters" }
}

# etcd (masters ↔ masters)
resource "aws_security_group_rule" "masters_etcd_self" {
  type                     = "ingress"
  security_group_id        = aws_security_group.masters.id
  protocol                 = "tcp"
  from_port                = 2379
  to_port                  = 2380
  source_security_group_id = aws_security_group.masters.id
}

# kube-apiserver (VPC → masters @ 6443)
resource "aws_security_group_rule" "masters_api_vpc" {
  type              = "ingress"
  security_group_id = aws_security_group.masters.id
  protocol          = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_blocks       = [aws_vpc.cluster.cidr_block]
}

# MCS (VPC → masters/bootstrap @ 22623)
resource "aws_security_group_rule" "masters_mcs_vpc" {
  type              = "ingress"
  security_group_id = aws_security_group.masters.id
  protocol          = "tcp"
  from_port         = 22623
  to_port           = 22623
  cidr_blocks       = [aws_vpc.cluster.cidr_block]
}

# Egress (allow all)
resource "aws_security_group_rule" "masters_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.masters.id
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
