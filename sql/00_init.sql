-- Session init: registers the Lakehouse Iceberg REST catalog.
CREATE CATALOG IF NOT EXISTS biglake_catalog WITH (
  'type' = 'iceberg',
  'catalog-type' = 'rest',
  'uri' = 'https://biglake.googleapis.com/iceberg/v1/restcatalog',
  'warehouse' = 'bl://projects/${PROJECT_ID}/catalogs/${CATALOG_ID}',
  'header.x-goog-user-project' = '${PROJECT_ID}',
  'rest.auth.type' = 'org.apache.iceberg.gcp.auth.GoogleAuthManager',
  'io-impl' = 'org.apache.iceberg.gcp.gcs.GCSFileIO',
  'header.X-Iceberg-Access-Delegation' = 'vended-credentials'
);
