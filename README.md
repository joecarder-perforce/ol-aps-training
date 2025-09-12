# OCP 4.19 on AWS (UPI) — Student Runbook

This runbook walks you end‑to‑end through bringing up a compact (3‑node) OpenShift Container Platform 4.19 cluster on AWS using **UPI + OpenTofu**.

> **Preset for this class**
> - Environment variables are already exported in your `~/.bash_profile`:
>   - `BASE_DOMAIN=trng.lab`
>   - `CLUSTER=s0`
>   - `AWS_REGION=eu-south-1` (also `AWS_DEFAULT_REGION`)
>   - `WORKDIR=~/ocp-ign/$CLUSTER`
>   - `OPENSHIFT_INSTALL_SSH_PUB_KEY` is set to your `~/.ssh/ocp-class.pub`
>   - `TF_VAR_metadata_json_path="$WORKDIR/metadata.json"`
>   - `KUBECONFIG="$WORKDIR/auth/kubeconfig"`
> - Tools already installed on the jump host: `openshift-install`, `oc`, `awscli`, `tofu` (OpenTofu), `jq`, `dig`.
> - The training repo (Terraform code) is already checked out on the jump host.

---

## 0) Quick start (TL;DR)

```bash
# 1) Create install-config via wizard (platform=aws)
mkdir -p "$WORKDIR"
cd "$WORKDIR"
openshift-install create install-config --dir "$WORKDIR"
  a) SSH Public Key
  Select: /home/aps-student-00/.ssh/ocp-class.pub
  b) Platform
  Select: aws
  c) Region
  Select: eu-south-1
  d) Base Domain
  Enter: trng.lab
  e) Cluster Name
Enter: \s#` — the last digit of your APS student account (e.g., `aps-student-00` ⇒ `s0`)`
  f) Pull Secret
  Paste the pull secret from ~/pull-secret (entire file contents on a single line).

# 2) Render ignition
openshift-install create ignition-configs --dir "$WORKDIR"

# 3) Deploy infra with OpenTofu (run from the repo root)
cd ~/ol-aps-training
tofu init
tofu validate
tofu plan
tofu apply -auto-approve

# 4) Wait for bootstrap to complete
openshift-install wait-for bootstrap-complete --dir "$WORKDIR" --log-level=info

# 5) Remove bootstrap (Terraform target destroy)
cd ~/ol-aps-training
BOOT_ADDR=$(tofu state list | grep -m1 "aws_instance.bootstrap")
[ -n "$BOOT_ADDR" ] && tofu destroy -target "$BOOT_ADDR" -auto-approve || true

# 6) Create *.apps DNS ALIAS (private zone) to router ELB
HZ_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${CLUSTER}.${BASE_DOMAIN}." \
  --query 'HostedZones[?Config.PrivateZone==`true`].Id' --output text | sed 's|/hostedzone/||')
ROUTER_DNS=$(oc -n openshift-ingress get svc router-default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ROUTER_HZ=$(aws elb describe-load-balancers \
  --query "LoadBalancerDescriptions[?DNSName=='${ROUTER_DNS}'].CanonicalHostedZoneNameID" --output text)

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HZ_ID" \
  --change-batch "$(jq -n \
    --arg name "*.apps.${CLUSTER}.${BASE_DOMAIN}." \
    --arg dns  "$ROUTER_DNS" \
    --arg hz   "$ROUTER_HZ" \
    '{Comment:"Alias *.apps to router ELB",Changes:[{Action:"UPSERT",ResourceRecordSet:{Name:$name,Type:"A",AliasTarget:{HostedZoneId:$hz,DNSName:$dns,EvaluateTargetHealth:false}}}] }')"

# 7) Verify
oc get nodes
oc get co
```

---

## 1) Prepare the install assets

1. Create the working directory and run the wizard:
   ```bash
   mkdir -p "$WORKDIR" && cd "$WORKDIR"
   openshift-install create install-config --dir "$WORKDIR"
   ```
   - Choose **platform: aws** (not `none`).
   - The SSH key is injected from `OPENSHIFT_INSTALL_SSH_PUB_KEY`.

2. Render ignition configs:
   ```bash
   openshift-install create ignition-configs --dir "$WORKDIR"
   ```
   This writes `bootstrap.ign`, `master.ign`, and `metadata.json` into `$WORKDIR`. Terraform reads `metadata.json` via `TF_VAR_metadata_json_path`.

---

## 2) Deploy AWS infrastructure (OpenTofu)

> Run these from the **repo root** (e.g., `~/ol-aps-training`).

```bash
cd ~/ol-aps-training

# Initialize providers/modules
tofu init

# Sanity check the configuration
tofu validate

# Review the plan
tofu plan

# Apply (this creates VPC, subnets, SGs, NLB, Route53 private zone, IAM, EC2, etc.)
tofu apply -auto-approve
```

