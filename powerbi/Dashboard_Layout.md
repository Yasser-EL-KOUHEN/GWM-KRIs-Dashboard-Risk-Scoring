# Dashboard layout (Power BI)

## Page 1 — Overview (Risk posture)
**Slicers**: YearMonth, Region, BookingLocation, Team, Product

**Visuals**
1. **Card**: `Risk Score (0-100)`
2. **Matrix heatmap**: Rows = Team, Columns = BookingLocation, Values = Risk Score  
   - Add conditional formatting (traffic-light or gradient)
3. **Line chart**: Risk Score by YearMonth (trend)
4. **Bar chart (Top Drivers)**: KRI_ID by Weighted Contribution (descending)
5. **Table (KRI status)**: KRI_ID, KRI_Value, Traffic Light, GreenMax/AmberMax (optional)

## Page 2 — Drill-down (KRI deep dive)
**Slicers**: KRI_ID + the same dims

**Visuals**
- Line chart: KRI_Value over time
- Bar chart: KRI_Value by BookingLocation (or Team)
- Small table: threshold values + current KRI value + traffic light

## Page 3 — Exceptions & actions
Load `exceptions_asof_2025-12-31.csv` (or compute from SQL).
**Visuals**
- Table: EventID, EventType, Severity, AgeDays, SLA_Days, ExceptionReason, BookingLocation, Team, Product
- Bar chart: exceptions count by EventType / Severity
- KPI cards: #Open exceptions, #Over SLA, #High/Critical

## Page 4 — Data quality
Load `dq_summary.csv` + `dq_issues_long.csv` (or use SQL in `03_dq_checks.sql`).
**Visuals**
- Bar chart: DQ issue counts (dq_summary)
- Table: DQ issue list (dq_issues_long) with filters by SourceSystem/EventType
- Card: raw events rows vs clean events rows (if you load both raw and clean)