CREATE OR REPLACE TABLE `aumc_uo_and_aki.a_urine_output_raw` AS

WITH
    admit AS (
        SELECT
            *,
            CASE
                WHEN admissionyeargroup LIKE "2003%" THEN DATETIME_ADD(
                    "2003-01-01 00:00:00",
                    INTERVAL CAST((admittedat / 1000) AS INT64) SECOND
                )
                ELSE DATETIME_ADD(
                    "2009-01-01 00:00:00",
                    INTERVAL CAST((admittedat / 1000) AS INT64) SECOND
                )
            END AS admit_time
        FROM
            `original.admissions`
    )
SELECT
    -- Original query from official A-UMC's repository in permalink: 
    -- https://github.com/AmsterdamUMC/AmsterdamUMCdb/blob/b88795565dae865869e6678c1d836e1e8200f41b/amsterdamumcdb/sql/common/urine_output.sql
    a.patientid AS SUBJECT_ID,
    n.admissionid AS STAY_ID,
    CASE
        WHEN a.admissionyeargroup LIKE "2003%" THEN DATETIME_ADD(
            a.admit_time,
            INTERVAL CAST((n.measuredat / 1000) AS INT64) SECOND
        )
        ELSE DATETIME_ADD(
            a.admit_time,
            INTERVAL CAST((n.measuredat / 1000) AS INT64) SECOND
        )
    END AS CHARTTIME,
    n.VALUE,
    n.ITEMID,
    CASE
        WHEN n.ITEMID = 8794 THEN "Foley"
        WHEN n.ITEMID = 8796 THEN "Suprapubic"
        WHEN n.ITEMID = 8798 THEN "Void"
        WHEN n.ITEMID = 8800 THEN "Straight Cath"
        WHEN n.ITEMID = 8803 THEN "Ileoconduit"
        WHEN n.ITEMID = 10743 THEN "L Nephrostomy"
        WHEN n.ITEMID = 10745 THEN "R Nephrostomy"
        WHEN n.ITEMID = 19921 THEN "L Ureteral Stent"
        WHEN n.ITEMID = 19922 THEN "R Ureteral Stent"
    END AS LABEL,
    a.location AS SERVICE
FROM
    `original.numericitems` n
    LEFT JOIN admit a ON n.admissionid = a.admissionid
WHERE
    n.itemid IN (
        8794, --UrineCAD ("Foley")
        8796, --UrineSupraPubis ("Suprapubic")
        8798, --UrineSpontaan ("Void")
        8800, --UrineIncontinentie ("?")
        8803, --UrineUP ("Ileoconduit")
        10743, --Nefrodrain li Uit ("L Nephrostomy")
        10745, --Nefrodrain re Uit ("R Nephrostomy")
        19921, --UrineSplint Li ("L Ureteral Stent")
        19922 --UrineSplint Re ("R Ureteral Stent")
    )
    AND n.value IS NOT NULL
    AND (n.measuredat - a.admittedat) >= 0