**Useful outputs/derivations**
```bash
# Infra ID for this cluster
INFRA_ID=$(jq -r .infraID "$WORKDIR/metadata.json")

echo "INFRA_ID=$INFRA_ID"
```

---

## 3) Watch bootstrap & control plane come up

### ELB/NLB target health
```bash
# Target group ARNs (names are created by Terraform):
API_TG_ARN=$(aws elbv2 describe-target-groups --names "${CLUSTER}-tg-api" --query 'TargetGroups[0].TargetGroupArn' --output text)
MCS_TG_ARN=$(aws elbv2 describe-target-groups --names "${CLUSTER}-tg-mcs" --query 'TargetGroups[0].TargetGroupArn' --output text)

# Health (bootstrap should be healthy for mcs; masters healthy for both as they progress)
aws elbv2 describe-target-health --target-group-arn "$API_TG_ARN" --query 'TargetHealthDescriptions[].{Id:Target.Id,State:TargetHealth.State}' --output table
aws elbv2 describe-target-health --target-group-arn "$MCS_TG_ARN" --query 'TargetHealthDescriptions[].{Id:Target.Id,State:TargetHealth.State}' --output table
```

### Instances & IPs
```bash
# List instances by cluster tag (masters + bootstrap)
aws ec2 describe-instances \
  --filters Name=tag:kubernetes.io/cluster/$INFRA_ID,Values=owned \
  --query 'Reservations[].Instances[].{Id:InstanceId,Role:Tags[?Key==`Role`]|[0].Value,Index:Tags[?Key==`Index`]|[0].Value,Priv:PrivateIpAddress,Pub:PublicIpAddress,AZ:Placement.AvailabilityZone}' \
  --output table
```

### Wait for bootstrap to complete
```bash
openshift-install wait-for bootstrap-complete --dir "$WORKDIR" --log-level=info
```

When you see `It is now safe to remove the bootstrap resources`, proceed to the next step.

---

## 4) Remove bootstrap

**Option A (preferred): target destroy with Terraform)**
```bash
cd ~/ol-aps-training
BOOT_ADDR=$(tofu state list | grep -m1 "aws_instance.bootstrap")
[ -n "$BOOT_ADDR" ] && tofu destroy -target "$BOOT_ADDR" -auto-approve || true
```

**Option B (fallback): AWS CLI)**
```bash
# Get the bootstrap instance ID
BOOTSTRAP_ID=$(aws ec2 describe-instances \
  --filters Name=tag:kubernetes.io/cluster/$INFRA_ID,Values=owned Name=tag:Role,Values=bootstrap \
  --query 'Reservations[].Instances[].InstanceId' --output text)

# Terminate it (idempotent if already gone)
[ -n "$BOOTSTRAP_ID" ] && aws ec2 terminate-instances --instance-ids "$BOOTSTRAP_ID" || true
```

---

## 5) Create the `*.apps` ALIAS in Route53 (private zone)

> This wires the wildcard apps domain to the router’s Classic ELB. Run once per cluster.

```bash
HZ_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${CLUSTER}.${BASE_DOMAIN}." \
  --query 'HostedZones[?Config.PrivateZone==`true`].Id' --output text | sed 's|/hostedzone/||')

ROUTER_DNS=$(oc -n openshift-ingress get svc router-default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ROUTER_HZ=$(aws elb describe-load-balancers \
  --query "LoadBalancerDescriptions[?DNSName=='${ROUTER_DNS}'].CanonicalHostedZoneNameID" --output text)

aws route53 change-resource-record-sets \
  --hosted-zone-id "$HZ_ID" \
  --change-batch "$(jq -n \
    --arg name "*.apps.${CLUSTER}.${BASE_DOMAIN}." \
    --arg dns  "$ROUTER_DNS" \
    --arg hz   "$ROUTER_HZ" \
    '{Comment:"Alias *.apps to router ELB",Changes:[{Action:"UPSERT",ResourceRecordSet:{Name:$name,Type:"A",AliasTarget:{HostedZoneId:$hz,DNSName:$dns,EvaluateTargetHealth:false}}}] }')"
```

Verify DNS propagates inside the VPC/jump host:
```bash
ROUTE=$(oc -n openshift-console get route console -o jsonpath='{.spec.host}')
echo "$ROUTE"
dig +short "$ROUTE"
```

> External laptops won’t resolve the private zone. Use your jump host as a SOCKS proxy if you want to browse the console from your laptop:
> ```bash
> ssh -D 1080 -N -f user@<jump-host-public-ip>
> ```
> Then set your browser’s proxy to `SOCKS5 127.0.0.1:1080`.

---

## 6) Post‑install sanity checks

