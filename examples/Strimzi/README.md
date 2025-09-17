
# Strimzi 0.45 on OpenShift 4.19 — 3×Kafka + 3×ZooKeeper

This repo installs **Strimzi 0.45.x** (last series that supports ZooKeeper) and deploys a
**3-broker Kafka** cluster with a **3-node ZooKeeper** ensemble.

> **Why 0.45?** Strimzi 0.46+ is KRaft-only (no ZooKeeper). For training that demonstrates the classic Kafka+ZooKeeper topology, pin to **0.45.x**.

---

## Prerequisites

- OpenShift **4.19** cluster; you are `kubeadmin`.
- `oc` CLI logged in.
- Working **default StorageClass** (adjust class names in YAMLs if needed; examples use `gp3-csi`).
- Internet egress to pull the Strimzi release assets and container images (or mirror them internally).

---

## Directory layout

```
.
├── README.md
├── 00-namespace.yaml
├── 10-kafka-cluster.yaml
└── 20-demo-topic.yaml
```

---

## 1) Create the project/namespace

```bash
oc apply -f examples/Strimzi/00-namespace.yaml
```

---

## 2) Install Strimzi **0.45.x** (operator, CRDs)

> We install from the official release from the operator hub

```bash
Select Operators in the Main Menu
Navigate to the OperatorHub sub menu item
Search for Strimzi
Select 0.45.0
Run in a specified name space, select the name space kafka
```

**Verify operator is ready:**
```bash
oc get deploy -n kafka | grep cluster-operator
oc get pods -n kafka
```
---

## 3) Deploy Kafka (3) + ZooKeeper (3)

```bash
oc apply -f examples/Strimzi/10-kafka-cluster.yaml
```

**Watch reconcile:**
```bash
oc get pods -n kafka -w
```
You should see:
- `demo-zk-zookeeper-0..2`
- `demo-zk-kafka-0..2`
- `demo-zk-entity-operator-*`

All should become **Running** with **READY 1/1 (or 2/2 for EO)**.

---

## 4) Quick smoke test (optional)

Create a test topic (internal, 3 partitions/replicas):
```bash
oc apply -f manifests/20-demo-topic.yaml
```

List topics via a temporary Kafka toolbox pod:
```bash
oc run -n kafka kt --image=quay.io/strimzi/kafka:latest --restart=Never -it --rm --   bash -lc 'bin/kafka-topics.sh --bootstrap-server demo-zk-kafka-bootstrap:9092 --list'
```

---

## Tuning notes

- **Storage classes/sizes:** Adjust `storage.class` and `size` in `10-kafka-cluster` to match your environment.
- **Listeners:** Examples expose **internal** listeners only (`ClusterIP`). For routes/LoadBalancer ingress, we will add a `type: route` or `type: loadbalancer` listener and configure TLS/users.
- **Resources:** For small training clusters, defaults are fine. For heavier loads, set CPU/memory requests/limits under `kafka.resources` and `zookeeper.resources`.
- **Entity Operator:** Enabled for convenience (Topic/User operators). Remove if you don’t need them.

---

## Uninstall (lab cleanup)

```bash
# Delete the Kafka cluster (PVCs retained unless you set deleteClaim: true)
oc delete -f manifests/10-kafka-zk-3x3.yaml

# Remove Strimzi operator resources
STRIMZI_VERSION=0.45.0
oc delete -n kafka -f /tmp/strimzi-${STRIMZI_VERSION}/strimzi-${STRIMZI_VERSION}/install/cluster-operator

# Finally remove the namespace (deletes PVCs unless you moved them)
oc delete -f manifests/00-namespace.yaml
```

---

## Troubleshooting

- **Pods Pending:** Check PV/PVC binding and StorageClass names; ensure `gp3-csi` (or your class) exists.
- **Operator events:**  
  `oc describe deploy/strimzi-cluster-operator -n kafka` and `oc logs deploy/strimzi-cluster-operator -n kafka`.
- **CRD mismatches:** Ensure you applied **0.45.x** CRDs/manifest set before creating the `Kafka` resource.
- **Image pull issues:** Confirm registry access or mirror Strimzi/Kafka images to an internal registry.
