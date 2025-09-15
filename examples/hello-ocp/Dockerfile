FROM registry.access.redhat.com/ubi9/ubi-minimal

# Minimal Python for a tiny HTTP server
RUN microdnf install -y python3 && microdnf clean all

# App files
WORKDIR /opt/app
COPY index.html .


# Listen on 8080 and run as an arbitrary non-root UID (required by OpenShift SCCs)
EXPOSE 8080
USER 1001
CMD ["python3","-m","http.server","8080"]