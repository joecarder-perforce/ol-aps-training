# Hello OpenShift (UBI + Python http.server)

A minimal, reviewable “hello world” web app for OpenShift.  
Image is built **in-cluster** from the provided `Dockerfile` using a Docker strategy build, then deployed behind a Service and exposed via a Route.

- Base image: `registry.access.redhat.com/ubi9/ubi-minimal`
- Serves static `index.html` via `python3 -m http.server 8080`
- Runs as **non-root (UID 1001)** so it works with OpenShift default SCCs

> This example assumes your cluster uses a public router NLB but **private DNS**. If DNS is private, you’ll add a temporary `/etc/hosts` entry to reach the app from your laptop.

---

## Prerequisites

- `oc` CLI logged into the target cluster (`oc whoami` should work).
- A project you can create resources in.
- On compact (3-node) clusters, masters are schedulable. Keep the registry/app replicas at 1 for simplicity.
- If your `*.apps` domain is **private**, you’ll need `sudo` on your workstation to update `/etc/hosts`.

Directory layout (in this repo):
```
examples/
  hello-ocp/
    Dockerfile
    README.md  (this file)
```

---

## Quick Start (copy/paste)

Run these from `examples/hello-ocp`:

```bash
# 0) Choose/enter the example directory
cd examples/hello-ocp

# 1) New project (namespace)
oc new-project hello-world || oc project hello-world

# 2) Create a Docker strategy BuildConfig that accepts local build context
oc new-build --name hello --strategy docker --binary

# 3) Start the build from the current directory and stream logs
oc start-build hello --from-dir=. --follow

# 4) Create a Deployment from the built ImageStream
oc new-app --image-stream=hello:latest --name hello

# 5) Expose a Service on 8080 and create a Route
oc expose deployment/hello --port=8080 --target-port=8080 || true
oc expose service/hello

# 6) Print the Route host
APP_HOST=$(oc -n hello-world get route hello -o jsonpath='{.spec.host}')
echo "App route: http://$APP_HOST"

# 7) If your apps DNS is PRIVATE but the router NLB is PUBLIC, add /etc/hosts
LB_DNS=$(oc -n openshift-ingress get svc/router-default -o jsonpath='{.status.loadBalancer.ingress[*].hostname}')
APP_IP=$(dig +short "$LB_DNS" | head -n1)
echo "Router LB: $LB_DNS -> $APP_IP"
echo "Add to /etc/hosts (requires sudo):"
echo "  $APP_IP  $APP_HOST"

# One-liner to append (careful: appends, won’t dedupe)
# sudo sh -c "echo '$APP_IP  $APP_HOST' >> /etc/hosts"

# 8) Test
curl -I "http://$APP_HOST" || true
echo "Now open: http://$APP_HOST"
```

---

## What you should see

- `Build` succeeds and creates an `ImageStreamTag` `hello:latest`.
- `Deployment/hello` with 1 replica.
- `Service/hello` targeting port `8080`.
- `Route/hello` with a hostname like `hello-hello-world.apps.<cluster-domain>`.

If DNS is private and you added an `/etc/hosts` entry pointing to the router NLB IP, your browser should load the “Hello from OpenShift 🚀” page.

---

## Notes for Instructors / Students

- **Review the Dockerfile** (kept intentionally simple and safe). It installs `python3`, bakes a tiny `index.html`, exposes `8080`, and sets `USER 1001`.
- **Binary builds** keep the example self-contained (no external git creds needed).
- If you want to redeploy with changes, edit files and re-run:
  ```bash
  oc start-build hello --from-dir=. --follow
  oc rollout restart deployment/hello
  ```
- If your cluster uses **public DNS** for `*.apps`, you do **not** need the `/etc/hosts` step.

---

## Troubleshooting

- **Build fails with Docker access error**  
  Ensure the BuildConfig is `--strategy docker` and you ran `oc start-build hello --from-dir=. --follow` from the folder containing `Dockerfile`.

- **Pod won’t start due to permissions**  
  Confirm the image runs as non-root (`USER 1001` is in the Dockerfile).  
  Check pod events:
  ```bash
  oc describe pod -l app=hello
  ```

- **Route resolves but times out**  
  Confirm Service selects the Deployment and targets port 8080:
  ```bash
  oc get svc hello -o yaml | yq '.spec.ports,.spec.selector'
  oc get endpoints hello
  ```

- **No external access from your laptop**  
  If your router NLB is public but DNS is private, add `/etc/hosts` as shown above.  
  If the router is internal-only, you must access from a jump host/VPC or create a public IngressController.

---

## Clean up

```bash
oc delete project hello-world
```

---

## Appendix: Commands, individually

```bash
# Build
oc new-project hello-world || oc project hello-world
oc new-build --name hello --strategy docker --binary
oc start-build hello --from-dir=. --follow

# Deploy + expose
oc new-app --image-stream=hello:latest --name hello
oc expose deployment/hello --port=8080 --target-port=8080 || true
oc expose service/hello
oc get route hello

# Router LB IP + /etc/hosts helper
LB_DNS=$(oc -n openshift-ingress get svc/router-default -o jsonpath='{.status.loadBalancer.ingress[*].hostname}')
dig +short "$LB_DNS"
```
