SELECT
    COUNT(DISTINCT STAY_ID) icu_stays,
    COUNT(STAY_ID) UO_records
FROM
    `aumc_uo_and_aki.a_urine_output_raw`
WHERE
    STAY_ID IN (
        SELECT
            admissionid AS STAY_ID
        FROM
            `original.numericitems`
        WHERE
            ITEMID IN (19921, 19922) -- Urethral stent
        GROUP BY
            admissionid
    )
    AND lower(SERVICE) != "mc"
