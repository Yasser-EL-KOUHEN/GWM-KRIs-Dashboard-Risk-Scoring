# Power BI – DAX measures (KRI scoring)

This project is designed so you can build the dashboard **without** complex DAX over raw events.

## Recommended Power BI model (simple)

Load:
- `kri_values_sample.csv` (or use SQL view `v_kri_monthly`)
- `kri_thresholds.csv`
- `risk_score_sample.csv` (optional, validation only)
- `exceptions_asof_2025-12-31.csv` (exceptions table)
- `dq_summary.csv` and `dq_issues_long.csv` (data quality page)

### Power Query step (important): unpivot KRI columns
In **Power Query**:
1. Select `kri_values_sample`
2. Keep the dimension columns: `YearMonth, Region, BookingLocation, Team, Product`
3. Select the remaining KRI columns (those starting with `KRI_`)
4. Choose **Transform → Unpivot Columns**

You should end up with a long table called `KRI_Long`:
- YearMonth, Region, BookingLocation, Team, Product
- KRI_ID  (from the column name)
- KRI_Value

Rename the unpivot output columns to:

**Shortcut:** you can load `data/kri_long_sample.csv` directly (already unpivoted) and rename it to `KRI_Long`.

- `KRI_ID`
- `KRI_Value`

---

## DAX measures

### Points (0 / 0.5 / 1) based on thresholds
```DAX
Points :=
VAR v = SELECTEDVALUE ( KRI_Long[KRI_Value] )
VAR kri = SELECTEDVALUE ( KRI_Long[KRI_ID] )
VAR green =
    LOOKUPVALUE ( kri_thresholds[GreenMax], kri_thresholds[KRI_ID], kri )
VAR amber =
    LOOKUPVALUE ( kri_thresholds[AmberMax], kri_thresholds[KRI_ID], kri )
RETURN
    SWITCH (
        TRUE (),
        ISBLANK ( v ), BLANK (),
        v <= green, 0,
        v <= amber, 0.5,
        1
    )
```

### Traffic light label
```DAX
Traffic Light :=
VAR p = [Points]
RETURN
    SWITCH (
        TRUE (),
        ISBLANK ( p ), "No Data",
        p = 0, "Green",
        p = 0.5, "Amber",
        "Red"
    )
```

### Weighted contribution (per KRI row)
```DAX
Weighted Contribution :=
VAR w =
    LOOKUPVALUE ( kri_thresholds[Weight], kri_thresholds[KRI_ID], SELECTEDVALUE ( KRI_Long[KRI_ID] ) )
RETURN
    [Points] * w
```

### Risk score (0–100) for the current filter context
```DAX
Risk Score (0-100) :=
VAR weightedSum =
    SUMX (
        KRI_Long,
        VAR p = [Points]
        VAR w =
            LOOKUPVALUE ( kri_thresholds[Weight], kri_thresholds[KRI_ID], KRI_Long[KRI_ID] )
        RETURN
            IF ( ISBLANK ( p ), BLANK (), p * w )
    )
VAR weightSum =
    SUMX (
        KRI_Long,
        VAR p = [Points]
        VAR w =
            LOOKUPVALUE ( kri_thresholds[Weight], kri_thresholds[KRI_ID], KRI_Long[KRI_ID] )
        RETURN
            IF ( ISBLANK ( p ), BLANK (), w )
    )
RETURN
    DIVIDE ( weightedSum, weightSum ) * 100
```

### Top drivers (for bar chart)
Use `Weighted Contribution` by `KRI_ID` and sort descending.

---

## Notes
- Thresholds in `kri_thresholds.csv` are **distribution-based baselines** (P50=GreenMax, P85=AmberMax).
  In a real BRS environment they are calibrated with Risk/Business owners and monitored for drift.