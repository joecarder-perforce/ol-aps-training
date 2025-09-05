# Example: stamp a single cluster 'so' in eu-south-1 (Milan
region      = "eu-south-1"
base_domain = "trng.lab"
ssh_key_name= "ocp-class"
admin_cidr  = "172.31.21.127/32" # jump box private IP/32

# Global tags (provider default_tags); 'customer=aps' is included by default.
common_tags = {
  customer = "aps"
  Project  = "OCP-Training"
}

# Update s0 and aps-student-00 to your assigned cluster and student number
clusters = {
  s0 = {
    vpc_cidr            = "10.38.0.0/16"
    public_subnet_cidrs = ["10.38.0.0/20","10.38.16.0/20","10.38.32.0/20"]
    rhcos_ami_id        = "ami-0dc93570c4163743d"
    ign_bootstrap_path  = "/home/aps-student-00/ocp-ign/s0/bootstrap.ign"
    ign_master_path     = "/home/aps-student-00//ocp-ign/s0/master.ign"
    enabled             = true
    extra_tags          = { Owner = "aps-student-00" }
  }

}
