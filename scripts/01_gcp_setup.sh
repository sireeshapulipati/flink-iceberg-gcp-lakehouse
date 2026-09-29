#!/usr/bin/env bash
# Run from your laptop or Cloud Shell. Creates the bucket, Lakehouse catalog,
# Pub/Sub topic and subscription, service account, and Flink VM.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a

gcloud services enable biglake.googleapis.com pubsub.googleapis.com \
  compute.googleapis.com bigquery.googleapis.com --project="$PROJECT_ID"

gcloud storage buckets create "gs://$BUCKET" --project="$PROJECT_ID" --location=US

gcloud biglake iceberg catalogs create "$CATALOG_ID" \
  --project "$PROJECT_ID" \
  --catalog-type biglake \
  --default-location "gs://$BUCKET/warehouse" \
  --credential-mode vended-credentials \
  --primary-location US

gcloud pubsub topics create "$TOPIC" --project="$PROJECT_ID"
gcloud pubsub subscriptions create "$SUBSCRIPTION" --topic="$TOPIC" --project="$PROJECT_ID"

gcloud iam service-accounts create "$FLINK_SA" --project="$PROJECT_ID"
for ROLE in roles/biglake.editor roles/pubsub.subscriber roles/pubsub.viewer \
            roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$FLINK_SA@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="$ROLE" --condition=None >/dev/null
done
# The publisher script runs on the same VM and needs publish access.
gcloud pubsub topics add-iam-policy-binding "$TOPIC" --project="$PROJECT_ID" \
  --member="serviceAccount:$FLINK_SA@$PROJECT_ID.iam.gserviceaccount.com" \
  --role=roles/pubsub.publisher >/dev/null

gcloud compute instances create "$VM_NAME" \
  --project="$PROJECT_ID" --zone="$ZONE" \
  --machine-type=e2-standard-4 \
  --image-family=debian-12 --image-project=debian-cloud \
  --boot-disk-size=50GB \
  --service-account="$FLINK_SA@$PROJECT_ID.iam.gserviceaccount.com" \
  --scopes=cloud-platform

cat <<MSG

Manual step (credential vending mode):
Open the catalog details page in the Lakehouse console, copy the auto-provisioned
service account, and grant it roles/storage.objectUser on gs://$BUCKET.
The account propagates asynchronously, so retry after a minute if the grant fails.
MSG
