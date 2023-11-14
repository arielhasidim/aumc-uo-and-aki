
SELECT
  COUNT(STAY_ID) UO_records
FROM
  `aumc_uo_and_aki.a_urine_output_raw`
WHERE
  STAY_ID NOT IN (
    SELECT
      admissionid AS STAY_ID
    FROM
      `original.numericitems`
    WHERE
      ITEMID IN (226558, 226557) -- Urethral stent
    GROUP BY
      admissionid
  )
  AND (
    VALUE > 5000
    OR VALUE < 0
  )
