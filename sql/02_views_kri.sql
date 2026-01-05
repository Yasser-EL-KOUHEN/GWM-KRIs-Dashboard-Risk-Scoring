-- Views for cleaning, monthly aggregation, open-items snapshot, and KRI computation.
-- Note: This is written for PostgreSQL.

-- 1) Clean events (basic DQ filtering)
DROP VIEW IF EXISTS v_events_clean;
CREATE VIEW v_events_clean AS
SELECT *
FROM fact_events_raw
WHERE booking_location IS NOT NULL
  AND product IS NOT NULL
  AND event_date <= DATE '2025-12-31';  -- change to CURRENT_DATE if desired

-- 2) Monthly volumes
DROP VIEW IF EXISTS v_monthly_volume;
CREATE VIEW v_monthly_volume AS
SELECT
  date_trunc('month', date)::date AS year_month,
  region,
  booking_location,
  team,
  product,
  SUM(transactions_count) AS transactions_count,
  SUM(clients_count) AS clients_count
FROM fact_volume_daily
GROUP BY 1,2,3,4,5;

-- 3) Monthly event counts by type
DROP VIEW IF EXISTS v_monthly_event_counts;
CREATE VIEW v_monthly_event_counts AS
SELECT
  date_trunc('month', event_date)::date AS year_month,
  region,
  booking_location,
  team,
  product,
  event_type,
  COUNT(*) AS event_count,
  SUM(CASE WHEN severity IN ('High','Critical') THEN 1 ELSE 0 END) AS high_severity_count,
  SUM(COALESCE(amount_chf,0)) AS amount_chf_sum,
  SUM(COALESCE(mandatory_fields_missing_count,0)) AS missing_fields_sum,
  SUM(COALESCE(is_repeat,0)) AS repeat_count,
  SUM(COALESCE(is_substantiated,0)) AS substantiated_count
FROM v_events_clean
GROUP BY 1,2,3,4,5,6;

-- 4) Month-end open-items snapshot
--    Open as-of month_end if: event_date <= month_end AND (close_date is null OR close_date > month_end)
DROP VIEW IF EXISTS v_open_snapshot;
CREATE VIEW v_open_snapshot AS
WITH month_ends AS (
  SELECT (date_trunc('month', d.date) + INTERVAL '1 month' - INTERVAL '1 day')::date AS month_end
  FROM dim_date d
  GROUP BY 1
),
open_events AS (
  SELECT
    m.month_end,
    e.region,
    e.booking_location,
    e.team,
    e.product,
    e.event_type,
    e.event_id,
    (m.month_end - e.event_date) AS age_days,
    e.sla_days,
    e.due_date
  FROM month_ends m
  JOIN v_events_clean e
    ON e.event_date <= m.month_end
   AND (e.close_date IS NULL OR e.close_date > m.month_end)
)
SELECT
  date_trunc('month', month_end)::date AS year_month,
  region,
  booking_location,
  team,
  product,
  event_type,
  COUNT(*) AS open_count,
  SUM(CASE WHEN age_days > 30 THEN 1 ELSE 0 END) AS open_over_30,
  SUM(CASE WHEN age_days > sla_days THEN 1 ELSE 0 END) AS open_over_sla,
  SUM(CASE WHEN due_date IS NOT NULL AND due_date < month_end THEN 1 ELSE 0 END) AS overdue_count,
  AVG(age_days) AS avg_age_days
FROM open_events
GROUP BY 1,2,3,4,5,6;

