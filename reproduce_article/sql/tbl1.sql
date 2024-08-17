WITH
    baseline_scr AS (
        SELECT
            n.admissionid,
            MIN(n.value) * 0.0113 AS baseline_creatinine -- convertion from μmol/L to mg/dL: https://academic.oup.com/ndt/article-pdf/19/suppl_2/ii42/5215827/gfh1030.pdf
        FROM
            `original.numericitems` n
            LEFT JOIN `original.admissions` a ON n.admissionid = a.admissionid
        WHERE
            itemid IN (
                6836, --Kreatinine µmol/l (erroneously documented as µmol)
                9941, --Kreatinine (bloed) µmol/l
                14216 --KREAT enzym. (bloed) µmol/l
            )
            AND
            --search upto 1 year before admission
            (n.measuredat - a.admittedat) / (60 * 60 * 1000) > - (365 * 24)
            AND (n.measuredat - a.admittedat) < (24 * 60 * 60 * 1000)
        GROUP BY
            n.admissionid
    ),
    first_last_creat AS (
        SELECT
            n.admissionid,
            ARRAY_AGG(
                n.value
                ORDER BY
                    n.measuredat ASC
                LIMIT
                    1
            ) [OFFSET(0)] * 0.0113 AS creat_first, -- convertion from μmol/L to mg/dL: https://academic.oup.com/ndt/article-pdf/19/suppl_2/ii42/5215827/gfh1030.pdf
            ARRAY_AGG(
                n.value
                ORDER BY
                    n.measuredat DESC
                LIMIT
                    1
            ) [OFFSET(0)] * 0.0113 AS creat_last,
            MAX(IF(n.measuredat <  b.measuredat + ( 72 * 60 * 60 * 1000)   AND n.measuredat >= b.measuredat, n.value, NULL)) * 0.0113 AS creat_peak_72
        FROM
            `original.numericitems` n
            LEFT JOIN  (SELECT STAY_ID, MIN(measuredat) measuredat FROM `aumc_uo_and_aki.a_urine_output_raw` GROUP BY STAY_ID) 
                AS b ON b.STAY_ID = n.admissionid
        WHERE
            itemid IN (
                6836, --Kreatinine µmol/l (erroneously documented as µmol)
                9941, --Kreatinine (bloed) µmol/l
                14216 --KREAT enzym. (bloed) µmol/l
            )
        GROUP BY
            n.admissionid
    ),
    rrt AS (
        SELECT
            a.admissionid,
            IF(COUNT(b.itemid) > 0, 1, 0) rrt_binary
        FROM
            `original.admissions` a
            LEFT JOIN `original.numericitems` b ON b.admissionid = a.admissionid
            AND b.itemid IN (
                10736, --Bloed-flow
                12460, --Bloedflow
                14850 --MFT_Bloedflow (ingesteld): Fresenius multiFiltrate blood flow
            )
            AND b.value > 0
        GROUP BY
            a.admissionid
    )
SELECT
    a.admissionid STAY_ID,
    CASE
        WHEN a.specialty = "Cardiochirurgie" THEN "CSURG"
        WHEN a.specialty = "Cardiologie" THEN "CMED"
        WHEN a.specialty = "Keel, Neus & Oorarts" THEN "ENT"
        WHEN a.specialty = "Urologie" THEN "GU"
        WHEN a.specialty = "Inwendig" THEN "MED"
        WHEN a.specialty = "Neurologie" THEN "NMED"
        WHEN a.specialty = "Neurochirurgie" THEN "NSURG"
        WHEN a.specialty = "Orthopedie" THEN "ORTHO"
        WHEN a.specialty = "Plastische chirurgie" THEN "PSURG"
        WHEN a.specialty = "Heelkunde Gastro-enterologie" THEN "SURG"
        WHEN a.specialty = "Traumatologie" THEN "TRAUM"
        WHEN a.specialty = "Vaatchirurgie" THEN "VSURG"
        WHEN a.specialty = "Gynaecologie" THEN "GYN"
        WHEN a.specialty = "Mondheelkunde" THEN "DENT"
        WHEN a.specialty IN ("Verloskunde", "Obstetrie") THEN "OBS"
        ELSE a.specialty
        -- "Intensive Care Volwassenen" - ICU
        -- "Heelkunde Oncologie" - Oncologic surgery
        -- "Longziekte" - Lung disease
        -- "Heelkunde Longen/Oncologie" - Lung surgery/oncology
        -- "Nefrologie" - Nephrology
        -- "Hematologie" - Hematology
        -- "Maag-,Darm-,Leverziekten" - Gastrointestinal, liver diseases
        -- "Oncologie Inwendig" - Oncology Internal
        -- "ders"?? (64)
        -- "Oogheelkunde" - Ophthalmology
        -- "Reumatologie" - Rheumatology
        -- Missing: TSURG, OMED
    END AS SERVICE,
    CASE
        WHEN a.gender = "Man" THEN "M"
        WHEN a.gender = "Vrouw" THEN "F"
        ELSE NULL
    END AS gender,
    IF(a.destination = 'Overleden', 1, 0) AS hospital_expire_flag,
    CASE
        WHEN a.agegroup LIKE "%18%" THEN 29
        WHEN a.agegroup LIKE "%40%" THEN 45
        WHEN a.agegroup LIKE "%50%" THEN 55
        WHEN a.agegroup LIKE "%60%" THEN 65
        WHEN a.agegroup LIKE "%70%" THEN 75
        WHEN a.agegroup LIKE "%80%" THEN 85
        ELSE NULL
    END admission_age,
    a.lengthofstay / 24 AS icu_days,
    CASE
        WHEN a.weightgroup LIKE "%59%" THEN 55
        WHEN a.weightgroup LIKE "%60%" THEN 65
        WHEN a.weightgroup LIKE "%70%" THEN 75
        WHEN a.weightgroup LIKE "%80%" THEN 85
        WHEN a.weightgroup LIKE "%90%" THEN 95
        WHEN a.weightgroup LIKE "%100%" THEN 105
        WHEN a.weightgroup LIKE "%110%" THEN 115
        ELSE NULL
    END AS weight_admit,
    CASE
        WHEN a.heightgroup LIKE "%159%" THEN 155
        WHEN a.heightgroup LIKE "%160%" THEN 165
        WHEN a.heightgroup LIKE "%170%" THEN 175
        WHEN a.heightgroup LIKE "%180%" THEN 185
        WHEN a.heightgroup LIKE "%190%" THEN 195
        ELSE NULL
    END AS height_first,
    b.baseline_creatinine scr_baseline,
    c.creat_first,
    c.creat_peak_72,
    c.creat_last,
    d.rrt_binary
FROM
    `original.admissions` a
    LEFT JOIN baseline_scr b ON b.admissionid = a.admissionid
    LEFT JOIN first_last_creat c ON c.admissionid = a.admissionid
    LEFT JOIN rrt d ON d.admissionid = a.admissionid
WHERE
    lower(a.location) != "mc"
    AND a.admissionid NOT IN (
        SELECT
            admissionid
        FROM
            `original.numericitems`
        WHERE
            ITEMID IN (19922, 19921, 8800) -- Urethral stent, Urine Incontinence
    )
    AND a.admissionid IN (
        SELECT
            STAY_ID
        FROM
            `aumc_uo_and_aki.b_uo_rate`
        WHERE
            TIME_INTERVAL IS NOT NULL
    )
