#!/bin/bash
# Creates instance template + managed instance group
set -e

# Load variables from .env in project root
source "$(dirname "$0")/../.env"

IMAGE="$GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/url-shortener/app:latest"
DB_URL="postgresql://$DB_USER:$DB_PASS@/$DB_NAME?host=/cloudsql/$GCP_PROJECT_ID:$GCP_REGION:url-shortener-db"

# Create instance template with container
gcloud compute instance-templates create-with-container url-shortener-template \
  --project=$GCP_PROJECT_ID \
  --machine-type=e2-micro \
  --region=$GCP_REGION \
  --container-image=$IMAGE \
  --container-env="DATABASE_URL=$DB_URL,SECRET_KEY=$SECRET_KEY,BASE_URL=$BASE_URL,FLASK_ENV=production" \
  --tags=http-server \
  --scopes=cloud-platform

# Create managed instance group
gcloud compute instance-groups managed create url-shortener-mig \
  --project=$GCP_PROJECT_ID \
  --base-instance-name=url-shortener \
  --template=url-shortener-template \
  --size=2 \
  --zone=$GCP_ZONE

# Set autoscaling
gcloud compute instance-groups managed set-autoscaling url-shortener-mig \
  --project=$GCP_PROJECT_ID \
  --zone=$GCP_ZONE \
  --min-num-replicas=2 \
  --max-num-replicas=5 \
  --target-cpu-utilization=0.6

# Allow HTTP traffic on port 8080
gcloud compute firewall-rules create allow-http-8080 \
  --project=$GCP_PROJECT_ID \
  --allow=tcp:8080 \
  --target-tags=http-server \
  --quiet 2>/dev/null || echo "Firewall rule already exists, skipping."

echo "MIG created: url-shortener-mig"
