# Use the existing metadata_json_path to derive the installer WORKDIR
locals {
  workdir     = dirname(var.metadata_json_path)
  apps_domain = "apps.${var.cluster}.${var.base_domain}"
}

# Ensure the manifests directory exists
resource "null_resource" "ensure_manifests_dir" {
  triggers = {
    path = "${local.workdir}/manifests"
  }

  provisioner "local-exec" {
    command = "mkdir -p ${local.workdir}/manifests"
  }
}

# 1) DNS operator: point to your private Route53 zone (lets OCP manage records)
resource "local_file" "dns_private_zone" {
  filename = "${local.workdir}/manifests/zz-01-dns-private-zone.yaml"
  content  = <<-YAML
    apiVersion: operator.openshift.io/v1
    kind: DNS
    metadata:
      name: default
    spec:
      privateZone:
        id: ${var.private_zone_id}
  YAML

  depends_on = [null_resource.ensure_manifests_dir]
}

# 2) Default IngressController: internal NLB and apps domain
resource "local_file" "ingress_default" {
  filename = "${local.workdir}/manifests/zz-02-ingress-default-internal.yaml"
  content  = <<-YAML
    apiVersion: operator.openshift.io/v1
    kind: IngressController
    metadata:
      name: default
      namespace: openshift-ingress-operator
    spec:
      domain: ${local.apps_domain}
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