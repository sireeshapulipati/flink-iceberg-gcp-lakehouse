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

# The Iceberg REST catalog depends on Hadoop's Configuration and a chain of
# its transitive classes even with GCSFileIO and no HDFS involved. This list
# was built empirically (github.com/rmoff, writing to Iceberg on S3 via Flink)
# hitting the same ClassNotFoundException chain; CREATE CATALOG fails without
# these even against GCS, not just S3.
wget -nc -P "$LIB" "$MVN/org/apache/hadoop/hadoop-common/${HADOOP_COMMON_VERSION}/hadoop-common-${HADOOP_COMMON_VERSION}.jar"
wget -nc -P "$LIB" "$MVN/org/apache/hadoop/hadoop-hdfs-client/${HADOOP_COMMON_VERSION}/hadoop-hdfs-client-${HADOOP_COMMON_VERSION}.jar"
wget -nc -P "$LIB" "$MVN/org/apache/hadoop/hadoop-auth/${HADOOP_COMMON_VERSION}/hadoop-auth-${HADOOP_COMMON_VERSION}.jar"
wget -nc -P "$LIB" "$MVN/org/apache/hadoop/hadoop-mapreduce-client-core/${HADOOP_COMMON_VERSION}/hadoop-mapreduce-client-core-${HADOOP_COMMON_VERSION}.jar"
wget -nc -P "$LIB" "$MVN/org/apache/hadoop/thirdparty/hadoop-shaded-guava/1.1.1/hadoop-shaded-guava-1.1.1.jar"
wget -nc -P "$LIB" "$MVN/org/apache/commons/commons-configuration2/2.1.1/commons-configuration2-2.1.1.jar"
wget -nc -P "$LIB" "$MVN/commons-logging/commons-logging/1.1.3/commons-logging-1.1.3.jar"
wget -nc -P "$LIB" "$MVN/org/codehaus/woodstox/stax2-api/4.2.1/stax2-api-4.2.1.jar"
wget -nc -P "$LIB" "$MVN/com/fasterxml/woodstox/woodstox-core/5.3.0/woodstox-core-5.3.0.jar"

# Flink defaults to 1 task slot per TaskManager regardless of the VM's actual
# CPU count, so the streaming job alone occupies the whole cluster and a
# concurrent batch job has nowhere to run. e2-standard-4 has 4 vCPUs to spare;
# 2 slots lets streaming and batch coexist. Flink 1.19+ uses config.yaml, a
# nested hierarchy, not the old flat flink-conf.yaml -- the key is a 2-space
# indented line under the top-level taskmanager: block.
sed -i 's/^  numberOfTaskSlots: 1/  numberOfTaskSlots: 2/' \
  "$HOME/flink-${FLINK_VERSION}/conf/config.yaml"

"$HOME/flink-${FLINK_VERSION}/bin/start-cluster.sh"
echo "Flink is running. Web UI on port 8081."
