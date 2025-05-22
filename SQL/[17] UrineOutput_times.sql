create index idx_uo on tesi.geturineoutput(subject_id, hadm_id, stay_id);

DROP TABLE IF EXISTS tesi.geturineoutput_time; CREATE TABLE tesi.geturineoutput_time AS
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
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then urineoutput end) as uo
from icu_days d
left join tesi.geturineoutput g on d.subject_id=g.subject_id and d.hadm_id=g.hadm_id and d.stay_id=g.stay_id and charttime between d.icu_intime and d.icu_outtime
Group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
order by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start;

create index idx_uo_times on tesi.geturineoutput_time(subject_id, hadm_id, stay_id, icu_day_start );