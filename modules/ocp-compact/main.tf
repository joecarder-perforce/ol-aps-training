locals {
  zone_name = "${var.cluster}.${var.base_domain}"
}

# Ensure bucket names are globally unique by including account id
data "aws_caller_identity" "this" {}

locals {
  bucket_name = "ocp-${var.cluster}-ign-${var.region}-${data.aws_caller_identity.this.account_id}"
  tags_base   = merge(var.tags, { Name = var.cluster })
}

# ---------- Networking ----------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.tags_base, { Resource = "vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags_base, { Resource = "igw" })
}

data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_subnet" "public" {
  for_each                = { for idx, cidr in var.public_subnet_cidrs : idx => { cidr = cidr, az = data.aws_availability_zones.azs.names[idx] } }
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags                    = merge(local.tags_base, { Resource = "subnet", AZ = each.value.az })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags_base, { Resource = "rt-public" })
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

# ---------- Security ----------
resource "aws_security_group" "cluster" {
  name        = "${var.cluster}-sg"
  description = "OCP compact SG"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.tags_base, { Resource = "sg" })
}

resource "aws_security_group_rule" "intra_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cluster.id
  self              = true
}

resource "aws_security_group_rule" "ssh_admin" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.admin_cidr]
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "api_vpc" {
  type              = "ingress"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.this.cidr_block]
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "mcs_vpc" {
  type              = "ingress"
  from_port         = 22623
  to_port           = 22623
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.this.cidr_block]
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "web_vpc" {
  type              = "ingress"
  from_port         = 80
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.this.cidr_block]
  security_group_id = aws_security_group.cluster.id
}

# API from jump/admin
resource "aws_security_group_rule" "api_admin" {
  type              = "ingress"
  description       = "API from admin CIDR (jump)"
  from_port         = 6443
  to_port           = 6443
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = [var.admin_cidr]
}
# MCS from jump/admin (needed during bootstrap)
resource "aws_security_group_rule" "mcs_admin" {
  type              = "ingress"
  description       = "MCS from admin CIDR (jump)"
  from_port         = 22623
  to_port           = 22623
  protocol          = "tcp"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = [var.admin_cidr]
}

