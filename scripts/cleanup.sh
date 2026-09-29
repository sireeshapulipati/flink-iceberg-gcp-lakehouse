#!/usr/bin/env bash
# Run from your laptop or Cloud Shell. Deletes every resource 01_gcp_setup.sh
# created. Deleting the VM stops the Flink cluster (and with it the streaming
# job and the publisher, both running on that VM), so there's nothing to
# cancel separately first.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a

gcloud compute instances delete "$VM_NAME" --zone="$ZONE" --project="$PROJECT_ID" --quiet
gcloud pubsub subscriptions delete "$SUBSCRIPTION" --project="$PROJECT_ID" --quiet
gcloud pubsub topics delete "$TOPIC" --project="$PROJECT_ID" --quiet
gcloud iam service-accounts delete "$FLINK_SA@$PROJECT_ID.iam.gserviceaccount.com" --project="$PROJECT_ID" --quiet
gcloud biglake iceberg catalogs delete "$CATALOG_ID" --project="$PROJECT_ID" --quiet
gcloud storage rm -r "gs://$BUCKET" --project="$PROJECT_ID"
