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

1. Clone the repo and `cd` into it: `git clone <this-repo-url> && cd flink-iceberg-gcp-lakehouse`.
2. Copy `.env.example` to `.env` and set `PROJECT_ID` and `BUCKET`. Bucket names are globally unique, so something like `my-lakehouse-bucket-<your-project-id>` is a safe choice.
3. `chmod +x scripts/*.sh` (only needed if you plan to run a script as `./scripts/name.sh` instead of `bash scripts/name.sh`).
4. From Cloud Shell or your laptop, run `scripts/01_gcp_setup.sh`. It's safe to rerun: every step checks whether its resource already exists and skips it, so a partial failure (an IAM propagation delay, a dropped connection) doesn't require cleaning anything up before trying again.
5. Open the catalog details page in the Lakehouse console, copy the catalog's service account, and grant it Storage Object User (`roles/storage.objectUser`) on the bucket.
6. SSH to the VM, clone this repo again, copy your `.env` over, and run `scripts/02_install_flink.sh`.
7. In a second SSH session, start the publisher.
   ```bash
   python3 -m venv .venv && . .venv/bin/activate
   pip install -r publisher/requirements.txt
   set -a; source .env; set +a
   python3 publisher/publish_events.py
   ```
8. Run `scripts/03_run_streaming.sh`. Flink's web UI (port 8081, reach it with `gcloud compute ssh ... -- -L 8081:localhost:8081`) shows the running job. A snapshot lands after each checkpoint.
9. Run the queries in `sql/30_bigquery_verify.sql` in BigQuery. Tables in a Lakehouse runtime catalog use the name `project.catalog.namespace.table`.
10. Run `scripts/04_run_batch.sh` to build `clickstream_daily`, then query it in BigQuery.

## Notes

- The Iceberg sink commits at each completed checkpoint, and the Pub/Sub source acknowledges messages at each completed checkpoint. `CHECKPOINT_INTERVAL` sets both.
- The Pub/Sub source is at-least-once. Deduplicate on `message_id`.
- Streaming writes create many small files. Schedule Iceberg compaction for long-running jobs.
- The Lakehouse runtime catalog supports Iceberg format version 2 and limits `metadata.json` to 1MB.
- If the SQL client reports `NoClassDefFoundError` for `org.apache.hadoop.conf.Configuration`, add the Hadoop client jars to Flink's `lib` directory.

## Status

Validated on: _fill in date and versions after your run_

## License

Apache License 2.0
