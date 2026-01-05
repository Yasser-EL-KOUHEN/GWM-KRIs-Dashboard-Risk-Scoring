# KRI Dashboard & Risk Scoring (Power BI + SQL + Excel) — Synthetic Project

This repository contains a **synthetic** dataset and an end-to-end blueprint for building a **Business Risk (non-financial risk) dashboard** with:
- **10+ Key Risk Indicators (KRIs)** across regions / booking locations / teams / products
- **traffic-light thresholds** and a **weighted risk score (0–100)**
- **trend + drill-down + top drivers**
- **exceptions list** (open items that require attention)
- **data quality checks** (raw vs clean, issue counts)

> Disclaimer: the dataset is **synthetic** (generated for demonstration/training). It is **not** UBS data.

---

## 1) Repository structure

- `data/`  
  CSVs for facts/dimensions, KRI thresholds, sample KRI outputs, exceptions, DQ outputs
- `sql/`  
  PostgreSQL scripts to create tables + views to compute KRIs
- `powerbi/`  
  Dashboard layout + DAX measures + refresh logic
- `images/`  
  **Mock screenshots** (Python-generated) showing the intended dashboard visuals

---

## 2) Data model

**Facts**
- `fact_events_raw.csv` — events with injected DQ issues (missing location/product, future date, negative amount)
- `fact_events_clean.csv` — filtered version used for KRI computation
- `fact_volume_daily.csv` — daily denominators (transactions + clients)

**Dimensions**
- `dim_date.csv`, `dim_booking_location.csv`, `dim_team.csv`, `dim_product.csv`

---

## 3) KRI definitions, thresholds, and weights

Thresholds are initial **distribution-based baselines**:
- **GreenMax** ≈ median (P50)
- **AmberMax** ≈ P85 (values above are **Red**)

In real production, these would be calibrated with Risk/Business owners and monitored for drift.

| KRI_ID | KRI | Definition | Green ≤ | Amber ≤ | Weight |
|---|---|---|---:|---:|---:|
| KRI_01 | Incident rate per 1k transactions | 1000 * Incidents / Transactions | 0.073 | 0.301 | 0.12 |
| KRI_02 | Aged open incidents (>30d) per 10k clients (month-end) | 10000 * OpenIncidentsOver30 / Clients | 0.000 | 56.276 | 0.10 |
| KRI_03 | Complaint rate per 10k clients | 10000 * Complaints / Clients | 0.000 | 7.262 | 0.08 |
| KRI_04 | Substantiated complaints per 10k clients | 10000 * SubstantiatedComplaints / Clients | 0.000 | 8.217 | 0.08 |
| KRI_05 | Processing error rate per 1k transactions | 1000 * ProcessingErrors / Transactions | 0.175 | 1.088 | 0.12 |
| KRI_06 | Open items over SLA per 10k clients (month-end) | 10000 * OpenItemsOverSLA / Clients | 175.439 | 416.876 | 0.10 |
| KRI_07 | Overdue tasks per 10k clients (month-end) | 10000 * OverdueTasks / Clients | 0.000 | 46.004 | 0.08 |
| KRI_08 | KYC review overdue per 10k clients (month-end) | 10000 * KYCOverdue / Clients | 0.000 | 22.016 | 0.10 |
| KRI_09 | High-risk transactions per 1k transactions | 1000 * HighRiskTxns / Transactions | 0.086 | 0.482 | 0.08 |
| KRI_10 | Reconciliation breaks per 1k transactions | 1000 * ReconBreaks / Transactions | 0.036 | 0.321 | 0.06 |
| KRI_11 | Limit breaches per 1k transactions | 1000 * LimitBreaches / Transactions | 0.000 | 0.105 | 0.06 |
| KRI_12 | Data quality issues per 1k transactions | 1000 * DataQualityIssues / Transactions | 0.074 | 0.366 | 0.07 |
| KRI_13 | Average incident closure time (days) | AVG(CloseDate - EventDate) for closed incidents | 4.750 | 17.631 | 0.05 |

---

## 4) Risk scoring logic

Each KRI is converted into **points**:
- Green → 0  
- Amber → 0.5  
- Red → 1

**Risk score (0–100)** for a given slice (Region/Location/Team/Product/Month):

`RiskScore = 100 * (Σ (Weightᵢ * Pointsᵢ)) / (Σ Weightᵢ)`

See `powerbi/DAX_Measures.md` for the exact DAX implementation.

---

## 5) Dashboard build (Power BI)

### Recommended approach (fastest)
1. Load `data/kri_values_sample.csv` (or `data/kri_long_sample.csv`) and `data/kri_thresholds.csv`
2. In Power Query: **unpivot** KRI columns into `KRI_Long` (see `powerbi/DAX_Measures.md`)
3. Add DAX measures:
   - `Points`, `Traffic Light`, `Weighted Contribution`, `Risk Score (0-100)`
4. Build pages following `powerbi/Dashboard_Layout.md`

### Optional (more realistic): SQL views
- Use `sql/01_create_tables.sql` to create tables
- Load CSVs using `COPY`
- Run `sql/02_views_kri.sql` and connect Power BI to `v_kri_monthly`

---

## 6) Exceptions list (operational follow-up)

Load `data/exceptions_asof_2025-12-31.csv` for a ready-made exceptions table including:
- open items over SLA
- high/critical severity
- overdue tasks
- missing mandatory fields
- high amount flags (>250k)

---

## 7) Data quality checks

Two outputs are provided:
- `data/dq_summary.csv` — counts by DQ issue type
- `data/dq_issues_long.csv` — record-level issues for drill-down

A PostgreSQL version is available in `sql/03_dq_checks.sql`.

---

## 8) Screenshots (mock)

The `images/` folder contains mock screenshots that illustrate the expected Power BI pages:
- `dashboard_overview_mock.png`
- `dashboard_trend_mock.png`
- `dashboard_top_drivers_mock.png`
- `dashboard_exceptions_mock.png`
- `data_quality_checks_mock.png`

---

## 9) How to refresh

See `powerbi/Refresh_Logic.md` for:
- CSV folder refresh
- SQL refresh (recommended)
- threshold recalibration idea
