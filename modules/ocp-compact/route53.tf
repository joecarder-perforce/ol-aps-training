# variables you’ll use below:
# var.cluster (e.g., "s0")
# var.base_domain (e.g., "trng.lab")
# var.jump_vpc_id (optional; null if not used)

resource "aws_route53_zone" "private" {
  name = "${var.cluster}.${var.base_domain}"
  vpc {
    vpc_id = aws_vpc.cluster.id
  }
  comment      = "Private zone for ${var.cluster}"
  force_destroy = true
}

# Optional second association for the jump VPC (same account)
resource "aws_route53_zone_association" "jump" {
  count   = var.jump_vpc_id == null ? 0 : 1
  zone_id = aws_route53_zone.private.zone_id
  vpc_id  = var.jump_vpc_id
}

# Assumes aws_lb.api (internal NLB) already exists
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "api.${var.cluster}.${var.base_domain}"
  type    = "A"
  alias {
    name                   = aws_lb.api.dns_name
    zone_id                = aws_lb.api.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "api_int" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "api-int.${var.cluster}.${var.base_domain}"
  type    = "A"
  alias {
    name                   = aws_lb.api.dns_name
    zone_id                = aws_lb.api.zone_id
    evaluate_target_health = false
  }
}