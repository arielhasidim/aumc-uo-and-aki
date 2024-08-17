WITH
    count_compartments AS (
        SELECT
            STAY_ID,
            (NON_BLADDER + BLADDER) compartment_count
        FROM
            (
                SELECT
                    a.admissionid STAY_ID,
                    COUNT(DISTINCT b.ITEMID) NON_BLADDER,
                    IF(SUM(c.ITEMID) IS NULL, 0, 1) AS BLADDER,
                FROM
                    `original.admissions` a
                    LEFT JOIN `aumc_uo_and_aki.a_urine_output_raw` b ON b.STAY_ID = a.admissionid
                    AND b.ITEMID IN (10743, 10745, 226584)
                    LEFT JOIN `aumc_uo_and_aki.a_urine_output_raw` c ON c.STAY_ID = a.admissionid
                    AND c.ITEMID NOT IN (10743, 10745, 226584)
                GROUP BY
                    a.admissionid
            )
    )
    -- select eligible ICU stays
SELECT
    a.admissionid STAY_ID,
    a.patientid SUBJECT_ID,
    d.FIRST_STAGE_UO_CONS AS FIRST_STAGE_NEW_CONS,
    d.AKI_STAGE_UO_CONS AS MAX_STAGE_NEW_CONS,
    d.FIRST_POSITIVE_STAGE_UO_CONS_TIME,
    d.FIRST_POSITIVE_STAGE_UO_MEAN_TIME,
    d.FIRST_STAGE_UO_MEAN AS FIRST_STAGE_NEW_MEAN,
    d.AKI_STAGE_UO_MEAN AS MAX_STAGE_NEW_MEAN,
    IFNULL(
        ROUND((a.dateofdeath - a.admittedat) / 1000 / 60 / 60 / 24),
        365
    ) AS FOLLOWUP_DAYS,
    IF(a.dateofdeath IS NOT NULL, 1, 0) AS DEATH_FLAG,
    COMPARTMENT_COUNT
FROM
    `original.admissions` a
    LEFT JOIN (
        SELECT
            a.STAY_ID,
            MAX(a.AKI_STAGE_UO_CONS) AKI_STAGE_UO_CONS,
            MAX(a.AKI_STAGE_UO_MEAN) AKI_STAGE_UO_MEAN,
            ARRAY_AGG(
                a.AKI_STAGE_UO_CONS IGNORE NULLS
                ORDER BY
                    a.CHARTTIME ASC
                LIMIT
                    1
            ) [OFFSET(0)] FIRST_STAGE_UO_CONS,
            ARRAY_AGG(
                a.AKI_STAGE_UO_MEAN IGNORE NULLS
                ORDER BY
                    a.CHARTTIME ASC
                LIMIT
                    1
            ) [OFFSET(0)] FIRST_STAGE_UO_MEAN,
            MIN(b.CHARTTIME) FIRST_POSITIVE_STAGE_UO_CONS_TIME,
            MIN(d.CHARTTIME) FIRST_POSITIVE_STAGE_UO_MEAN_TIME
        FROM
            `aumc_uo_and_aki.d3_kdigo_stages` a
            LEFT JOIN (
                SELECT
                    STAY_ID,
                    MIN(CHARTTIME) CHARTIME
                FROM
                    `aumc_uo_and_aki.a_urine_output_raw`
                GROUP BY
                    STAY_ID
            ) AS C ON C.STAY_ID = a.STAY_ID
            LEFT JOIN `aumc_uo_and_aki.d3_kdigo_stages` b ON b.stay_id = a.STAY_ID
            AND b.AKI_STAGE_UO_CONS > 0
            AND b.CHARTTIME < DATETIME_ADD(C.CHARTIME, INTERVAL 72 HOUR)
            LEFT JOIN `aumc_uo_and_aki.d3_kdigo_stages` d
              ON d.stay_id = a.STAY_ID AND d.AKI_STAGE_UO_MEAN > 0 AND d.CHARTTIME < DATETIME_ADD(C.CHARTIME, INTERVAL 72 HOUR)
        WHERE
            a.CHARTTIME < DATETIME_ADD(C.CHARTIME, INTERVAL 72 HOUR)
        GROUP BY
            STAY_ID
    ) d ON d.STAY_ID = a.admissionid
    LEFT JOIN count_compartments e ON e.STAY_ID = a.admissionid
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