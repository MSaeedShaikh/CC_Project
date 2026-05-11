#!/bin/bash
# Creates Cloud SQL PostgreSQL instance + database + user
set -e

# Load variables from .env in project root
source "$(dirname "$0")/../.env"

INSTANCE_NAME="url-shortener-db"

# Create PostgreSQL instance
gcloud sql instances create $INSTANCE_NAME \
  --project=$GCP_PROJECT_ID \
  --database-version=POSTGRES_15 \
  --region=$GCP_REGION \
  --tier=db-f1-micro

# Create database
gcloud sql databases create $DB_NAME \
  --project=$GCP_PROJECT_ID \
  --instance=$INSTANCE_NAME

# Create user
gcloud sql users create $DB_USER \
  --project=$GCP_PROJECT_ID \
  --instance=$INSTANCE_NAME \
  --password="$DB_PASS"

echo "Cloud SQL ready."
echo "Connection name: $GCP_PROJECT_ID:$GCP_REGION:$INSTANCE_NAME"
