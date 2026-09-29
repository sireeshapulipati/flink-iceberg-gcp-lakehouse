#!/usr/bin/env bash
# Run on the VM. Installs Java 17, Flink, and the Iceberg and Pub/Sub jars.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; source .env; set +a

sudo apt-get update
sudo apt-get install -y openjdk-17-jdk wget python3-venv gettext-base

cd "$HOME"
wget -nc "https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_2.12.tgz"
tar xzf "flink-${FLINK_VERSION}-bin-scala_2.12.tgz"

MVN=https://repo.maven.apache.org/maven2
LIB="$HOME/flink-${FLINK_VERSION}/lib"
wget -nc -P "$LIB" "$MVN/org/apache/iceberg/iceberg-flink-runtime-1.20/${ICEBERG_VERSION}/iceberg-flink-runtime-1.20-${ICEBERG_VERSION}.jar"
wget -nc -P "$LIB" "$MVN/org/apache/iceberg/iceberg-gcp-bundle/${ICEBERG_VERSION}/iceberg-gcp-bundle-${ICEBERG_VERSION}.jar"
wget -nc -P "$LIB" "$MVN/io/github/flink-gcp/flink-sql-connector-gcp-pubsub/${PUBSUB_CONNECTOR_VERSION}/flink-sql-connector-gcp-pubsub-${PUBSUB_CONNECTOR_VERSION}.jar"

"$HOME/flink-${FLINK_VERSION}/bin/start-cluster.sh"
echo "Flink is running. Web UI on port 8081."