```bash
# Nodes should be Ready (compact: 3 masters labelled as workers too)
oc get nodes -o wide

# Cluster operators
oc get clusteroperators

# Ingress service: should have a load balancer hostname
oc -n openshift-ingress get svc router-default -o wide
oc -n openshift-ingress get svc router-default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'

# Console route
CONSOLE_ROUTE=$(oc -n openshift-console get route console -o jsonpath='{.spec.host}')
curl -skI "https://${CONSOLE_ROUTE}" | head -n1

# API health (internal service)
curl -sk "https://api-int.${CLUSTER}.${BASE_DOMAIN}:6443/readyz" || true
```

If ingress ever appears stuck, you can nudge a reconcile:
```bash
oc -n openshift-ingress annotate svc router-default \
  "ingress.operator.openshift.io/force-reconcile=$(date +%s)" --overwrite
```

---

## 7) Useful AWS CLI snippets

**Instances by role**
```bash
# All cluster instances
aws ec2 describe-instances \
  --filters Name=tag:kubernetes.io/cluster/$INFRA_ID,Values=owned \
  --query 'Reservations[].Instances[].{Id:InstanceId,Role:Tags[?Key==`Role`]|[0].Value,Priv:PrivateIpAddress,AZ:Placement.AvailabilityZone}' \
  --output table

# Just masters
aws ec2 describe-instances \
  --filters Name=tag:kubernetes.io/cluster/$INFRA_ID,Values=owned Name=tag:Role,Values=master \
  --query 'Reservations[].Instances[].{Id:InstanceId,Priv:PrivateIpAddress,AZ:Placement.AvailabilityZone}' \
  --output table
```

**Target group health**
```bash
API_TG_ARN=$(aws elbv2 describe-target-groups --names "${CLUSTER}-tg-api" --query 'TargetGroups[0].TargetGroupArn' --output text)
MCS_TG_ARN=$(aws elbv2 describe-target-groups --names "${CLUSTER}-tg-mcs" --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 describe-target-health --target-group-arn "$API_TG_ARN" --output table
aws elbv2 describe-target-health --target-group-arn "$MCS_TG_ARN" --output table
```

**IAM instance profile on each node**
```bash
aws ec2 describe-instances \
  --filters Name=tag:kubernetes.io/cluster/$INFRA_ID,Values=owned \
  --query 'Reservations[].Instances[].{Id:InstanceId,Role:Tags[?Key==`Role`]|[0].Value,Profile:IamInstanceProfile.Arn}' \
  --output table
```

**Router ELB details**
```bash
ELB_DNS=$(oc -n openshift-ingress get svc router-default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
aws elb describe-load-balancers \
  --query "LoadBalancerDescriptions[?DNSName=='${ELB_DNS}'][{Name:LoadBalancerName,Scheme:Scheme,Subnets:Subnets,SGs:SecurityGroups}]" \
  --output table
```

**Private zone ID and records**
```bash
aws route53 list-hosted-zones-by-name --dns-name "${CLUSTER}.${BASE_DOMAIN}." --output table
HZ_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${CLUSTER}.${BASE_DOMAIN}." \
  --query 'HostedZones[?Config.PrivateZone==`true`].Id' --output text | sed 's|/hostedzone/||')
aws route53 list-resource-record-sets --hosted-zone-id "$HZ_ID" --output table
```

---

## 8) Teardown

> **Warning:** This deletes the cluster infrastructure.

```bash
cd ~/ol-aps-training
# (Optional) delete the *.apps ALIAS first
HZ_ID=$(aws route53 list-hosted-zones-by-name --dns-name "${CLUSTER}.${BASE_DOMAIN}." --query 'HostedZones[?Config.PrivateZone==`true`].Id' --output text | sed 's|/hostedzone/||')
APPS_NAME="*.apps.${CLUSTER}.${BASE_DOMAIN}."
# Build a DELETE change batch using the existing record (if present)
EXIST=$(aws route53 list-resource-record-sets --hosted-zone-id "$HZ_ID" --query "ResourceRecordSets[?Name=='${APPS_NAME}' && Type=='A']" )
if [ "$(echo "$EXIST" | jq 'length')" -gt 0 ]; then
  aws route53 change-resource-record-sets --hosted-zone-id "$HZ_ID" \
    --change-batch "$(jq -n --argjson rrset "$(echo "$EXIST" | jq '.[0]')" '{Changes:[{Action:"DELETE",ResourceRecordSet:$rrset}]}')"
fi

# Destroy everything else
tofu destroy -auto-approve
```

---

### Notes
- Expect a few minutes of "connection refused" on NLB health checks during early bootstrap; this is normal.
- The cluster operators may flap while ingress/DNS settles. After the `*.apps` alias is in place, `authentication` and `console` should go `Available=True`.
- Route53 here is a **private** zone; external clients won’t resolve it unless you tunnel or set up split-horizon DNS.

