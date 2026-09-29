#!/usr/bin/env bash
# Run from your laptop or Cloud Shell. Cancel the Flink job in the web UI first,
# and delete the Lakehouse catalog from the console.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
gcloud compute instances delete "$VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" --quiet
gcloud pubsub subscriptions delete "$SUBSCRIPTION" --project="$PROJECT_ID" --quiet
gcloud pubsub topics delete "$TOPIC" --project="$PROJECT_ID" --quiet
gcloud iam service-accounts delete "$FLINK_SA@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" --quiet
gcloud storage rm -r "gs://$BUCKET" --project="$PROJECT_ID"