-- 5) KRI computation (monthly + month-end KRIs)
DROP VIEW IF EXISTS v_kri_monthly;
CREATE VIEW v_kri_monthly AS
WITH base AS (
  SELECT
    v.year_month,
    v.region,
    v.booking_location,
    v.team,
    v.product,
    v.transactions_count,
    v.clients_count,
    COALESCE(SUM(CASE WHEN e.event_type='Incident' THEN e.event_count END),0) AS incidents,
    COALESCE(SUM(CASE WHEN e.event_type='Complaint' THEN e.event_count END),0) AS complaints,
    COALESCE(SUM(CASE WHEN e.event_type='Complaint' THEN e.substantiated_count END),0) AS substantiated_complaints,
    COALESCE(SUM(CASE WHEN e.event_type='Processing Error' THEN e.event_count END),0) AS processing_errors,
    COALESCE(SUM(CASE WHEN e.event_type='High-Risk Transaction' THEN e.event_count END),0) AS high_risk_txns,
    COALESCE(SUM(CASE WHEN e.event_type='Reconciliation Break' THEN e.event_count END),0) AS recon_breaks,
    COALESCE(SUM(CASE WHEN e.event_type='Limit Breach' THEN e.event_count END),0) AS limit_breaches,
    COALESCE(SUM(CASE WHEN e.event_type='Data Quality Issue' THEN e.event_count END),0) AS dq_issues
  FROM v_monthly_volume v
  LEFT JOIN v_monthly_event_counts e
    ON e.year_month = v.year_month
   AND e.region = v.region
   AND e.booking_location = v.booking_location
   AND e.team = v.team
   AND e.product = v.product
  GROUP BY 1,2,3,4,5,6,7
),
open_agg AS (
  SELECT
    s.year_month,
    s.region,
    s.booking_location,
    s.team,
    s.product,
    SUM(s.open_over_30) FILTER (WHERE s.event_type='Incident') AS open_incidents_over_30,
    SUM(s.open_over_sla) AS open_items_over_sla,
    SUM(s.overdue_count) FILTER (WHERE s.event_type='Overdue Task') AS overdue_tasks,
    SUM(s.overdue_count) FILTER (WHERE s.event_type='KYC Review Overdue') AS kyc_overdue
  FROM v_open_snapshot s
  GROUP BY 1,2,3,4,5
),
avg_inc_closure AS (
  SELECT
    date_trunc('month', event_date)::date AS year_month,
    region,
    booking_location,
    team,
    product,
    AVG(close_date - event_date) AS avg_incident_closure_days
  FROM v_events_clean
  WHERE event_type='Incident'
    AND status='Closed'
    AND close_date IS NOT NULL
  GROUP BY 1,2,3,4,5
)
SELECT
  b.year_month,
  b.region,
  b.booking_location,
  b.team,
  b.product,

  -- KRI_01: incident rate per 1k transactions
  CASE WHEN b.transactions_count>0 THEN (b.incidents::numeric / b.transactions_count)*1000 ELSE 0 END AS kri_01_incident_rate_per_1k_txn,

  -- KRI_02: aged open incidents >30 days per 10k clients (month-end)
  CASE WHEN b.clients_count>0 THEN (COALESCE(o.open_incidents_over_30,0)::numeric / b.clients_count)*10000 ELSE 0 END AS kri_02_aged_open_inc_over30_per_10k_clients,

  -- KRI_03: complaint rate per 10k clients
  CASE WHEN b.clients_count>0 THEN (b.complaints::numeric / b.clients_count)*10000 ELSE 0 END AS kri_03_complaint_rate_per_10k_clients,

  -- KRI_04: substantiated complaints per 10k clients
  CASE WHEN b.clients_count>0 THEN (b.substantiated_complaints::numeric / b.clients_count)*10000 ELSE 0 END AS kri_04_substantiated_complaints_per_10k_clients,

  -- KRI_05: processing error rate per 1k transactions
  CASE WHEN b.transactions_count>0 THEN (b.processing_errors::numeric / b.transactions_count)*1000 ELSE 0 END AS kri_05_processing_error_rate_per_1k_txn,

  -- KRI_06: open items over SLA per 10k clients (month-end)
  CASE WHEN b.clients_count>0 THEN (COALESCE(o.open_items_over_sla,0)::numeric / b.clients_count)*10000 ELSE 0 END AS kri_06_open_items_over_sla_per_10k_clients,

  -- KRI_07: overdue tasks per 10k clients (month-end)
  CASE WHEN b.clients_count>0 THEN (COALESCE(o.overdue_tasks,0)::numeric / b.clients_count)*10000 ELSE 0 END AS kri_07_overdue_tasks_per_10k_clients,

  -- KRI_08: KYC review overdue per 10k clients (month-end)
  CASE WHEN b.clients_count>0 THEN (COALESCE(o.kyc_overdue,0)::numeric / b.clients_count)*10000 ELSE 0 END AS kri_08_kyc_overdue_per_10k_clients,

  -- KRI_09: high-risk txns per 1k transactions
  CASE WHEN b.transactions_count>0 THEN (b.high_risk_txns::numeric / b.transactions_count)*1000 ELSE 0 END AS kri_09_high_risk_txn_per_1k_txn,

  -- KRI_10: recon breaks per 1k transactions
  CASE WHEN b.transactions_count>0 THEN (b.recon_breaks::numeric / b.transactions_count)*1000 ELSE 0 END AS kri_10_recon_breaks_per_1k_txn,

  -- KRI_11: limit breaches per 1k transactions
  CASE WHEN b.transactions_count>0 THEN (b.limit_breaches::numeric / b.transactions_count)*1000 ELSE 0 END AS kri_11_limit_breaches_per_1k_txn,

  -- KRI_12: data quality issues per 1k transactions
  CASE WHEN b.transactions_count>0 THEN (b.dq_issues::numeric / b.transactions_count)*1000 ELSE 0 END AS kri_12_dq_issues_per_1k_txn,

  -- KRI_13: avg incident closure time (days)
  COALESCE(a.avg_incident_closure_days,0) AS kri_13_avg_incident_closure_days

FROM base b
LEFT JOIN open_agg o
  ON o.year_month=b.year_month AND o.region=b.region AND o.booking_location=b.booking_location AND o.team=b.team AND o.product=b.product
LEFT JOIN avg_inc_closure a
  ON a.year_month=b.year_month AND a.region=b.region AND a.booking_location=b.booking_location AND a.team=b.team AND a.product=b.product;

-- Optional: scoring logic can be implemented in Power BI via DAX (preferred),
-- or in SQL by joining kri_thresholds row-by-row per KRI.