# Example: stamp a single cluster 's1' in eu-south-1 (Milan), close to Malta
region      = "eu-south-1"
base_domain = "trng.lab"
ssh_key_name= "ocp-class"
admin_cidr  = "172.31.21.127/32" # jump box public IP/32

# Global tags (provider default_tags); 'customer=aps' is included by default.
common_tags = {
  customer = "aps"
  Project  = "OCP-Training"
}

clusters = {
  s0 = {
    vpc_cidr            = "10.38.0.0/16"
    public_subnet_cidrs = ["10.38.0.0/20","10.38.16.0/20","10.38.32.0/20"]
    ign_bootstrap_path  = "~/ocp-ign/s1/bootstrap.ign"
    ign_master_path     = "~/ocp-ign/s1/master.ign"
    enabled             = true
    extra_tags          = { Owner = "aps-student-00" }
  }

}
