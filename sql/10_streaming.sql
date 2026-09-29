-- Streaming job: Pub/Sub -> Iceberg.
SET 'execution.checkpointing.interval' = '${CHECKPOINT_INTERVAL}';

CREATE TEMPORARY TABLE default_catalog.default_database.clickstream_source (
  user_id    STRING,
  event_type STRING,
  event_ts   TIMESTAMP(3),
  session_id STRING,
  message_id STRING METADATA FROM 'message-id' VIRTUAL
) WITH (
  'connector'    = 'pubsub',
  'project'      = '${PROJECT_ID}',
  'subscription' = '${SUBSCRIPTION}',
  'format'       = 'json'
);

USE CATALOG biglake_catalog;
CREATE DATABASE IF NOT EXISTS events;
USE events;

CREATE TABLE IF NOT EXISTS clickstream (
  user_id    STRING,
  event_type STRING,
  event_ts   TIMESTAMP(3),
  session_id STRING,
  message_id STRING,
  event_date DATE
) PARTITIONED BY (event_date)
WITH ('format-version' = '2');

INSERT INTO clickstream
SELECT user_id, event_type, event_ts, session_id, message_id,
       CAST(event_ts AS DATE) AS event_date
FROM default_catalog.default_database.clickstream_source;
