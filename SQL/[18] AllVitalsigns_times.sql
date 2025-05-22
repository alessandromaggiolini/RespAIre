create index idx_lab_times on tesi.getalllabvalues_time(subject_id, hadm_id, stay_id, icu_day_start );
create index idx_vitalsign on tesi.getallvitalsigns(subject_id, hadm_id, stay_id);

DROP TABLE IF EXISTS tesi.getallvitalsigns_time; CREATE TABLE tesi.getallvitalsigns_time AS
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
		round(avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then gcs end)) as gcs,
		round(avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then heartrate end)) as heartrate,
		round(avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then sysbp end)) as sysbp,
		round(avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then diasbp end)) as diasbp,
		round(avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then meanbp end)) as meanbp,
		round(avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then resprate end)) as resprate,
		round(max(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then tempc end),2) as tempc,
		avg(case when charttime between icu_day_start and icu_day_start+interval '4 hours' then spo2 end) as spo2		
from icu_days d
left join tesi.getallvitalsigns g on d.subject_id=g.subject_id and d.hadm_id=g.hadm_id and d.stay_id=g.stay_id and charttime between d.icu_intime and d.icu_outtime
Group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
order by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start;

create index idx_vitalsign_times on tesi.getallvitalsigns_time(subject_id, hadm_id, stay_id, icu_day_start );