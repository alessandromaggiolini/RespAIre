create index idx_allflag ON tesi.allflags(subject_id, hadm_id, stay_id, icu_day_start);
--create index idx_all_lab on tesi.getalllabvalues(subject_id, hadm_id, stay_id);

DROP TABLE IF EXISTS tesi.getalllabvalues_time; CREATE TABLE tesi.getalllabvalues_time AS
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
select 
		d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then ph end) as ph,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then paco2 end) as paco2,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then pao2 end) as pao2,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then lactate end) as lactate,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then hemoglobin end) as hemoglobin,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then albumin end) as albumin,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then platelet end) as platelet,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then wbc end) as wbc,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then bilirubin end) as bilirubin,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then creatinine end) as creatinine,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then bun end) as bun,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then sodium end) as sodium,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then potassium end) as potassium,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then bicarbonate end) as bicarbonate		
from icu_days d
left join tesi.getalllabvalues g on d.subject_id=g.subject_id and charttime between d.icu_intime and d.icu_outtime
Group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
order by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start