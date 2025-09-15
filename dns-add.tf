# root/dns_zone.tf
## Derive infraID per cluster from the installer's metadata.json
## (metadata.json exists by the time you run the full tofu apply)
locals {
  meta_by_cluster = {
    for k, v in var.clusters :
    k => jsondecode(file(v.metadata_json_path))
  }
  infra_id_by_cluster = {
    for k, m in local.meta_by_cluster :
    k => m.infraID
  }
}

resource "aws_route53_zone" "private" {
  for_each = local.active_clusters

  name = "${each.key}.${var.base_domain}" # e.g. s0.trng.lab

  # AWS requires at least one VPC association at create time
  vpc {
    vpc_id = var.jump_vpc_id
  }

  comment = "Private zone for ${each.key}.${var.base_domain}"
  tags = merge(
    var.common_tags,
    try(each.value.extra_tags, {}),
    {
      Cluster                                                                                       = each.key
      Resource                                                                                      = "route53-private-zone"
      Name                                                                                          = "${coalesce(try(local.infra_id_by_cluster[each.key], null), each.key)}-int"
      "kubernetes.io/cluster/${coalesce(try(local.infra_id_by_cluster[each.key], null), each.key)}" = "owned"
    }
  )
}