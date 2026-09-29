# Flink SQL and Apache Iceberg on Google Cloud

Streaming and batch pipelines with Flink SQL, writing Apache Iceberg tables to Cloud Storage through Google's Lakehouse (BigLake) Iceberg REST catalog. BigQuery queries the same tables.

```
publisher (Python) -> Pub/Sub -> Flink SQL (streaming) -> Iceberg table (Cloud Storage)
                                                                 |            |
                                          Flink SQL (batch) <----+            +--> BigQuery
                                          daily aggregate table
```

The full walkthrough is in the article: **ARTICLE_URL**

## Versions

| Component | Version |
|---|---|
| Apache Flink | 1.20.x (LTS), Scala 2.12 build |
| Java | 17 |
| Apache Iceberg | 1.11.0 (`iceberg-flink-runtime-1.20`, `iceberg-gcp-bundle`) |
| Pub/Sub SQL connector | `flink-sql-connector-gcp-pubsub` 1.1.0-1.20 (independent open-source project) |

## Repository layout

```
.env.example              settings for every script
scripts/01_gcp_setup.sh   bucket, catalog, Pub/Sub, service account, VM (run from laptop or Cloud Shell)
scripts/02_install_flink.sh   Java, Flink, and jars (run on the VM)
scripts/03_run_streaming.sh   submits the streaming job (run on the VM)
scripts/04_run_batch.sh       runs the batch job (run on the VM)
scripts/cleanup.sh        deletes the resources
sql/00_init.sql           registers the Iceberg REST catalog
sql/10_streaming.sql      Pub/Sub -> Iceberg streaming job
sql/20_batch.sql          daily aggregate rebuild in batch mode
sql/30_bigquery_verify.sql    queries to run in BigQuery
publisher/publish_events.py   mock clickstream events to Pub/Sub
```

## Run it

**1. Clone the repo (Cloud Shell or your laptop).**
```bash
git clone <this-repo-url> && cd flink-iceberg-gcp-lakehouse
```

**2. Set up `.env`.** Bucket names are globally unique, so something like `my-lakehouse-bucket-<your-project-id>` is a safe choice.
```bash
cp .env.example .env && chmod +x scripts/*.sh
```
Edit the two values with an editor:
```bash
nano .env   # set PROJECT_ID and BUCKET, save with Ctrl+O, exit with Ctrl+X
```
Or without one:
```bash
sed -i 's/^PROJECT_ID=.*/PROJECT_ID=YOUR_PROJECT_ID/' .env && sed -i 's/^BUCKET=.*/BUCKET=YOUR_BUCKET/' .env && cat .env
```

**3. Run the setup script.** Safe to rerun: every step checks whether its resource already exists and skips it.
```bash
bash scripts/01_gcp_setup.sh
```

**4. Grant the catalog's service account bucket access.** The script prints the reminder; the account itself is shown on the catalog's details page in the Lakehouse console.
```bash
gcloud storage buckets add-iam-policy-binding gs://YOUR_BUCKET --member="serviceAccount:CATALOG_SERVICE_ACCOUNT" --role="roles/storage.objectUser"
```

**5. SSH into the VM.**
```bash
gcloud compute ssh flink-vm --zone=us-central1-a
```

**6. On the VM: get the repo and `.env` there again, then install Flink.** `.env` isn't tracked in git, so recreate it the same way as step 2. The base image doesn't ship git, so install it first.
```bash
sudo apt-get update && sudo apt-get install -y git && git clone <this-repo-url> && cd flink-iceberg-gcp-lakehouse && cp .env.example .env
```
Set `PROJECT_ID` and `BUCKET` to the same values you used in step 2. With an editor available:
```bash
nano .env
```
Without one (or to script it), `sed` instead:
```bash
sed -i 's/^PROJECT_ID=.*/PROJECT_ID=YOUR_PROJECT_ID/' .env && sed -i 's/^BUCKET=.*/BUCKET=YOUR_BUCKET/' .env && cat .env
```
Then:
```bash
chmod +x scripts/*.sh && bash scripts/02_install_flink.sh
```

**7. Open a second SSH session and start the publisher.**
```bash
gcloud compute ssh flink-vm --zone=us-central1-a
```
On the VM, one line so a Cloud Shell paste can't split it across commands:
```bash
cd flink-iceberg-gcp-lakehouse && python3 -m venv .venv && . .venv/bin/activate && pip install -r publisher/requirements.txt && set -a && source .env && set +a && python3 publisher/publish_events.py
```

