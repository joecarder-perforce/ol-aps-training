# Look up the existing *base* private zone (e.g., trng.lab.)
data "aws_route53_zone" "private" {
  name         = "${var.base_domain}."
  private_zone = true
}