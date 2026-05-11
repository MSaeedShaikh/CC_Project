#!/bin/bash
# Creates HTTP load balancer pointing to the MIG
set -e

# Load variables from .env in project root
source "$(dirname "$0")/../.env"

# Health check
gcloud compute health-checks create http url-shortener-health \
  --project=$GCP_PROJECT_ID \
  --port=8080 \
  --request-path=/health

# Backend service
gcloud compute backend-services create url-shortener-backend \
  --project=$GCP_PROJECT_ID \
  --protocol=HTTP \
  --port-name=http \
  --health-checks=url-shortener-health \
  --global

# Attach MIG to backend
gcloud compute backend-services add-backend url-shortener-backend \
  --project=$GCP_PROJECT_ID \
  --instance-group=url-shortener-mig \
  --instance-group-zone=$GCP_ZONE \
  --global

# Named port on MIG
gcloud compute instance-groups managed set-named-ports url-shortener-mig \
  --project=$GCP_PROJECT_ID \
  --zone=$GCP_ZONE \
  --named-ports=http:8080

# URL map
gcloud compute url-maps create url-shortener-map \
  --project=$GCP_PROJECT_ID \
  --default-service=url-shortener-backend

# HTTP proxy
gcloud compute target-http-proxies create url-shortener-proxy \
  --project=$GCP_PROJECT_ID \
  --url-map=url-shortener-map

# Forwarding rule (external IP)
gcloud compute forwarding-rules create url-shortener-rule \
  --project=$GCP_PROJECT_ID \
  --global \
  --target-http-proxy=url-shortener-proxy \
  --ports=80

echo "Load balancer ready. Get IP:"
echo "gcloud compute forwarding-rules describe url-shortener-rule --global --format='get(IPAddress)'"
