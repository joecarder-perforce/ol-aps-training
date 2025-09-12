variable "region" {
  type = string
}

variable "base_domain" {
  type = string
}

variable "cluster" {
  description = "Short cluster slug used in names and DNS (e.g., s0)"
  type        = string
}

variable "ssh_key_name" {
  type = string
}

variable "admin_cidr" {
  type = string
}

variable "jump_vpc_id" {
  type    = string
  default = null
}

variable "jump_cidr" {
  type    = string
  default = null
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "ign_bootstrap_path" {
  type = string
}

variable "ign_master_path" {
  type = string
}

variable "instance_type_master" {
  type = string
}

variable "instance_type_bootstrap" {
  type = string
}

variable "metadata_json_path" {
  description = "Path to OpenShift metadata.json. If present, infraID is read from it."
  type        = string
  default     = ""
}

variable "infra_id" {
  description = "OpenShift infrastructure ID from metadata.json (e.g., s0-abcde). If empty, falls back to var.cluster."
  type        = string
  default     = ""
}

variable "private_zone_id" {
  description = "Route53 private hosted zone ID for ${var.cluster}.${var.base_domain} (no /hostedzone/ prefix)."
  type        = string
}

variable "master_root_volume_size" {
  type = number
}

variable "bootstrap_root_volume_size" {
  type = number
}

variable "rhcos_ami_id" {
  type    = string
  default = ""
}

variable "apps_lb_dns_name" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
