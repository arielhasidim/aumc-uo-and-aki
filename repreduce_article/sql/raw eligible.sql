SELECT
  *
FROM
  `aumc_uo_and_aki.a_urine_output_raw`
WHERE
  STAY_ID NOT IN (
    SELECT
      admissionid AS STAY_ID
    FROM
      `original.numericitems`
    WHERE
      ITEMID IN (19922, 19921, 8800) -- Urethral stent, Urine Incontinence
    GROUP BY
      admissionid
  )
  AND NOT (
    VALUE > 5000
    OR VALUE < 0
  )
  AND lower(SERVICE) != "mc"
