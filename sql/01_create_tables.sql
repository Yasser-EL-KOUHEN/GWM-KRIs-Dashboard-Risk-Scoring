-- PostgreSQL schema for the synthetic KRI dashboard project.
-- Assumptions:
-- 1) You load the CSVs from /data using COPY (or your preferred ETL).
-- 2) Event dates are in YYYY-MM-DD format.
-- 3) This is a *synthetic* dataset (training/demo only).

DROP TABLE IF EXISTS fact_events_raw;
DROP TABLE IF EXISTS fact_volume_daily;
DROP TABLE IF EXISTS dim_booking_location;
DROP TABLE IF EXISTS dim_team;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS kri_thresholds;

CREATE TABLE dim_date (
  date DATE PRIMARY KEY,
  year INT,
  month INT,
  month_name TEXT,
  quarter TEXT,
  week INT
);

CREATE TABLE dim_booking_location (
  booking_location TEXT PRIMARY KEY,
  region TEXT
);

CREATE TABLE dim_team (
  team TEXT PRIMARY KEY
);

CREATE TABLE dim_product (
  product TEXT PRIMARY KEY
);

CREATE TABLE fact_volume_daily (
  date DATE,
  booking_location TEXT,
  region TEXT,
  team TEXT,
  product TEXT,
  transactions_count INT,
  clients_count INT
);

CREATE TABLE fact_events_raw (
  event_id TEXT PRIMARY KEY,
  event_type TEXT,
  event_date DATE,
  close_date DATE,
  status TEXT,
  booking_location TEXT,
  region TEXT,
  team TEXT,
  product TEXT,
  severity TEXT,
  root_cause TEXT,
  amount_chf NUMERIC,
  is_repeat INT,
  mandatory_fields_missing_count INT,
  sla_days INT,
  due_date DATE,
  is_substantiated INT,
  client_segment TEXT,
  source_system TEXT
);

CREATE TABLE kri_thresholds (
  kri_id TEXT PRIMARY KEY,
  kri_name TEXT,
  frequency TEXT,
  source_tables TEXT,
  direction TEXT,
  greenmax NUMERIC,
  ambermax NUMERIC,
  weight NUMERIC,
  unit TEXT
);

-- Indexes (optional but helps interactive dashboard performance)
CREATE INDEX IF NOT EXISTS ix_events_date ON fact_events_raw(event_date);
CREATE INDEX IF NOT EXISTS ix_events_dims ON fact_events_raw(booking_location, team, product, event_type);
CREATE INDEX IF NOT EXISTS ix_volume_dims ON fact_volume_daily(date, booking_location, team, product);

-- Example COPY commands (adjust paths):
-- COPY dim_date FROM '/path/dim_date.csv' WITH (FORMAT csv, HEADER true);
-- COPY dim_booking_location FROM '/path/dim_booking_location.csv' WITH (FORMAT csv, HEADER true);
-- COPY dim_team FROM '/path/dim_team.csv' WITH (FORMAT csv, HEADER true);
-- COPY dim_product FROM '/path/dim_product.csv' WITH (FORMAT csv, HEADER true);
-- COPY fact_volume_daily FROM '/path/fact_volume_daily.csv' WITH (FORMAT csv, HEADER true);
-- COPY fact_events_raw FROM '/path/fact_events_raw.csv' WITH (FORMAT csv, HEADER true);
-- COPY kri_thresholds FROM '/path/kri_thresholds.csv' WITH (FORMAT csv, HEADER true);