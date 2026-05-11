#!/bin/bash
# Usage: bash gcp/push-image.sh
set -e

# Load variables from .env in project root
source "$(dirname "$0")/../.env"

IMAGE="$GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/url-shortener/app"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git")

gcloud auth configure-docker $GCP_REGION-docker.pkg.dev --quiet

docker build -t $IMAGE:latest -t $IMAGE:$GIT_SHA .
docker push $IMAGE:latest
docker push $IMAGE:$GIT_SHA

echo "Pushed: $IMAGE:latest ($GIT_SHA)"
