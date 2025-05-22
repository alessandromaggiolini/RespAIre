drop table if exists tesi.infection; create table tesi.infection as  

WITH infection_info AS (
  SELECT
    icu.subject_id,
    icu.hadm_id,
    icu.stay_id,
    icu.icu_intime,
    soi.suspected_infection_time,
    COALESCE(
      CASE 
        WHEN soi.suspected_infection_time IS NOT NULL 
             AND soi.suspected_infection_time <= icu.icu_intime + interval '6 hours' or soi.suspected_infection_time <= icu.icu_intime + INTERVAL '48 hours'
        THEN 1 ELSE 0 
      END, 0
    ) AS infection_at_icu_admission,
    -- Classificazione sede infezione (se presente)
    case WHEN LOWER(spec_type_desc) IN ('bronchial brush', 'bronchial washings', 'bronchoalveolar lavage', 'mini-bal', 'pleural fluid', 'sputum',
						'rapid respiratory viral screen & culture', 'influenza a/b by dfa') THEN 'Polmone'
        WHEN LOWER(spec_type_desc) IN ('urine') THEN 'Vie urinarie'
        WHEN LOWER(spec_type_desc) in ('peritoneal fluid') THEN 'Addome'
        WHEN LOWER(spec_type_desc) IN ('abscess', 'ear', 'foot culture', 'foreign body', 'staph aureus swab', 'swab', 'tissue')  THEN 'Tessuti molli'
        WHEN LOWER(spec_type_desc) in ('csf;spinal fluid') THEN 'Sistema nervoso centrale'
        WHEN LOWER(spec_type_desc) LIKE '%blood culture%' AND LOWER(org_name) IN (
            'staphylococcus aureus', 'enterococcus faecalis', 'streptococcus viridans',
            'staphylococcus epidermidis', 'streptococcus sanguinis'
        ) THEN 'Endocardite sospetta' 
		WHEN LOWER(spec_type_desc) is null then 'Sconosciuto'
		ELSE 'Altro' 
    END AS site_of_infection
  FROM tesi.cohort AS icu
  LEFT JOIN mimiciv_derived.suspicion_of_infection AS soi
    ON icu.subject_id = soi.subject_id
    AND icu.hadm_id = soi.hadm_id
  LEFT JOIN mimiciv_hosp.microbiologyevents me
    ON icu.hadm_id = me.hadm_id
    AND me.chartdate BETWEEN soi.suspected_infection_time - interval '1 day'
                         AND soi.suspected_infection_time + interval '1 day'
)
-- Una riga per ICU stay: scegliamo il primo evento microbiologico se ci sono più
SELECT DISTINCT ON (subject_id, hadm_id, stay_id)
  subject_id,
  hadm_id,
  stay_id,
  icu_intime,
  infection_at_icu_admission,
  case when infection_at_icu_admission=1 then site_of_infection else null end as site_of_infection
FROM infection_info
ORDER BY subject_id, hadm_id, stay_id, suspected_infection_time;

select * from tesi.infection;