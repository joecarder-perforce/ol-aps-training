variable "region" {
  description = "AWS region (EU close to Malta: eu-south-1, eu-south-2, eu-central-1, eu-west-1, etc.)"
  type        = string
  default     = "eu-south-1"
}

variable "base_domain" {
  description = "Training suffix (e.g., lab)"
  type        = string
  default     = "lab"
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH (e.g., jump box public IP/32)"
  type        = string
}

variable "common_tags" {
  description = "Global tags (should include customer = aps)"
  type        = map(string)
  default = {
    customer = "aps"
    Project  = "OCP-Training"
  }
}

# Map of clusters to create. Each entry points at its Ignition files & networking
variable "clusters" {
  description = <<EOT
Map of clusters:
  clusters = {
    s1 = {
      vpc_cidr            = "10.38.0.0/16"
      public_subnet_cidrs = ["10.38.0.0/20","10.38.16.0/20","10.38.32.0/20"]
      ign_bootstrap_path  = "/abs/path/s1/bootstrap.ign"
      ign_master_path     = "/abs/path/s1/master.ign"
      # Optional overrides:
      instance_type_master       = "t3.xlarge"
      instance_type_bootstrap    = "t3.large"
      master_root_volume_size    = 140
      bootstrap_root_volume_size = 80
      rhcos_ami_id               = ""     # pin AMI if you want stability
      apps_lb_dns_name           = ""     # set after router LB appears to create *.apps CNAME
      enabled                    = true   # toggle without destroying
      extra_tags                 = { Owner = "student1" }
    }
  }
EOT
  type = map(object({
    vpc_cidr                   = string
    public_subnet_cidrs        = list(string)
    ign_bootstrap_path         = string
    ign_master_path            = string
    instance_type_master       = optional(string)
    instance_type_bootstrap    = optional(string)
    master_root_volume_size    = optional(number)
    bootstrap_root_volume_size = optional(number)
    rhcos_ami_id               = optional(string)
    apps_lb_dns_name           = optional(string)
    enabled                    = optional(bool)
    extra_tags                 = optional(map(string))
  }))
}
