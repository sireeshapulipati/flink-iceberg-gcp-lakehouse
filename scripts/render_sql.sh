#!/usr/bin/env bash
# Substitutes .env values into sql/*.sql and writes the results to build/.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a
mkdir -p build
for f in sql/*.sql; do
  envsubst '${PROJECT_ID} ${CATALOG_ID} ${SUBSCRIPTION} ${CHECKPOINT_INTERVAL}' < "$f" > "build/$(basename "$f")"
done
echo "Rendered SQL into build/"
