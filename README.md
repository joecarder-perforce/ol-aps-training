# OpenShift on AWS (UPI) — Lab Runbook (dns-fix-03)

## 0) Environment

```bash
export BASE_DOMAIN=trng.lab
export CLUSTER=s0
export AWS_REGION=eu-south-1
export AWS_DEFAULT_REGION="$AWS_REGION"

export WORKDIR=~/ocp-ign/$CLUSTER

mkdir -p "$WORKDIR"

export OPENSHIFT_INSTALL_SSH_PUB_KEY="$(cat ~/.ssh/ocp-class.pub)"
export KUBECONFIG="$WORKDIR/auth/kubeconfig"

git clone https://github.com/joecarder-perforce/ol-aps-training.git
```
Edit .aws/credntials




Initialize Tofu in the repo (once per clone):
```bash
cd ~/ol-aps-training
tofu init
```
edit the terraform.tfvars file  to reflect your user and cluster names, and increment the cidr valudes to avoid conflicts
```bash
clusters = {
  cluster-name = {
    vpc_cidr            = "10.38.0.0/16"
    public_subnet_cidrs = ["10.38.0.0/20", "10.38.16.0/20", "10.38.32.0/20"]
    rhcos_ami_id        = "ami-0dc93570c4163743d"
    ign_bootstrap_path  = "/home/your student name/ocp-ign/{cluster-name}/bootstrap.ign"
    ign_master_path     = "/home/your student name/ocp-ign/{cluster-name}/master.ign"
    metadata_json_path  = "/home/your student name/ocp-ign/{cluster-name}/metadata.json"
    enabled             = true
    extra_tags          = { Owner = "your student name" }
```

---

## 1) Create install-config (students run this)

Recommended command **options**:
```bash
openshift-install create install-config \
  --dir "$WORKDIR" \
  --log-level=info
```

During the interactive prompts pick **AWS**, region **eu-south-1**, base domain **trng.lab**, cluster name **$CLUSTER**, paste **pull-secret**, and include your **SSH public key**.

**Manual edit (required):**
```bash
vi "$WORKDIR/install-config.yaml"
```
Set:
- `compute[0].replicas: 0`  ← **no workers** (compact/3-node)

> When workers = 0, the installer will set **mastersSchedulable: true** automatically in `cluster-scheduler-02-config.yml`. No extra field needed in `install-config.yaml`.

---

## 2) Create manifests

```bash
openshift-install create manifests --dir "$WORKDIR"
```

---

Tofu creates custom manifests:
```
$WORKDIR/manifests/00-cco-credentials-mode.yaml
```
with:
```yaml
apiVersion: operator.openshift.io/v1
kind: CloudCredential
metadata:
  name: cluster
spec:
  credentialsMode: Passthrough
```
## 2.a) Apply custom manifest before ignition (be sure to replace "s0" with your cluster name

Apply via targeted Tofu **before ignition**:
```bash
tofu apply \
  -target='module.cluster["s0"].null_resource.ensure_manifests_dir' \
  -target='module.cluster["s0"].local_file.cco_passthrough_cr' \
  -auto-approve
```

---

## 4) Create ignition

```bash
openshift-install create ignition-configs --dir "$WORKDIR"
```

---

## 5) Infra with Tofu (creates/tag/associates PHZ, VPC/NLB/EC2, etc.)

Then push full infra:
```bash
tofu apply -auto-approve
```

> TF tags the PHZ with `Name=<infraID>-int` and `kubernetes.io/cluster/<infraID>=owned` **and** associates it to the **cluster VPC** (so in‑cluster DNS can resolve).

---

## 6) Wait for cluster

```bash
openshift-install wait-for bootstrap-complete --dir "$WORKDIR" --log-level=info
openshift-install wait-for install-complete   --dir "$WORKDIR" --log-level=info
```

## IAM quick notes (DNS path)

- Master node role must allow `route53:ChangeResourceRecordSets` on **private** zone ARN and **public** zone ARN (if public apps kept).
- Route53 read (`List*`/`Get*`) can be broad.
- ELBv2 lifecycle includes `elasticloadbalancing:ModifyListener`.
- CCM read‑only includes `ec2:DescribeAddresses`, `ec2:DescribeNatGateways`, `ec2:DescribeNetworkInterfaces`.

---

## Troubleshooting cheats

- **Credentials requests failing** → ensure day‑1 **CloudCredential CR** sets `credentialsMode: Passthrough`.
- **NXDOMAIN in pods** but records exist in Route53 → **PHZ not associated** to the **cluster VPC**; add association (your TF does this now).
- **Ingress canary failing** → curl `https://<canary-host>/healthz` from a pod; if switching scope, delete `svc/router-default` to re‑LB.
- **CoreDNS cache lag** → restart DNS pods:  
  `oc -n openshift-dns delete pod -l dns.operator.openshift.io/daemonset-dns=default`

---

## Teardown

Use the script below (download separately), then optionally purge the WORKDIR:
```bash
chmod +x destroy.sh
./destroy.sh --force-zone --purge-workdir
```
