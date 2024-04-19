SELECT
    a.admissionid STAY_ID,
    b.first_kdigo_uo,
    b.first_aki_id,
    b.max_uo_stage
FROM
    `original.admissions` a
    LEFT JOIN (
        SELECT
            a.stay_id,
            ARRAY_AGG(
                a.aki_stage_uo IGNORE NULLS
                ORDER BY
                    a.charttime ASC
                LIMIT
                    1
            ) [OFFSET(0)] first_kdigo_uo,
            ARRAY_AGG(
                c.AKI_ID IGNORE NULLS
                ORDER BY
                    c.AKI_START ASC
                LIMIT
                    1
            ) [OFFSET(0)] first_aki_id,
            ARRAY_AGG(
                c.WORST_STAGE IGNORE NULLS
                ORDER BY
                    c.AKI_START ASC
                LIMIT
                    1
            ) [OFFSET(0)] max_uo_stage
        FROM
            `aumc_uo_and_aki.d3_kdigo_stages` a
            LEFT JOIN (
                SELECT
                    stay_id,
                    MIN(CHARTTIME) AS first_record
                FROM
                    `aumc_uo_and_aki.a_urine_output_raw`
                GROUP BY
                    stay_id
            ) b ON b.stay_id = a.stay_id
            LEFT JOIN `aumc_uo_and_aki.e_aki_analysis` c ON c.stay_id = a.stay_id
            AND c.AKI_START <= DATETIME_ADD(b.first_record, INTERVAL 24 HOUR)
            AND NO_START = 0
        WHERE
            a.charttime <= DATETIME_ADD(b.first_record, INTERVAL 24 HOUR)
        GROUP BY
            stay_id
    ) b ON b.STAY_ID = a.admissionid
WHERE
    -- First ICU stay in hostpital admission
    a.admissioncount = 1
    -- ICU stay type inclusion
    AND a.location != "MC"
    -- Exclude all stays with ureteral stent or GU irrigation 
    -- (See https://github.com/MIT-LCP/mimic-code/issues/745 for GU irrig.)
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
    AND first_kdigo_uo IS NOT NULL