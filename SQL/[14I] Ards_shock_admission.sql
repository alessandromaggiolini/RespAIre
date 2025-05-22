DROP TABLE IF EXISTS tesi.ards_shock_admission; CREATE TABLE tesi.ards_shock_admission AS 
with adm as (
SELECT
  icu.subject_id,
  icu.hadm_id,
  icu.stay_id,
  MIN(icu.icu_intime),
  MAX(diag.icd_code),
  MAX(dd.long_title),
  MAX(CASE
  	when dd.long_title is null then null
    -- Insufficienza respiratoria acuta
    WHEN dd.long_title ILIKE '%acute respiratory failure%' 
         OR dd.long_title ILIKE '%pulmonary edema%' 
         OR dd.long_title ILIKE '%ARDS%'
      THEN 'Insufficienza respiratoria acuta'

    -- BPCO riacutizzata
    WHEN dd.long_title ILIKE '%COPD with exacerbation%' 
	     OR dd.long_title ILIKE '%chronic respiratory failure%' 
         OR dd.long_title ILIKE '%chronic obstructive pulmonary disease%'
      THEN 'Insufficienza respiratoria cronica riacutizzata (BPCO)'

    -- Insufficienza neurologica centrale
    WHEN dd.long_title ILIKE '%meningitis%' 
         OR dd.long_title ILIKE '%encephalitis%' 
         OR dd.long_title ILIKE '%overdose%' 
         OR dd.long_title ILIKE '%cerebral infarction%' 
         OR dd.long_title ILIKE '%coma%' 
         OR dd.long_title ILIKE '%hypoxic encephalopathy%' 
      THEN 'Insufficienza neurologica centrale'

    -- Insufficienza neurologica periferica
    WHEN dd.long_title ILIKE '%guillain-barre%' 
         OR dd.long_title ILIKE '%myasthenia gravis%' 
         OR dd.long_title ILIKE '%botulism%' 
         OR dd.long_title ILIKE '%tetanus%'
      THEN 'Insufficienza neurologica periferica'

    -- Scompenso metabolico
    WHEN dd.long_title ILIKE '%hyperglycemia%' 
         OR dd.long_title ILIKE '%ketoacidosis%' 
         OR dd.long_title ILIKE '%acute renal failure%' 
         OR dd.long_title ILIKE '%hepatic failure%' 
      THEN 'Scompenso metabolico'

    -- Shock cardiogeno
    WHEN dd.long_title ILIKE '%cardiogenic shock%' 
         OR dd.long_title ILIKE '%acute heart failure%'
      THEN 'Shock cardiogeno'

    -- Shock settico
    WHEN dd.long_title ILIKE '%septic shock%' 
         OR (dd.long_title ILIKE '%sepsis%' AND dd.long_title ILIKE '%shock%')
      THEN 'Shock settico'

    -- Shock emorragico / ipovolemico
    WHEN dd.long_title ILIKE '%hypovolemic shock%' 
         OR dd.long_title ILIKE '%hemorrhage%' 
         OR dd.long_title ILIKE '%bleeding%'
      THEN 'Shock emorragico/ipovolemico'

    -- Monitoraggio postoperatorio
    WHEN dd.long_title ILIKE '%postoperative%' 
         OR dd.long_title ILIKE '%following surgery%' 
         OR dd.long_title ILIKE '%post op%'
      THEN 'Monitoraggio postoperatorio'

    ELSE 'Altro'
  END) AS admission_category

FROM tesi.cohort icu
JOIN mimiciv_hosp.diagnoses_icd diag ON icu.hadm_id = diag.hadm_id and diag.seq_num=1
JOIN mimiciv_hosp.d_icd_diagnoses dd ON diag.icd_code = dd.icd_code 
group by icu.subject_id, icu.hadm_id, icu.stay_id
) --select distinct(admission_category) from adm;
,co_dx AS
(
	SELECT hadm_id
	-- septic shock codes
	, MAX(
    	CASE
    		WHEN icd_version=9 and icd_code = '78552' THEN 1
			WHEN icd_version=10 and icd_code ILIKE 'T8112%' then 1
			when icd_version=10 and icd_code ILIKE 'R6521' then 1
      ELSE 0 END)
     AS septic_shock
	,MAX(
		CASE
    		WHEN icd_version=9 and icd_code in ('51882', '51881') THEN 1
			WHEN icd_version=10 and icd_code ILIKE 'J80%' then 1
      ELSE 0 END
	) as ARDS
  FROM mimiciv_hosp.diagnoses_icd
  GROUP BY hadm_id
)
select
  c.subject_id
  ,c.hadm_id
  ,co_dx.septic_shock
  ,co_dx.ards
  ,case when septic_shock=0 and admission_category='Shock settico' then 'Altro' else adm.admission_category end as admission_category
FROM tesi.cohort c
left join co_dx on c.hadm_id = co_dx.hadm_id
left join adm on adm.stay_id=c.stay_id
order by c.subject_id, c.hadm_id;

