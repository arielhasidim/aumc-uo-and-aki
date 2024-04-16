CREATE OR REPLACE TABLE `aumc_uo_and_aki.d3_kdigo_stages` AS
-- This query checks if the patient had AKI according to KDIGO 2012 AKI guideline.
-- AKI is calculated every time a creatinine or urine output (UO) measurement occurs or renal replacement therapy (RRT) begins.

-- Baseline creatinine is estimated by the lowest serum creatinine value in the last 7 days per patient.

-- Creatinine stage 3 by RRT initiation was added. Since RRT can be also used in ESRD without AKI, 
-- it has been looked at only if AKI has been diagnosed by creatinine in the last 48 hours.

-- Fourth and final creatinine criterion for stage 3 in patients under the age of 18 has been left out (decrease in eGFR to <35 ml/min per 1.73 m2).
WITH
  uo_stg AS ( -- stages for UO
    SELECT
      uo.stay_id,
      uo.charttime,
      uo.weight_first,
      uo.uo_rt_6hr,
      uo.uo_rt_12hr,
      uo.uo_rt_24hr,
      CASE -- AKI stages according to urine output
      -- require hourly urine output for every hour in the last 6 hours period at least.
        WHEN uo.uo_count_6hr < 6
        OR uo.weight_first IS NULL THEN NULL
        -- require the hourly UO rate to be calculated for every hour in the period.
        -- i.e. for uo rate over 24 hours, require documentation of UO rate for 24 hours.
        WHEN uo.uo_count_24hr = 24
        AND uo.uo_rt_24hr < 0.3
        AND uo.uo_rt_6hr < 0.5 THEN 3
        WHEN uo.uo_count_12hr = 12
        AND uo.uo_rt_12hr = 0
        AND uo.uo_rt_6hr < 0.5 THEN 3
        WHEN uo.uo_count_12hr = 12
        AND uo.uo_rt_12hr < 0.5
        AND uo.uo_rt_6hr < 0.5 THEN 2
        WHEN uo.uo_rt_6hr < 0.5 THEN 1
        ELSE 0
      END AS aki_stage_uo
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
  uo.uo_rt_6hr,
  uo.uo_rt_12hr,
  uo.uo_rt_24hr,
  uo.aki_stage_uo,
  GREATEST( -- Classify AKI using both creatinine/urine output/active RRT criteria
    COALESCE(uo.aki_stage_uo, 0)
  ) AS aki_stage
FROM
  `original.admissions` ie
  LEFT JOIN tm_stg tm ON ie.admissionid = tm.stay_id -- get all possible charttimes as listed in tm_stg
  LEFT JOIN uo_stg uo ON ie.admissionid = uo.stay_id
  AND tm.charttime = uo.charttime