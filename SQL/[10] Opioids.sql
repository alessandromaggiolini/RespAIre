DROP table if exists tesi.opioids; CREATE TABLE tesi.opioids as
WITH icu_days AS (
  SELECT
    icu.subject_id,
    icu.hadm_id,
    icu.stay_id,
    icu.icu_intime, 
    icu.icu_outtime,
    generate_series(icu.icu_intime, icu.icu_outtime, interval '4 hours') AS icu_day_start
  FROM tesi.cohort icu
)
SELECT 
  d.subject_id, 
  d.hadm_id, 
  d.stay_id, 
  d.icu_day_start,
  MAX(
    CASE 
      WHEN p.starttime <= d.icu_day_start + interval '4 hours'
           AND p.stoptime >= d.icu_day_start
           AND LOWER(p.drug) ~ 'fentanyl|morphine|hydromorphone|oxycodone|pethidine|meperidine|codeine|buprenorphine|tramadol'
      THEN 1 
      ELSE 0 
    END
  ) AS opioids
FROM icu_days d 
LEFT JOIN mimiciv_hosp.prescriptions p 
  ON p.subject_id = d.subject_id 
 AND p.hadm_id = d.hadm_id 
 AND p.starttime <= d.icu_day_start + interval '4 hours'
 AND p.stoptime >= d.icu_day_start
GROUP BY d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
ORDER BY d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start;