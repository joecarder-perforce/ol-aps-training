# root/dns_lookup.tf
data "aws_route53_zone" "private" {
  for_each     = local.active_clusters
  name         = "${each.key}.${var.base_domain}."
  private_zone = true
}