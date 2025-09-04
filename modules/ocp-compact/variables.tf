variable "region" { type = string }
variable "base_domain" { type = string }
variable "cluster_name" { type = string }
variable "ssh_key_name" { type = string }
variable "admin_cidr" { type = string }

variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }

variable "ign_bootstrap_path" { type = string }
variable "ign_master_path" { type = string }

variable "instance_type_master" { type = string }
variable "instance_type_bootstrap" { type = string }

variable "master_root_volume_size" { type = number }
variable "bootstrap_root_volume_size" { type = number }

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
