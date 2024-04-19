WITH aa AS (
        SELECT
            STAY_ID,
            CHARTTIME
        FROM
            `aumc_uo_and_aki.a_urine_output_raw` uo
        GROUP BY
            STAY_ID,
            CHARTTIME
    ),
    ab AS (
        SELECT
            a.*,
            b.ITEMID,
            b.VALUE,
            b.LABEL
        FROM
            aa a
            LEFT JOIN `aumc_uo_and_aki.a_urine_output_raw` b ON b.STAY_ID = a.STAY_ID
            AND b.CHARTTIME = a.CHARTTIME
        ORDER BY
            STAY_ID,
            CHARTTIME,
            ITEMID
    ),
    ac AS (
        SELECT
            STAY_ID,
            CHARTTIME,
            STRING_AGG(label) label,
            COUNT(STAY_ID) COUNT,
            IF(
                MIN(VALUE) = MAX(VALUE),
                "Equal volume",
                "Different volume"
            ) AS same_value
        FROM
            ab
        GROUP BY
            STAY_ID,
            CHARTTIME
    ),
    ad AS (
        SELECT
            COUNT(CHARTTIME) COUNT,
            label,
            same_value
        FROM
            ac
        WHERE
            COUNT > 1
        GROUP BY
            label,
            same_value
    )
SELECT
    *
FROM
    ac
WHERE
    COUNT > 1
