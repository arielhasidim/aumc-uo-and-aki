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
      ITEMID IN (8800) -- Incontinence (Urine leakage)
    GROUP BY
      admissionid
  )
  AND STAY_ID NOT IN (
    SELECT
      admissionid AS STAY_ID
    FROM
      `original.numericitems`
    WHERE
      ITEMID IN (19921, 19922) -- Urethral stent
    GROUP BY
      admissionid
  )
  AND LOWER(SERVICE) != "mc"
  AND (
    VALUE > 5000
    OR VALUE < 0
  )