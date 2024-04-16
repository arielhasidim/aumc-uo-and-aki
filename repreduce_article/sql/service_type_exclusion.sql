SELECT
    COUNT(DISTINCT STAY_ID) icu_stays,
    COUNT(STAY_ID) UO_records
FROM
    `aumc_uo_and_aki.a_urine_output_raw`
WHERE
    lower(SERVICE) = "mc"