# etcd peer/client ports between masters
resource "aws_security_group_rule" "master_etcd_peer" {
  type                     = "ingress"
  description              = "etcd peer/client between masters"
  from_port                = 2379
  to_port                  = 2380
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

# ---------- S3 (Ignition) ----------
resource "aws_s3_bucket" "ign" {
  bucket = local.bucket_name
  tags   = merge(local.tags_base, { Resource = "s3-ign" })
}

resource "aws_s3_bucket_public_access_block" "ign" {
  bucket                  = aws_s3_bucket.ign.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "ign_public" {
  bucket = aws_s3_bucket.ign.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "PublicReadIgnition"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject"]
      Resource  = "${aws_s3_bucket.ign.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.ign]
}

resource "aws_s3_object" "bootstrap_ign" {
  bucket       = aws_s3_bucket.ign.id
  key          = "bootstrap.ign"
  source       = var.ign_bootstrap_path
  content_type = "application/json"
  tags         = merge(local.tags_base, { Resource = "s3obj-ign", Role = "bootstrap" })
}

resource "aws_s3_object" "master_ign" {
  bucket       = aws_s3_bucket.ign.id
  key          = "master.ign"
  source       = var.ign_master_path
  content_type = "application/json"
  tags         = merge(local.tags_base, { Resource = "s3obj-ign", Role = "master" })
}

locals {
  s3_bootstrap_url = "https://${aws_s3_bucket.ign.bucket}.s3.${var.region}.amazonaws.com/${aws_s3_object.bootstrap_ign.key}"
  s3_master_url    = "https://${aws_s3_bucket.ign.bucket}.s3.${var.region}.amazonaws.com/${aws_s3_object.master_ign.key}"
}

# ---------- UserData (Ignition wrapper via templatefile) ----------
locals {
  bootstrap_user_data_b64 = base64encode(templatefile("${path.module}/templates/ignition_wrapper.json.tpl", { source_url = local.s3_bootstrap_url }))
  master_user_data_b64    = base64encode(templatefile("${path.module}/templates/ignition_wrapper.json.tpl", { source_url = local.s3_master_url }))
}

# ---------- AMI (RHCOS) ----------
data "aws_ami" "rhcos" {
  count       = var.rhcos_ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["125523088429"] # Red Hat
  filter {
    name   = "name"
    values = ["rhcos*${var.region}*x86_64*"]
  }
}

locals {
  rhcos_ami = var.rhcos_ami_id != "" ? var.rhcos_ami_id : data.aws_ami.rhcos[0].id
}

# ---------- Load Balancing (API + MCS) ----------
resource "aws_lb" "api_mcs" {
  name               = "${var.cluster}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = merge(local.tags_base, { Resource = "nlb" })
}

resource "aws_lb_target_group" "api" {
  name        = "${var.cluster}-tg-api"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"
  health_check {
    protocol = "TCP"
    port     = "6443"
  }
  tags = merge(local.tags_base, { Resource = "tg", Port = "6443" })
}

resource "aws_lb_target_group" "mcs" {
  name        = "${var.cluster}-tg-mcs"
  port        = 22623
  protocol    = "TCP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"
  health_check {
    protocol = "TCP"
    port     = "22623"
  }
  tags = merge(local.tags_base, { Resource = "tg", Port = "22623" })
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api_mcs.arn
  port              = 6443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_listener" "mcs" {
  load_balancer_arn = aws_lb.api_mcs.arn
  port              = 22623
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mcs.arn
  }
}

# ---------- EC2 Instances ----------
resource "aws_instance" "bootstrap" {
  ami                         = local.rhcos_ami
  instance_type               = var.instance_type_bootstrap
  subnet_id                   = values(aws_subnet.public)[0].id
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name
  credit_specification { cpu_credits = "unlimited" }
  user_data_base64 = local.bootstrap_user_data_b64

  root_block_device {
    volume_size = var.bootstrap_root_volume_size
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }

  tags = merge(local.tags_base, { Resource = "ec2", Role = "bootstrap" })
}

resource "aws_instance" "master" {
  count                       = 3
  ami                         = local.rhcos_ami
  instance_type               = var.instance_type_master
  subnet_id                   = element(values(aws_subnet.public)[*].id, count.index)
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name
  credit_specification { cpu_credits = "unlimited" }
  user_data_base64 = local.master_user_data_b64

  root_block_device {
    volume_size = var.master_root_volume_size
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }

  tags = merge(local.tags_base, { Resource = "ec2", Role = "master", Index = tostring(count.index + 1) })
}

# Attach masters to NLB target groups
resource "aws_lb_target_group_attachment" "api_attach" {
  count            = length(aws_instance.master)
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = aws_instance.master[count.index].id
  port             = 6443
}

resource "aws_lb_target_group_attachment" "mcs_attach" {
  count            = length(aws_instance.master)
  target_group_arn = aws_lb_target_group.mcs.arn
  target_id        = aws_instance.master[count.index].id
  port             = 22623
}

# Let masters fetch Ignition from bootstrap MCS during bootstrap phase
resource "aws_lb_target_group_attachment" "mcs_attach_bootstrap" {
  target_group_arn = aws_lb_target_group.mcs.arn
  target_id        = aws_instance.bootstrap.id
  port             = 22623
}

# ---------- DNS (Private) ----------
resource "aws_route53_zone" "private" {
  name = local.zone_name
  vpc { vpc_id = aws_vpc.this.id }
  lifecycle {
    ignore_changes = [vpc] # Avoid Route53 association churn; manage extra VPCs via aws_route53_zone_association
  }
  force_destroy = true
  tags          = merge(local.tags_base, { Resource = "r53-zone" })
}

resource "aws_route53_zone_association" "jump" {
  count      = var.jump_vpc_id == "" || var.jump_vpc_id == null ? 0 : 1
  zone_id    = aws_route53_zone.private.zone_id
  vpc_id     = var.jump_vpc_id
  vpc_region = var.region
}

resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "api.${local.zone_name}"
  type    = "A"
  alias {
    name                   = aws_lb.api_mcs.dns_name
    zone_id                = aws_lb.api_mcs.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api_int" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "api-int.${local.zone_name}"
  type    = "A"
  alias {
    name                   = aws_lb.api_mcs.dns_name
    zone_id                = aws_lb.api_mcs.zone_id
    evaluate_target_health = false
  }
}

# Optional: create *.apps once you know the router LB DNS name
resource "aws_route53_record" "apps_wildcard" {
  count   = var.apps_lb_dns_name != null && var.apps_lb_dns_name != "" ? 1 : 0
  zone_id = aws_route53_zone.private.zone_id
  name    = "*.apps.${local.zone_name}"
  type    = "CNAME"
  ttl     = 60
  records = [var.apps_lb_dns_name]
}
