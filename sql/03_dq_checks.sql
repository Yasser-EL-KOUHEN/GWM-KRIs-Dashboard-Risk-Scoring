-- Data quality checks over the RAW table (before cleaning).
-- Each row is an issue type + count; use this for a DQ page in Power BI.

WITH issues AS (
  SELECT 'Missing BookingLocation' AS issue, COUNT(*) AS cnt
  FROM fact_events_raw WHERE booking_location IS NULL
  UNION ALL
  SELECT 'Missing Product' AS issue, COUNT(*) AS cnt
  FROM fact_events_raw WHERE product IS NULL
  UNION ALL
  SELECT 'Future EventDate' AS issue, COUNT(*) AS cnt
  FROM fact_events_raw WHERE event_date > DATE '2025-12-31'
  UNION ALL
  SELECT 'Negative Amount' AS issue, COUNT(*) AS cnt
  FROM fact_events_raw WHERE COALESCE(amount_chf,0) < 0
  UNION ALL
  SELECT 'Missing Mandatory Fields' AS issue, COUNT(*) AS cnt
  FROM fact_events_raw WHERE COALESCE(mandatory_fields_missing_count,0) > 0
)
SELECT * FROM issues ORDER BY cnt DESC;