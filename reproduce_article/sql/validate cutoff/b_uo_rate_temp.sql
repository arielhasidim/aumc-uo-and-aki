CREATE OR REPLACE TABLE `aumc_uo_and_aki.b_uo_rate_temp` AS

-- UO rate table with validity according to time interval length and 
-- source (cut-off for 95% precentile)
WITH
    uo_with_intervals_sources_and_weight AS (
        -- Raw UO with its source and charttime, preceding charttime in the 
        -- same compartment, and calculated time interval
        SELECT
            a.SUBJECT_ID,
            a.STAY_ID,
            a.VALUE,
            a.CHARTTIME,
            a.ITEMID,
            a.SERVICE,
            a.LABEL,
            MAX(b.CHARTTIME) AS LAST_CHARTTIME,
            (
                DATETIME_DIFF(a.CHARTTIME, MAX(b.CHARTTIME), SECOND) / 60
            ) AS TIME_INTERVAL,
            CASE
                WHEN w.weightgroup LIKE "%59%" THEN 55
                WHEN w.weightgroup LIKE "%60%" THEN 65
                WHEN w.weightgroup LIKE "%70%" THEN 75
                WHEN w.weightgroup LIKE "%80%" THEN 85
                WHEN w.weightgroup LIKE "%90%" THEN 95
                WHEN w.weightgroup LIKE "%100%" THEN 105
                WHEN w.weightgroup LIKE "%110%" THEN 115
                ELSE NULL
            END AS WEIGHT_ADMIT
        FROM
            `aumc_uo_and_aki.a_urine_output_raw` a
            LEFT JOIN `aumc_uo_and_aki.a_urine_output_raw` b ON b.STAY_ID = a.STAY_ID
            AND b.CHARTTIME < a.CHARTTIME
            -- The rates for right and left nephrostomy and ileoconduit will be calculated from 
            -- the last identical item as each of them represents a different and unique compartment 
            -- other than the urinary bladder.
            AND IF(
                a.ITEMID IN (10743, 10745, 8803),
                b.ITEMID = a.ITEMID,
                b.ITEMID NOT IN (10743, 10745, 8803)
            )
            LEFT JOIN `original.admissions` w ON w.admissionid = a.STAY_ID
        GROUP BY
            a.SUBJECT_ID,
            a.STAY_ID,
            a.VALUE,
            a.CHARTTIME,
            a.ITEMID,
            a.LABEL,
            w.weightgroup,
            a.SERVICE
    ),
    excluding AS (
        -- excluding unreliable ICU stays
        SELECT
            SUBJECT_ID,
            STAY_ID,
            label AS SOURCE,
            VALUE,
            CHARTTIME,
            LAST_CHARTTIME,
            TIME_INTERVAL,
            WEIGHT_ADMIT,
            SERVICE
        FROM
            uo_with_intervals_sources_and_weight
        WHERE
            -- Exclude all stays with ureteral stent
            -- for amsterdamumcdb: also excluding urine Incontinence (8800)
            STAY_ID NOT IN (
                SELECT
                    admissionid AS STAY_ID
                FROM
                    `original.numericitems`
                WHERE
                    ITEMID IN (19922, 19921, 8800)
                GROUP BY
                    admissionid
            )
            -- Sanity check
            AND VALUE >= 0
            AND VALUE < 5000
            AND lower(SERVICE) != "mc"          
    ),
    interval_precentiles_approx AS (
        -- Calculating 95th precentile for all and for less than 20ml urine output recoreds by source type
        SELECT
            SOURCE,
            APPROX_QUANTILES(TIME_INTERVAL, 100) [OFFSET(95)] AS percentile95_all,
            APPROX_QUANTILES(TIME_INTERVAL, 100) [OFFSET(99)] AS percentile99_all,
            APPROX_QUANTILES(
                (
                    CASE
                        WHEN (VALUE / (TIME_INTERVAL / 60)) <= 20 THEN TIME_INTERVAL
                    END
                ),
                100
            ) [OFFSET(95)] AS percentile95_20,
            APPROX_QUANTILES(
                (
                    CASE
                        WHEN (VALUE / (TIME_INTERVAL / 60)) <= 20 THEN TIME_INTERVAL
                    END
                ),
                100
            ) [OFFSET(99)] AS percentile99_20
        FROM
            (
                SELECT
                    * EXCEPT (SOURCE),
                    IF(
                        SOURCE = "R Nephrostomy"
                        OR SOURCE = "L Nephrostomy",
                        "Nephrostomy",
                        SOURCE
                    ) AS SOURCE,
                FROM
                    excluding
            )
        GROUP BY
            SOURCE
    ),
    added_validity AS (
        -- Evaluate validity by setting cut-off value for maximal interval time by output source.
        -- Cut-off value is set to the highest out of 95th precentile for all or for zero output records.
        SELECT
            a.*,
            -- Used for sensetivity analysis:
            b.percentile95_all,
            b.percentile99_all,
            b.percentile95_20,
            percentile99_20
        FROM
            excluding a
            LEFT JOIN interval_precentiles_approx b ON b.SOURCE = a.SOURCE
            OR (
                b.SOURCE = "Nephrostomy"
                AND a.SOURCE LIKE "%Nephrostomy"
            )
    )
    -- Hourly rate is finally calculated
SELECT
    a.*,
    VALUE / (TIME_INTERVAL / 60) AS HOURLY_RATE
FROM
    added_validity a