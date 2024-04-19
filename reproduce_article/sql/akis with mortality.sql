CREATE TEMP FUNCTION GREATEST_ARRAY (arr ANY TYPE) AS (
  (
    SELECT
      MAX(a)
    FROM
      UNNEST (arr) a
    WHERE
      a IS NOT NULL
  )
);

WITH
  HADM_AKI_COUNT AS (
    SELECT
      aa.AKI_ID,
      COUNT(bb.AKI_ID) STAY_RESOLVED_UO_AKI_PRE
    FROM
      `aumc_uo_and_aki.e_aki_analysis` aa
      LEFT JOIN `aumc_uo_and_aki.e_aki_analysis` bb ON bb.STAY_ID = aa.STAY_ID
      AND bb.AKI_STOP < aa.AKI_START
    GROUP BY
      aa.AKI_ID
  ),
  admit AS (
    SELECT
      *,
      CASE
        WHEN admissionyeargroup LIKE "2003%" THEN DATETIME_ADD(
          "2003-01-01 00:00:00",
          INTERVAL CAST((admittedat / 1000) AS INT64) SECOND
        )
        ELSE DATETIME_ADD(
          "2010-01-01 00:00:00",
          INTERVAL CAST((admittedat / 1000) AS INT64) SECOND
        )
      END AS admit_time
    FROM
      `original.admissions`
  ),
  HADM_LATEST_VITAL_SIGN_OR_UO AS (
    SELECT
      admissionid STAY_ID,
      MAX(measuredat) LATEST_POSITIVE_VITAL_SIGN
    FROM
      `original.numericitems`
    WHERE
      ITEMID IN (
        6640, -- Hartfrequentie (/min)
        6709, -- Saturatie (Monitor) (None)
        6641, 6642, 6643, -- ABP systolisch/gemiddeld/diastolisch (mmHg)
        8794, --UrineCAD ("Foley")
        8796, --UrineSupraPubis ("Suprapubic")
        8798, --UrineSpontaan ("Void")
        8800, --UrineIncontinentie ("Incontinence (urine leakage)")
        8803, --UrineUP ("Ileoconduit")
        10743, --Nefrodrain li Uit ("L Nephrostomy")
        10745, --Nefrodrain re Uit ("R Nephrostomy")
        19921, --UrineSplint Li ("L Ureteral Stent")
        19922 --UrineSplint Re ("R Ureteral Stent")
      )
      AND CASE
        WHEN ITEMID = 6709 THEN VALUE > 50
        WHEN ITEMID IN (6641, 6642, 6643) THEN VALUE > 20
        ELSE VALUE > 0
      END
    GROUP BY
      STAY_ID
  ),
  HADM_DEATH_OR_DISCHARGE_TIME AS (
    SELECT
      a.admissionid STAY_ID,
      GREATEST_ARRAY (
        [
          a.dateofdeath,
          a.dischargedat,
          b.LATEST_POSITIVE_VITAL_SIGN
        ]
      ) DEATH_OR_DISCHARGE_TIME
    FROM
      `original.admissions` a
      LEFT JOIN HADM_LATEST_VITAL_SIGN_OR_UO b ON b.STAY_ID = a.admissionid
  )
SELECT
  a.AKI_ID,
  a.STAY_ID,
  a.SUBJECT_ID,
  a.AKI_START,
  DATETIME_ADD(
    admit_time,
    INTERVAL CAST((DEATH_OR_DISCHARGE_TIME / 1000) AS INT64) SECOND
  ) DEATH_OR_DISCH,
  DATETIME_DIFF(
    DATETIME_ADD(
      admit_time,
      INTERVAL CAST((DEATH_OR_DISCHARGE_TIME / 1000) AS INT64) SECOND
    ),
    a.AKI_START,
    HOUR
  ) / 24 FIRST_AKI_TO_DEATH_OR_DISCH,
  IF(c.dateofdeath IS NULL, 0, 1) AS HADM_DEATH_FLAG,
  a.WORST_STAGE PEAK_UO_STAGE,
  a.NO_START,
  b.STAY_RESOLVED_UO_AKI_PRE
FROM
  `aumc_uo_and_aki.e_aki_analysis` a
  LEFT JOIN HADM_AKI_COUNT b ON b.AKI_ID = a.AKI_ID
  LEFT JOIN admit c ON c.admissionid = a.STAY_ID
  LEFT JOIN HADM_DEATH_OR_DISCHARGE_TIME d ON d.STAY_ID = a.STAY_ID