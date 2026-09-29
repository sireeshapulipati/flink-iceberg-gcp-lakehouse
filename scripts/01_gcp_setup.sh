#!/usr/bin/env bash
# Run from your laptop or Cloud Shell. Creates the bucket, Lakehouse catalog,
# Pub/Sub topic and subscription, service account, and Flink VM.
# Idempotent: safe to rerun after a partial failure. Every create step checks
# first and skips if the resource already exists.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a

gcloud services enable biglake.googleapis.com pubsub.googleapis.com \
  compute.googleapis.com bigquery.googleapis.com --project="$PROJECT_ID"

if gcloud storage buckets describe "gs://$BUCKET" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Bucket gs://$BUCKET already exists, skipping."
else
  gcloud storage buckets create "gs://$BUCKET" --project="$PROJECT_ID" --location=US
fi

if gcloud biglake iceberg catalogs describe "$CATALOG_ID" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Catalog $CATALOG_ID already exists, skipping."
else
  gcloud biglake iceberg catalogs create "$CATALOG_ID" \
    --project "$PROJECT_ID" \
    --catalog-type biglake \
    --default-location "gs://$BUCKET/warehouse" \
    --credential-mode vended-credentials \
    --primary-location US
fi

if gcloud pubsub topics describe "$TOPIC" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Topic $TOPIC already exists, skipping."
else
  gcloud pubsub topics create "$TOPIC" --project="$PROJECT_ID"
fi

if gcloud pubsub subscriptions describe "$SUBSCRIPTION" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Subscription $SUBSCRIPTION already exists, skipping."
else
  gcloud pubsub subscriptions create "$SUBSCRIPTION" --topic="$TOPIC" --project="$PROJECT_ID"
fi

FLINK_SA_EMAIL="$FLINK_SA@$PROJECT_ID.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$FLINK_SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
  echo "Service account $FLINK_SA_EMAIL already exists, skipping."
else
  gcloud iam service-accounts create "$FLINK_SA" --project="$PROJECT_ID"
fi

# IAM propagation lag: a just-created service account can be briefly invisible
# to policy-binding calls. Retry instead of failing on the first attempt.
for i in $(seq 1 6); do
  if gcloud iam service-accounts describe "$FLINK_SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    break
  fi
  echo "Waiting for $FLINK_SA to propagate... ($i/6)"
  sleep 10
done

# add-iam-policy-binding is itself idempotent (a no-op if the binding already
# exists), so this loop is safe to rerun without a describe check.
for ROLE in roles/biglake.editor roles/pubsub.subscriber roles/pubsub.viewer \
            roles/serviceusage.serviceUsageConsumer; do
  for i in $(seq 1 6); do
    if gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$FLINK_SA_EMAIL" \
        --role="$ROLE" --condition=None >/dev/null 2>&1; then
      break
    fi
    echo "Retrying grant of $ROLE... ($i/6)"
    sleep 10
  done
done

# The publisher script runs on the same VM and needs publish access.
# Also idempotent -- a no-op if the binding is already there.
gcloud pubsub topics add-iam-policy-binding "$TOPIC" --project="$PROJECT_ID" \
  --member="serviceAccount:$FLINK_SA_EMAIL" \
  --role=roles/pubsub.publisher >/dev/null

if gcloud compute instances describe "$VM_NAME" --project="$PROJECT_ID" --zone="$ZONE" >/dev/null 2>&1; then
  echo "VM $VM_NAME already exists, skipping."
else
  gcloud compute instances create "$VM_NAME" \
    --project="$PROJECT_ID" --zone="$ZONE" \
    --machine-type=e2-standard-4 \
    --image-family=debian-12 --image-project=debian-cloud \
    --boot-disk-size=50GB \
    --service-account="$FLINK_SA_EMAIL" \
    --scopes=cloud-platform
fi

cat <<MSG

Manual step (credential vending mode):
Open the catalog details page in the Lakehouse console, copy the auto-provisioned
service account, and grant it roles/storage.objectUser on gs://$BUCKET.
The account propagates asynchronously, so retry after a minute if the grant fails.
MSG
