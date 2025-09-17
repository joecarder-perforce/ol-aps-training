
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
```
You should see:
NAME                                               READY   STATUS    RESTARTS   AGE
lab-cluster-0-entity-operator-69bc77d4f8-jp8n5     2/2     Running   0          24s
lab-cluster-0-kafka-0                              1/1     Running   0          59s
lab-cluster-0-kafka-1                              1/1     Running   0          59s
lab-cluster-0-kafka-2                              1/1     Running   0          59s
lab-cluster-0-zookeeper-0                          1/1     Running   0          97s
lab-cluster-0-zookeeper-1                          1/1     Running   0          97s
lab-cluster-0-zookeeper-2                          1/1     Running   0          97s
strimzi-cluster-operator-v0.45.0-db47f489b-ph8gf   1/1     Running   0          119m
```

All should become **Running** with **READY 1/1 (or 2/2 for EO)**.

---

## 4) Quick smoke test (optional)

Create a test topic (internal, 3 partitions/replicas):
```bash
oc apply -f examples/Strimzi/20-demo-topic.yaml
```

== Manually consuming a topic  from your minikube Kafka broker cluster

Let's create the certificates for the kafka consumer/producer test

. create a folder for storing the certificate `mkdir $HOME/sslraw` and switch to that dir `cd $HOME/sslraw`
. be sure to have `jq` installed by running `which jq`. If it's not installed, install it
.. on mac  `brew install jq`
.. on ubuntu `sudo apt-get install jq`
. extract the certificates from Kubernetes:

.Extracting the certificates and creating a Keystore
```
oc -n kafka get secret lab-cluster-0-cluster-ca-cert -o json | jq '.data["ca.crt"]' -r | base64 --decode >  ca.crt

oc -n kafka get secret kafka-user -o json | jq '.data["user.p12"]' -r | base64 --decode >  user.p12

oc -n kafka get secret kafka-user -o json | jq '.data["user.password"]' -r | base64 --decode >  user.password

```

.Create the keystore
```
keytool -importkeystore \
        -deststorepass passw0rd -destkeypass passw0rd -destkeystore my-user.jks \
        -srckeystore user.p12 -srcstoretype PKCS12 -srcstorepass $(cat user.password) \
        -alias my-user
```

.Create the trust store
```
keytool -import -file ./ca.crt -alias my-cluster-ca -keystore truststore.jks -deststorepass passw0rd  -noprompt
```

.Setup kafka consumers for SSL
. Change your home directory `cd` and hit enter
. Download and unzip Apache Kafka (at the time of writing, this document is using 3.1.0 )
.. `wget https://dlcdn.apache.org/kafka/3.9.1/kafka_2.12-3.9.1.tgz`
.. `tar -xvzf kafka_2.12-3.9.1.tgz`
. Let's prepare a place for the SSL certificates in the unzipped kafka distribution
.. `mkdir ./kafka_2.12-3.9.1/ssl`
.. `cp sslraw/truststore.jks ./kafka_2.12-3.9.1/ssl`
.. `cp sslraw/my-user.jks ./kafka_2.12-3.9.1/ssl`

. Create a file `./kafka_2.12-3.9.1/ssl/client-ssl-auth.properties` copy these contents into it:
.. `vi ./kafka_2.12-3.9.1/ssl/client-ssl-auth.properties`

.client-ssl-auth.properties
```
security.protocol=SSL
ssl.truststore.location=/home/*{user-name}*/kafka_2.12-3.9.1/ssl/truststore.jks
ssl.truststore.password=passw0rd
ssl.keystore.location=/home/*{user-name}*/kafka_2.12-3.9.1/ssl/my-user.jks
ssl.keystore.password=passw0rd
ssl.key.password=passw0rd
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
oc delete -f examples/Strimzi/10-kafka-zk-3x3.yaml

# Remove Strimzi operator resources
Delete the Operator from OperatorHub

# Finally remove the namespace (deletes PVCs unless you moved them)
oc delete -f examples/Strimzi/00-namespace.yaml
```

---

## Troubleshooting

- **Pods Pending:** Check PV/PVC binding and StorageClass names; ensure `gp3-csi` (or your class) exists.
- **Operator events:**  
  `oc describe deploy/strimzi-cluster-operator -n kafka` and `oc logs deploy/strimzi-cluster-operator -n kafka`.
- **CRD mismatches:** Ensure you applied **0.45.x** CRDs/manifest set before creating the `Kafka` resource.
- **Image pull issues:** Confirm registry access or mirror Strimzi/Kafka images to an internal registry.
