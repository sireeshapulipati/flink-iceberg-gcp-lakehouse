#!/usr/bin/env bash
# Run on the VM. Runs the batch job that rebuilds the daily aggregate table.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
./scripts/render_sql.sh
"$HOME/flink-${FLINK_VERSION}/bin/sql-client.sh" -i build/00_init.sql -f build/20_batch.sql
