SELECT
  a.admissionid STAY_ID,
  CASE
      WHEN a.weightgroup LIKE "%59%" THEN 55
      WHEN a.weightgroup LIKE "%60%" THEN 65
      WHEN a.weightgroup LIKE "%70%" THEN 75
      WHEN a.weightgroup LIKE "%80%" THEN 85
      WHEN a.weightgroup LIKE "%90%" THEN 95
      WHEN a.weightgroup LIKE "%100%" THEN 105
      WHEN a.weightgroup LIKE "%110%" THEN 115
      ELSE NULL
  END AS WEIGHT_ADMIT,
  c.FIRST_STAGE_UO_CONS AS FIRST_STAGE_NEW_CONS,
  c.AKI_STAGE_UO_CONS AS MAX_STAGE_NEW_CONS,
  d3.FIRST_STAGE_UO_CONS AS FIRST_STAGE_NEW_CONS_95_20,
  d3.AKI_STAGE_UO_CONS AS MAX_STAGE_NEW_CONS_95_20,
  d4.FIRST_STAGE_UO_CONS AS FIRST_STAGE_NEW_CONS_99_20,
  d4.AKI_STAGE_UO_CONS AS MAX_STAGE_NEW_CONS_99_20,
  IFNULL(
        (a.dateofdeath - a.admittedat) / 1000 / 60 / 60 / 24,
        365
    ) AS FOLLOWUP_DAYS,
    IF(a.dateofdeath IS NOT NULL, 1, 0) AS DEATH_FLAG,
FROM
  `original.admissions` a
  LEFT JOIN (
    SELECT
      a.STAY_ID,
      MAX(a.AKI_STAGE_UO_CONS) AKI_STAGE_UO_CONS,
      ARRAY_AGG(
        a.AKI_STAGE_UO_CONS IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_CONS
    FROM
      `aumc_uo_and_aki.d3_kdigo_stages` a
    LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `aumc_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
      AS b ON b.STAY_ID = a.STAY_ID
    WHERE a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
    GROUP BY
      STAY_ID
  ) c ON c.STAY_ID = a.admissionid
  LEFT JOIN (
    SELECT
      a.STAY_ID,
      MAX(a.AKI_STAGE_UO_CONS) AKI_STAGE_UO_CONS,
      ARRAY_AGG(
        a.AKI_STAGE_UO_CONS IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_CONS
    FROM
      `aumc_uo_and_aki.d3_kdigo_stages_9520_temp` a
    LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `aumc_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
      AS b ON b.STAY_ID = a.STAY_ID
    WHERE a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
    GROUP BY
      STAY_ID
  ) d3 ON d3.STAY_ID = a.admissionid
  LEFT JOIN (
    SELECT
      a.STAY_ID,
      MAX(a.AKI_STAGE_UO_CONS) AKI_STAGE_UO_CONS,
      ARRAY_AGG(
        a.AKI_STAGE_UO_CONS IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_CONS
    FROM
      `aumc_uo_and_aki.d3_kdigo_stages_9920_temp` a
    LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `aumc_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
      AS b ON b.STAY_ID = a.STAY_ID
    WHERE a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
    GROUP BY
      STAY_ID
  ) d4 ON d4.STAY_ID = a.admissionid
  LEFT JOIN (
    SELECT
      a.STAY_ID,
      MAX(a.AKI_STAGE_UO_CONS) AKI_STAGE_UO_CONS,
      ARRAY_AGG(
        a.AKI_STAGE_UO_CONS IGNORE NULLS
        ORDER BY
          a.CHARTTIME ASC
        LIMIT
          1
      ) [OFFSET(0)] FIRST_STAGE_UO_CONS
    FROM
      `aumc_uo_and_aki.d3_kdigo_stages_9920_temp` a
    LEFT JOIN  (SELECT STAY_ID, MIN(CHARTTIME) CHARTIME FROM `aumc_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID)
      AS b ON b.STAY_ID = a.STAY_ID
    WHERE a.CHARTTIME < DATETIME_ADD(b.CHARTIME, INTERVAL 72 HOUR)
    GROUP BY
      STAY_ID
  ) d5 ON d5.STAY_ID = a.admissionid
WHERE
    -- First ICU stay in hostpital admission
    a.admissioncount = 1
    -- ICU stay type inclusion
    AND a.location != "MC"
    -- Exclude all stays with ureteral stent or GU irrigation 
    AND a.admissionid NOT IN (
        SELECT
            admissionid AS STAY_ID
        FROM
            `original.numericitems`
        WHERE
            ITEMID IN (19922, 19921, 8800)
        GROUP BY
            admissionid
    )