**8. Back in the first SSH session: run the streaming job.**
```bash
bash scripts/03_run_streaming.sh
```
A snapshot lands after each checkpoint. To watch the Flink web UI while this runs, open a third terminal (a new Cloud Shell tab, or your laptop) and tunnel to it instead of a plain SSH:
```bash
gcloud compute ssh flink-vm --zone=us-central1-a -- -L 8081:localhost:8081
```
Then browse to `http://localhost:8081`.

**9. Query the streaming table from BigQuery.** Tables in a Lakehouse runtime catalog use the name `project.catalog.namespace.table`. Easiest from the BigQuery console's query editor, with `PROJECT_ID` and `CATALOG_ID` filled in. From the command line instead, from Cloud Shell (not the VM, `.env` isn't sourced there automatically):
```bash
set -a && source .env && set +a && bq query --use_legacy_sql=false "SELECT event_type, COUNT(*) AS event_count FROM \`${PROJECT_ID}.${CATALOG_ID}.events.clickstream\` GROUP BY event_type ORDER BY event_count DESC"
```
(Building this query directly from `$PROJECT_ID` and `$CATALOG_ID` rather than substituting into `sql/30_bigquery_verify.sql` and piping the whole file to `bq query`, that file's leading `--` comment lines get parsed as command-line flags by `bq`, not SQL, and fail. The `.sql` file is meant for pasting into the BigQuery console, where comments are fine.)

**10. Run the batch job (back on the VM, first SSH session).** Runs alongside the still-running streaming job from step 8, no need to cancel it, that's what the second task slot is for.
```bash
bash scripts/04_run_batch.sh
```
Then query `clickstream_daily` the same way as step 9, with the table name swapped:
```bash
set -a && source .env && set +a && bq query --use_legacy_sql=false "SELECT * FROM \`${PROJECT_ID}.${CATALOG_ID}.events.clickstream_daily\` ORDER BY event_date, event_type"
```

**11. Clean up when you're done (from Cloud Shell, not the VM).** Deletes the VM, subscription, topic, service account, catalog, and bucket. Deleting the VM stops the Flink cluster, so the streaming job and the publisher stop with it, nothing to cancel separately first.
```bash
bash scripts/cleanup.sh
```

## Notes

- The Iceberg sink commits at each completed checkpoint, and the Pub/Sub source acknowledges messages at each completed checkpoint. `CHECKPOINT_INTERVAL` sets both.
- The Pub/Sub source is at-least-once. Deduplicate on `message_id`.
- Streaming writes create many small files. Schedule Iceberg compaction for long-running jobs.
- The Lakehouse runtime catalog supports Iceberg format version 2 and limits `metadata.json` to 1MB.
- The Iceberg REST catalog depends on `org.apache.hadoop.conf.Configuration` and a chain of its transitive classes, even with `GCSFileIO` and no HDFS involved. `scripts/02_install_flink.sh` installs the full set of Hadoop-related jars this needs (`hadoop-common`, `hadoop-hdfs-client`, `hadoop-auth`, `hadoop-mapreduce-client-core`, `hadoop-shaded-guava`, `commons-configuration2`, `commons-logging`, `stax2-api`, `woodstox-core`). If you're on an earlier copy of the repo and hit a `ClassNotFoundException` for any of these, add the missing jar to `lib/` and restart the cluster (`bin/stop-cluster.sh && bin/start-cluster.sh`, jars only load at startup).
- Flink defaults to 1 task slot per TaskManager regardless of the VM's actual CPU count. With only 1, the streaming job (step 8) occupies the whole cluster and the batch job (step 10) submits but sits stuck indefinitely rather than failing. `scripts/02_install_flink.sh` sets `numberOfTaskSlots: 2` in `conf/config.yaml` (the nested-hierarchy format Flink 1.19+ uses, not the old flat `flink-conf.yaml`) before starting the cluster, so both can run at once.

## Status

Validated on: 2026-09-29, against project `flink-openlakehouse`. Flink 1.20.4, Iceberg 1.11.0, `flink-sql-connector-gcp-pubsub` 1.1.0-1.20, `hadoop-common` 3.3.6 (full jar list per Notes above). Streaming (steps 1-9) and batch (step 10, including a second rerun to confirm `INSERT OVERWRITE` doesn't duplicate) both confirmed working end to end, including a BigQuery read-back at each stage.

## License

Apache License 2.0
