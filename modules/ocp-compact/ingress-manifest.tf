# Use the existing metadata_json_path to derive the installer WORKDIR
locals {
  workdir = dirname(var.metadata_json_path)
}

# Ensure the manifests directory exists so openshift-install will pick them up
resource "null_resource" "ensure_manifests_dir" {
  triggers = { path = "${local.workdir}/manifests" }
  provisioner "local-exec" {
    command = "mkdir -p ${local.workdir}/manifests"
  }
}

# --- CCO Passthrough so operators use node IAM to manage Route53 ---
resource "local_file" "cco_passthrough" {
  filename = "${local.workdir}/manifests/00-cco-passthrough.yaml"
  content  = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-credential-operator-config
  namespace: openshift-cloud-credential-operator
data:
  mode: Passthrough
YAML

  depends_on = [null_resource.ensure_manifests_dir]
}



# --- IngressController: internal NLB; keep default apps domain (no spec.domain) ---
resource "local_file" "ingress_default" {
  filename = "${local.workdir}/manifests/zz-02-ingresscontroller.yaml"
  content  = <<YAML
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  name: default
  namespace: openshift-ingress-operator
spec:
  endpointPublishingStrategy:
    type: LoadBalancerService
    loadBalancer:
      scope: Internal
      providerParameters:
        type: AWS
        aws:
          type: NLB
YAML

  depends_on = [null_resource.ensure_manifests_dir]
}
