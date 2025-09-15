FROM registry.access.redhat.com/ubi9/ubi-minimal

# Minimal Python for a tiny HTTP server
RUN microdnf install -y python3 && microdnf clean all

# App files
WORKDIR /opt/app
# Write index.html during build so this stays single-file for the demo
RUN bash -lc 'cat > index.html << "HTML"
<!doctype html>
<html lang="en">
  <head><meta charset="utf-8"><title>Hello OpenShift</title></head>
  <body style="font-family: sans-serif; margin: 2rem;">
    <h1>Hello from OpenShift 🚀</h1>
    <p>If you can read this, your Route and Service are working.</p>
  </body>
</html>
HTML'

# Listen on 8080 and run as an arbitrary non-root UID (required by OpenShift SCCs)
EXPOSE 8080
USER 1001
CMD ["python3","-m","http.server","8080"]