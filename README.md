# OCP 4.19 Compact UPI on AWS (EU) — Multi-Cluster Module

Minimal, production-ish OpenTofu/Terraform to stamp **compact** OpenShift 4.19 clusters on AWS:
- **Masters-as-workers** (3 control-plane, 0 workers; masters schedulable)
- **Private Route 53** zone per cluster (`<name>.lab`) — internal access via jump box/VPC
- **Internal NLB**: API **6443** and MCS **22623**
- **T3 Unlimited** instances (`t3.large` bootstrap, `t3.xlarge` masters)
- All resources tagged with `customer=aps` (via provider `default_tags` + per-resource tags)
- Default region: **eu-south-1** (Milan), close to Malta

> You can deploy **one cluster now** and add more later by appending entries to `clusters` and running `tofu apply` again.

---

## Prereqs

- OpenTofu/Terraform (>= 1.5)
- AWS credentials with permissions for EC2, ELBv2, Route53, S3, IAM instance profile usage
- `openshift-install` and `oc` 4.19 on your jump box
- An EC2 key pair name (`ssh_key_name`) for optional SSH

## Generate Ignition (per cluster)

```bash
mkdir -p ~/ocp-ign/s1
cd ~/ocp-ign/s1
openshift-install create manifests --dir .
# compact: make masters schedulable
sed -i '' 's/mastersSchedulable: false/mastersSchedulable: true/' manifests/cluster-scheduler-02-config.yml
openshift-install create ignition-configs --dir .
```

## Configure & apply

1) Copy `terraform.tfvars.example` to `terraform.tfvars`, edit paths & IPs.
2) Init and apply:
```bash
tofu init
tofu apply
```

## After bootstrap completes

- Remove the bootstrap instance (manually today).
- Create `*.apps.<cluster>.lab` once the ingress router LB exists:
  ```bash
  # get LB DNS name
  oc -n openshift-ingress get svc router-default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
  # add to terraform.tfvars under the specific cluster:
  #   apps_lb_dns_name = "<router-lb-hostname>"
  # then apply again
  tofu apply
  ```

## Add clusters later

Append new entries to `clusters` in `terraform.tfvars` and `tofu apply`. To remove one, set `enabled = false` or delete its entry and apply.

## Pin the RHCOS AMI (recommended)

For reproducibility, set `rhcos_ami_id` in each cluster entry. If left empty, the module tries to discover an appropriate RHCOS AMI via `aws_ami` data source, which can drift over time.

## Region choices

Defaults to `eu-south-1` (Milan). Alternatives: `eu-south-2` (Spain), `eu-central-1` (Frankfurt), `eu-west-1` (Ireland).

---

## Outputs

- `api_endpoints` — per-cluster API URLs
- `nlb_dns` — per-cluster internal NLB DNS name
- `private_zone_ids` — per-cluster Route53 private zone ids
