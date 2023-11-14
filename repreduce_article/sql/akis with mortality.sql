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
                    "2009-01-01 00:00:00",
                    INTERVAL CAST((admittedat / 1000) AS INT64) SECOND
                )
            END AS admit_time
        FROM
            `original.admissions`
    )

SELECT
  a.AKI_ID,
  a.STAY_ID,
  a.SUBJECT_ID,
  a.AKI_START,
  CASE
    WHEN c.dateofdeath is not null then datetime_add(admit_time, INTERVAL CAST((dateofdeath / 1000) AS INT64) SECOND)
    ELSE datetime_add(admit_time, INTERVAL CAST((dischargedat / 1000) AS INT64) SECOND)
  end as DEATH_OR_DISCH,
  DATETIME_DIFF(
    IF(c.dateofdeath is not null, 
    datetime_add(admit_time, INTERVAL CAST((dateofdeath / 1000) AS INT64) SECOND),
    datetime_add(admit_time, INTERVAL CAST((dischargedat / 1000) AS INT64) SECOND)
    ),
    a.AKI_START,
    HOUR
  ) / 24  FIRST_AKI_TO_DEATH_OR_DISCH,
  IF(c.dateofdeath is null, 0, 1) AS HADM_DEATH_FLAG,
  a.WORST_STAGE PEAK_UO_STAGE,
  a.NO_START,
  b.STAY_RESOLVED_UO_AKI_PRE
FROM
  `aumc_uo_and_aki.e_aki_analysis` a
  LEFT JOIN HADM_AKI_COUNT b ON b.AKI_ID = a.AKI_ID
  LEFT JOIN admit c ON c.admissionid = a.STAY_ID
