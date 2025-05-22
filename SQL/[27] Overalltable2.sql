DROP TABLE IF EXISTS tesi.overalltablePROVA; CREATE TABLE tesi.overalltablePROVA AS 

with sapsii as (
	select subject_id, hadm_id, stay_id, sapsii, percent_missing_value_sapsii
	from tesi.sapsii 
), a as(
	select o.*, is_intubated, intubation_time, extubation_time, is_tracheo, tracheo_ts, end_mech_vent, time_no_mech_vent, next_intubation_time,
			round(s.sofa ) as sofa, s.percentual_missing_value as percentual_missing_value_sofa
	from tesi.overalltable1 o
	join tesi.prova_intubation g on o.subject_id =g.subject_id and o.stay_id = g.stay_id and o.icu_day_start = g.icu_day_start
	join tesi.sofadays s on s.subject_id = o.subject_id and s.hadm_id = o.hadm_id and s.stay_id = o.stay_id and o.icu_day_start::date = s.icu_day_start	
)
select  a.*, s.sapsii, s.percent_missing_value_sapsii as percentual_missing_value_sapsii
from a
left join sapsii s on s.subject_id=a.subject_id and s.hadm_id=a.hadm_id and s.stay_id=a.stay_id
order by a.subject_id, a.hadm_id, a.stay_id, a.icu_day_start;

DROP INDEX if EXISTS tesi.idx_overall2; CREATE INDEX idx_overall2 on tesi.overalltablePROVA(subject_id, hadm_id, stay_id, icu_day_start);
select * from tesi.overalltablePROVA order by subject_id, hadm_id, stay_id, icu_day_start;