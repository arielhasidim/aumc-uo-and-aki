CREATE OR REPLACE TABLE `aumc_uo_and_aki.a_urine_output_raw` AS

WITH
    uo AS (
        -- Original query from official A-UMC's repository in permalink: 
        -- https://github.com/AmsterdamUMC/AmsterdamUMCdb/blob/b88795565dae865869e6678c1d836e1e8200f41b/amsterdamumcdb/sql/common/urine_output.sql
        SELECT
            n.admissionid,
            (n.measuredat - a.admittedat) / (1000 * 60) AS time
            n.value,
            n.itemid,
            n.item,
        FROM
            `amsterdamumcdb102.original.numericitems` n
            LEFT JOIN `amsterdamumcdb102.original.admissions` a ON n.admissionid = a.admissionid
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
            -- measurements within 24 hours of ICU stay (use 30 minutes before admission to allow for time differences):
            AND (n.measuredat - a.admittedat) <= 1000 * 60 * 60 * 24
            AND (n.measuredat - a.admittedat) >= 0
    )

SELECT
    a.patientid,
    uo.*,
    a.location
FROM
    uo
    LEFT JOIN `amsterdamumcdb102.original.admissions` a ON a.admissionid = uo.admissionid
