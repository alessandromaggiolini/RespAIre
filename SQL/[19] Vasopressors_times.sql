DROP TABLE IF EXISTS tesi.getvasopressor_time; CREATE TABLE tesi.getvasopressor_time AS
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
		avg(case when starttime between icu_day_start and icu_day_start+interval '4 hours' then v.rate_norepinephrine end) as rate_norepinephrine,
		avg(case when starttime between icu_day_start and icu_day_start+interval '4 hours' then v.rate_dopamine end) as rate_dopamine,
		avg(case when starttime between icu_day_start and icu_day_start+interval '4 hours' then v.rate_vasopressin end) as rate_vasopressin,
		avg(case when starttime between icu_day_start and icu_day_start+interval '4 hours' then v.rate_dobutamine end) as rate_dobutamine,
		avg(case when starttime between icu_day_start and icu_day_start+interval '4 hours' then v.rate_epinephrine end) as rate_epinephrine
from icu_days d
left join tesi.vasopressors v  on d.stay_id=v.stay_id and starttime between d.icu_intime and d.icu_outtime
Group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
order by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start;

create index idx_vaso_all on  tesi.getvasopressor_time(subject_id, hadm_id, stay_id, icu_day_start );