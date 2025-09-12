# root/dns_zone.tf
resource "aws_route53_zone" "private" {
  for_each = local.active_clusters

  name = "${each.key}.${var.base_domain}" # e.g. s0.trng.lab

  # AWS requires at least one VPC association at create time
  vpc {
    vpc_id = var.jump_vpc_id
  }

  comment = "Private zone for ${each.key}.${var.base_domain}"
  tags = merge(var.common_tags, try(each.value.extra_tags, {}), {
    Cluster  = each.key
    Resource = "route53-private-zone"
  })
}