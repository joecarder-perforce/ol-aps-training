locals {
  # Root-level defaults for instances/volumes (can be overridden per cluster)
  defaults = {
    instance_type_master       = "t3.xlarge"
    instance_type_bootstrap    = "t3.large"
    master_root_volume_size    = 140
    bootstrap_root_volume_size = 80
    rhcos_ami_id               = ""
    apps_lb_dns_name           = ""
  }

  active_clusters = { for k, v in var.clusters : k => v if try(v.enabled, true) }
}

module "cluster" {
  for_each = local.active_clusters
  source   = "./modules/ocp-compact"

  # Global
  region       = var.region
  base_domain  = var.base_domain
  ssh_key_name = var.ssh_key_name
  admin_cidr   = var.admin_cidr

  # Per-cluster
  cluster                    = each.key
  vpc_cidr                   = each.value.vpc_cidr
  public_subnet_cidrs        = each.value.public_subnet_cidrs
  metadata_json_path         = each.value.metadata_json_path
  ign_bootstrap_path         = each.value.ign_bootstrap_path
  ign_master_path            = each.value.ign_master_path
  instance_type_master       = coalesce(try(each.value.instance_type_master, null), local.defaults.instance_type_master)
  instance_type_bootstrap    = coalesce(try(each.value.instance_type_bootstrap, null), local.defaults.instance_type_bootstrap)
  master_root_volume_size    = coalesce(try(each.value.master_root_volume_size, null), local.defaults.master_root_volume_size)
  bootstrap_root_volume_size = coalesce(try(each.value.bootstrap_root_volume_size, null), local.defaults.bootstrap_root_volume_size)
  rhcos_ami_id               = coalesce(try(each.value.rhcos_ami_id, null), local.defaults.rhcos_ami_id)
  apps_lb_dns_name           = lookup(each.value, "apps_lb_dns_name", "")
  jump_vpc_id                = var.jump_vpc_id
  private_zone_id            = aws_route53_zone.private[each.key].zone_id

  # tags (merge global + per-cluster)
  tags = merge(var.common_tags, try(each.value.extra_tags, {}), { Cluster = each.key })
}
