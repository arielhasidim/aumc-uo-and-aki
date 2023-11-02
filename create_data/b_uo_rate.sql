CREATE OR REPLACE TABLE `aumc_uo_and_aki.b_uo_rate` AS

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
            a.LABEL,
            MAX(b.CHARTTIME) AS LAST_CHARTTIME,
            (
                DATETIME_DIFF(a.CHARTTIME, MAX(b.CHARTTIME), SECOND) / 60
            ) AS TIME_INTERVAL,
            CASE
                WHEN weightgroup LIKE '59' THEN 55
                WHEN weightgroup LIKE '60' THEN 65
                WHEN weightgroup LIKE '70' THEN 75
                WHEN weightgroup LIKE '80' THEN 85
                WHEN weightgroup LIKE '90' THEN 95
                WHEN weightgroup LIKE '100' THEN 105
                WHEN weightgroup LIKE '110' THEN 115
                ELSE 80 --mean weight for all years
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
            w.weightgroup
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
            WEIGHT_ADMIT
        FROM
            uo_with_intervals_sources_and_weight
        WHERE
            -- Exclude all stays with ureteral stent or GU irrigation 
            -- (See https://github.com/MIT-LCP/mimic-code/issues/745 for GU irrig.)
            STAY_ID NOT IN (
                SELECT
                    STAY_ID
                FROM
                    `physionet-data.mimiciv_icu.outputevents`
                WHERE
                    ITEMID IN (19922, 19921)
                GROUP BY
                    STAY_ID
            )
            -- Sanity check
            AND VALUE >= 0
            AND VALUE < 5000
    ),
    interval_precentiles_approx AS (
        -- Calculating 95th precentile for all and for less than 20ml urine output recoreds by source type
        SELECT
            SOURCE,
            APPROX_QUANTILES(TIME_INTERVAL, 100) [OFFSET(95)] AS percentile95_all,
            APPROX_QUANTILES(
                (
                    CASE
                        WHEN (VALUE / (TIME_INTERVAL / 60)) <= 20 THEN TIME_INTERVAL
                    END
                ),
                100
            ) [OFFSET(95)] AS percentile95_20
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
            CASE
                WHEN a.SOURCE = 'Suprapubic'
                AND TIME_INTERVAL <= GREATEST(percentile95_20, percentile95_all) THEN TRUE
                WHEN a.SOURCE = 'Ileoconduit'
                AND TIME_INTERVAL <= GREATEST(percentile95_20, percentile95_all) THEN TRUE
                WHEN a.SOURCE LIKE '%Nephrostomy'
                AND TIME_INTERVAL <= GREATEST(percentile95_20, percentile95_all) THEN TRUE
                WHEN a.SOURCE = 'Foley'
                AND TIME_INTERVAL <= GREATEST(percentile95_20, percentile95_all) THEN TRUE
                WHEN a.SOURCE = 'Condom Cath'
                AND TIME_INTERVAL <= GREATEST(percentile95_20, percentile95_all) THEN TRUE
                WHEN a.SOURCE = 'Straight Cath'
                AND TIME_INTERVAL <= GREATEST(percentile95_20, percentile95_all) THEN TRUE
                WHEN a.SOURCE = 'Void'
                AND TIME_INTERVAL <= GREATEST(percentile95_20, percentile95_all) THEN TRUE
                ELSE FALSE
            END AS VALIDITY
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
    VALUE / (TIME_INTERVAL / 60) AS HOURLY_RATE,
    s.location SERVICE
FROM
    added_validity a
    LEFT JOIN `original.admissions` s ON s.admissionid = a.STAY_ID