DROP table if exists tesi.neuroblock; CREATE TABLE tesi.neuroblock as
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
select d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start, --i.starttime,
		max(case when i.starttime between icu_day_start and icu_day_start + interval '4 hours' and 
			lower(di.label) ~'rocuronium|vecuronium|cisatracurium|pancuronium|atracurium|succinylcholine'
		then 1 else 0 end) as neuroblock		
from icu_days d 
left join mimiciv_icu.inputevents i on i.stay_id = d.stay_id and i.starttime between d.icu_intime and d.icu_outtime
left join mimiciv_icu.d_items di on di.itemid = i.itemid 
		
group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
order by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start;