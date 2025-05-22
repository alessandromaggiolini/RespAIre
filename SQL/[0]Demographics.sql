/* Crea la tabella 'tesi.demographics' aggregando dati anagrafici e clinici da patients, admissions e icustays.
   Calcola l’età al momento del ricovero, durata della degenza ospedaliera e ICU, indicatori di mortalità (ospedaliera, 28/90 giorni, in-ICU)
   e integra l’informazione DNR estratta da chartevents.
 */

DROP TABLE IF EXISTS tesi.demographics; CREATE TABLE tesi.demographics AS
With DNR as 
(
	select 
		subject_id,
		MAX(case when value like '%DNR%' then 1 else 0 end) as DNR
	from mimiciv_icu.chartevents
	group by subject_id
), demo as (
SELECT
  ie.subject_id,
  ie.hadm_id,
  ie.stay_id, /* patient level factors */
  pat.gender,
 /* calculate the age as anchor_age (60) plus difference between */ /* admit year and the anchor year. */ /* the noqa retains the extra long line so the */ /* convert to postgres bash script works */
  ROUND(pat.anchor_age + EXTRACT(EPOCH FROM adm.admittime - MAKE_TIMESTAMP(pat.anchor_year, 1, 1, 0, 0, 0)) / 31556908.8, 2 ) AS admission_age, /* noqa: L016 */
  pat.dod, /* hospital level factors */
  adm.admittime,
  case when admission_type IN 
	('EW EMER.', 'EU OBSERVATION', 'URGENT', 'AMBULATORY OBSERVATION','DIRECT OBSERVATION','OBSERVATION ADMIT',
	'DIRECT EMER.', 'EW EMER.') then 'postSurgical '
	when admission_type IN ('ELECTIVE', 'SURGICAL SAME DAY ADMISSION') then 'intensiveCare'
	end as admission_type,
  adm.dischtime,
  EXTRACT(EPOCH FROM adm.dischtime - adm.admittime) / 86400.0 AS los_hospital_day,  
  adm.hospital_expire_flag as hospMort,
  (CASE WHEN dod < admittime + interval '28' day THEN 1 ELSE 0 END)  AS HospMort28day,
  (CASE WHEN dod < admittime + interval '90' day THEN 1 ELSE 0 END)  AS HospMort90day,
  (CASE WHEN dod > ie.intime AND dod < ie.outtime THEN 1 ELSE 0 END) AS ICUMort,
  DENSE_RANK() OVER (PARTITION BY adm.subject_id ORDER BY adm.admittime NULLS FIRST) AS hospstay_seq,
 
 /* icu level factors */
  ie.intime AS icu_intime,
  ie.outtime AS icu_outtime,
  ROUND(
    CAST(CAST(EXTRACT(EPOCH FROM ie.outtime - ie.intime) / 3600.0 AS DOUBLE PRECISION) / 24.0 AS DECIMAL),
    2
  ) AS los_icu_day,
  DENSE_RANK() OVER (PARTITION BY ie.hadm_id ORDER BY ie.intime NULLS FIRST) AS icustay_seq 
FROM mimiciv_icu.icustays AS ie
INNER JOIN mimiciv_hosp.admissions AS adm
  ON ie.hadm_id = adm.hadm_id
INNER JOIN mimiciv_hosp.patients AS pat
  ON ie.subject_id = pat.subject_id
) 

select demo.subject_id, demo.hadm_id, demo.stay_id,
	gender, round(admission_age) as age, 
	dod, admittime, admission_type, dischtime, round(los_hospital_day,2) as los_hospital_day, 
	dnr, hospmort, hospmort28day, hospmort90day, 
	icumort, icu_intime, icu_outtime, los_icu_day, hospstay_seq, icustay_seq 
from demo 
left join DNR on demo.subject_id = DNR.subject_id
order by demo.subject_id,icustay_seq,stay_id;

select * from tesi.demographics