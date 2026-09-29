-- Run in BigQuery. Tables in a Lakehouse runtime catalog use project.catalog.namespace.table.
-- Replace my-project and my-streaming-catalog with your PROJECT_ID and CATALOG_ID.
SELECT event_type, COUNT(*) AS event_count
FROM `my-project.my-streaming-catalog.events.clickstream`
GROUP BY event_type
ORDER BY event_count DESC;

SELECT * FROM `my-project.my-streaming-catalog.events.clickstream_daily`
ORDER BY event_date, event_type;
