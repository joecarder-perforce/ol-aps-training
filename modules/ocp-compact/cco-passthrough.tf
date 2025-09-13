# Minimal, correct day-1 manifest to force CCO Passthrough on OCP 4.19+

locals {
  # Use the installer metadata.json path you already pass to the module
  workdir = dirname(var.metadata_json_path)
}

# Ensure the manifests directory exists so openshift-install will pick them up
resource "null_resource" "ensure_manifests_dir" {
  triggers = { path = "${local.workdir}/manifests" }
  provisioner "local-exec" {
    command = "mkdir -p ${local.workdir}/manifests"
  }
}

# Authoritative switch: set CloudCredential CR to Passthrough
resource "local_file" "cco_passthrough_cr" {
  filename   = "${local.workdir}/manifests/00-cco-credentials-mode.yaml"
  content    = <<YAML
apiVersion: operator.openshift.io/v1
kind: CloudCredential
metadata:
  name: cluster
spec:
  credentialsMode: Passthrough
YAML
  depends_on = [null_resource.ensure_manifests_dir]
}