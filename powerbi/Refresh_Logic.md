# Refresh logic (Power BI)

## Option A — Folder refresh (CSV)
1. Place the `/data` folder contents in a stable location (e.g., OneDrive or local path).
2. In Power Query, use **Get Data → Folder** and set a `DataFolder` parameter.
3. Load:
   - `fact_events_raw.csv`, `fact_events_clean.csv`, `fact_volume_daily.csv`
   - `kri_values_sample.csv` (or compute in SQL)
   - `kri_thresholds.csv`, `exceptions_asof_2025-12-31.csv`, `dq_summary.csv`, `dq_issues_long.csv`
4. For scheduled refresh in Power BI Service:
   - Ensure the folder source is accessible (SharePoint/OneDrive recommended)
   - Configure dataset refresh schedule (daily/weekly)

## Option B — SQL refresh (recommended)
1. Load the CSVs into PostgreSQL using `01_create_tables.sql`
2. Create the views using `02_views_kri.sql`
3. Connect Power BI to PostgreSQL and import:
   - `v_kri_monthly`
   - `v_open_snapshot` (optional)
   - `v_events_clean` (optional, for exceptions)
4. Refresh the dataset in Power BI Service.

## Threshold recalibration
If you want thresholds to adapt:
- Recompute GreenMax/AmberMax on a rolling window (e.g., last 6–12 months)
- Version-control the threshold table; changes should be explainable (governance)