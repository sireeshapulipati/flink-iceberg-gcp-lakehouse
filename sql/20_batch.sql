-- Batch job: rebuild the daily aggregate from the Iceberg table.
SET 'execution.runtime-mode' = 'batch';
SET 'table.dml-sync' = 'true';

USE CATALOG biglake_catalog;
USE events;

CREATE TABLE IF NOT EXISTS clickstream_daily (
  event_date  DATE,
  event_type  STRING,
  event_count BIGINT
) PARTITIONED BY (event_date)
WITH ('format-version' = '2');

INSERT OVERWRITE clickstream_daily
SELECT event_date, event_type, COUNT(*) AS event_count
FROM clickstream
GROUP BY event_date, event_type;
