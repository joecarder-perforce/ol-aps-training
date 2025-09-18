# Lab: HTTP JSON → Kafka → Connect pod logs (no auth, TLS client auth)

**Namespace:** `kafka` (already exists)  
**Kafka cluster:** `lab-cluster-0`  
**Bootstrap:** `lab-cluster-0-kafka-bootstrap-kafka.apps.{change-me}.trng.lab:443` (Route, TLS)  
**Auth:** client TLS with KafkaUser `kafka-user` (Secret contains `user.crt`, `user.key`, `ca.crt`)  
**Data topic:** `lab-topic`  
**Connect internals:** `_http-connect-configs`, `_http-connect-offsets`, `_http-connect-status`

## 0) Pre-flight
Ensure the namespace/cluster/topic exist (you likely already applied your cluster files):
- Namespace `kafka`
- Kafka `lab-cluster-0` and KafkaUser `kafka-user`
- KafkaTopic `lab-topic`
```
cd examples/kafkaconnect
```
## 1) Deploy Kafka Connect (w/build to ImageStream)
```bash
oc -n kafka apply -f 05-imagestream.yaml
oc -n kafka apply -f 10-kafkaconnect-with-camel.yaml
oc -n kafka get buildconfigs
oc -n kafka logs -f build/http-connect-connect-build-##
```

## 2) Start the HTTP source + console sink
```bash
oc -n kafka apply -f 30-connector-http-source.yaml
oc -n kafka apply -f 40-connector-console-sink.yaml
oc -n kafka get kafkaconnector
```

## 3) Watch data in Connect logs
```bash
CONNECT_POD=$(oc -n kafka get pods -l strimzi.io/name=http-connect-connect -o jsonpath='{.items[0].metadata.name}')
oc -n kafka logs -f "$CONNECT_POD" -c kafka-connect
```

### Reset
```bash
oc -n kafka delete kafkaconnector console-sink http-openmeteo-source
oc -n kafka apply -f 30-connector-http-source.yaml
oc -n kafka apply -f 40-connector-console-sink.yaml
```

## Clean up
```bash
oc -n kafka delete -f 40-connector-console-sink.yaml || true
oc -n kafka delete -f 30-connector-http-source.yaml || true
oc -n kafka delete -f 10-kafkaconnect-with-camel.yaml || true
oc -n kafka delete -f 01-connect-internals.yaml || true
```

## Troubleshooting
- Describe KafkaConnect for build status:
  ```bash
  oc -n kafka describe kafkaconnect http-connect
  oc -n kafka get builds
  oc -n kafka logs build/$(oc -n kafka get builds -o name | tail -n1)
  ```
- TLS assets required:
  - Secret `lab-cluster-0-cluster-ca-cert` (`ca.crt`)
  - Secret `kafka-user` (`user.crt`, `user.key`)
