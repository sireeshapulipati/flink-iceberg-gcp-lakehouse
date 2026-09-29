#!/usr/bin/env bash
# Run on the VM. Submits the streaming Pub/Sub -> Iceberg job.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
./scripts/render_sql.sh
"$HOME/flink-${FLINK_VERSION}/bin/sql-client.sh" -i build/00_init.sql -f build/10_streaming.sql
