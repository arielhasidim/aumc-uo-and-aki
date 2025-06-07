CREATE OR REPLACE TABLE
  `aumc_uo_and_aki.d3_kdigo_stages` AS
  -- This query checks if the patient had AKI according to KDIGO 2012 AKI guideline.
  -- AKI is calculated every time a urine output (UO) measurement occurs.
  -- Hourly UOs are imputed according to DOI:XXX
  -- KDIGO-UO are calculated twice:
  --  1. For an avarage UO rates per KG for 6, 12 and 24 hours (aki_stage_uo_mean)
  --  2. For hourly UO rates per KG in a consecutive manner for 6, 12 and 24 hours (aki_stage_uo_cons)
WITH
  uo_stg AS ( -- stages for UO
    SELECT
      uo.stay_id,
      uo.charttime,
      uo.weight_first,
      uo.uo_rt_kg_6hr,
      uo.uo_rt_kg_12hr,
      uo.uo_rt_kg_24hr,
      uo.uo_max_kg_6hr,
      uo.uo_max_kg_12hr,
      uo.uo_max_kg_24hr,
      CASE -- mean hourly UO meeting KDIGO criteria.
      -- require hourly urine output for every hour in the last 6 hours period at least.
        WHEN uo.uo_rt_kg_6hr IS NULL THEN NULL
        -- require the hourly UO rate to be calculated for every hour in the period.
        -- i.e. for uo rate over 24 hours, require documentation of UO rate for 24 hours.
        -- using avarage hourly rate, it means that individual hour can be bigger than the threshold
        WHEN uo.uo_rt_kg_24hr < 0.3
        AND uo.uo_rt_kg_6hr < 0.5 THEN 3
        WHEN uo.uo_rt_kg_12hr = 0
        AND uo.uo_rt_kg_6hr < 0.5 THEN 3
        WHEN uo.uo_rt_kg_12hr < 0.5
        AND uo.uo_rt_kg_6hr < 0.5 THEN 2
        WHEN uo.uo_rt_kg_6hr < 0.5 THEN 1
        ELSE 0
      END AS aki_stage_uo_mean,
      CASE -- UO meeting KDIGO criteria in each consecutive hour
      -- require hourly urine output for every hour in the last 6 hours period at least.
        WHEN uo.uo_max_kg_6hr IS NULL THEN NULL
        -- require the hourly UO rate to be calculated for every hour in the period.
        -- i.e. for uo rate over 24 hours, require documentation of UO rate for 24 hours.
        -- using maximum hourly rate, it means that all hours in interval must meat criteria consecutivly
        WHEN uo.uo_max_kg_24hr < 0.3
        AND uo.uo_max_kg_6hr < 0.5 THEN 3
        WHEN uo.uo_max_kg_12hr = 0
        AND uo.uo_max_kg_6hr < 0.5 THEN 3
        WHEN uo.uo_max_kg_12hr < 0.5
        AND uo.uo_max_kg_6hr < 0.5 THEN 2
        WHEN uo.uo_max_kg_6hr < 0.5 THEN 1
        ELSE 0
      END AS aki_stage_uo_cons
    FROM
      `aumc_uo_and_aki.d1_kdigo_uo` uo
  ),
  tm_stg AS ( -- get all chart times documented
    SELECT
      stay_id,
      charttime
    FROM
      uo_stg
  )
SELECT
  ie.patientid subject_id,
  ie.admissionid stay_id,
  tm.charttime,
  CASE
      WHEN w.weightgroup LIKE "%59%" THEN 55
      WHEN w.weightgroup LIKE "%60%" THEN 65
      WHEN w.weightgroup LIKE "%70%" THEN 75
      WHEN w.weightgroup LIKE "%80%" THEN 85
      WHEN w.weightgroup LIKE "%90%" THEN 95
      WHEN w.weightgroup LIKE "%100%" THEN 105
      WHEN w.weightgroup LIKE "%110%" THEN 115
      ELSE NULL
  END AS WEIGHT_ADMIT,
  uo.uo_rt_kg_6hr,
  uo.uo_rt_kg_12hr,
  uo.uo_rt_kg_24hr,
  uo.uo_max_kg_6hr,
  uo.uo_max_kg_12hr,
  uo.uo_max_kg_24hr,
  uo.aki_stage_uo_mean,
  uo.aki_stage_uo_cons,
  GREATEST( -- Classify AKI using both creatinine/urine output/active RRT criteria
    COALESCE(uo.aki_stage_uo_mean, 0)
  ) AS aki_stage_mean,
  GREATEST( -- Classify AKI using both creatinine/urine output/active RRT criteria
    COALESCE(uo.aki_stage_uo_cons, 0)
  ) AS aki_stage_cons
FROM
  `original.admissions` ie
  LEFT JOIN tm_stg tm ON ie.admissionid = tm.stay_id -- get all possible charttimes as listed in tm_stg
  LEFT JOIN uo_stg uo ON ie.admissionid = uo.stay_id
  AND tm.charttime = uo.charttime
  LEFT JOIN `original.admissions` w ON w.admissionid = ie.admissionid