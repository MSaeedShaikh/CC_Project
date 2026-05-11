#!/bin/bash
# Deletes all GCP resources for this project.
# WARNING: This is irreversible. All data will be lost.
set -e

source "$(dirname "$0")/../.env"

read -p "This will DELETE all resources and data. Type 'yes' to confirm: " confirm
if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo "Deleting load balancer..."
gcloud compute forwarding-rules delete url-shortener-rule --project=$GCP_PROJECT_ID --global --quiet
gcloud compute target-http-proxies delete url-shortener-proxy --project=$GCP_PROJECT_ID --quiet
gcloud compute url-maps delete url-shortener-map --project=$GCP_PROJECT_ID --quiet
gcloud compute backend-services delete url-shortener-backend --project=$GCP_PROJECT_ID --global --quiet
gcloud compute health-checks delete url-shortener-health --project=$GCP_PROJECT_ID --quiet

echo "Deleting instance group + template..."
gcloud compute instance-groups managed delete url-shortener-mig --project=$GCP_PROJECT_ID --zone=$GCP_ZONE --quiet
gcloud compute instance-templates delete url-shortener-template --project=$GCP_PROJECT_ID --quiet

echo "Deleting Cloud SQL..."
gcloud sql instances delete url-shortener-db --project=$GCP_PROJECT_ID --quiet

echo "Deleting Artifact Registry..."
gcloud artifacts repositories delete url-shortener --project=$GCP_PROJECT_ID --location=$GCP_REGION --quiet

echo "Done. All resources deleted."
