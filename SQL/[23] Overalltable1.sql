DROP TABLE IF EXISTS tesi.overalltable1; CREATE TABLE tesi.overalltable1 AS
WITH a as (
select 
	-- lab values
	l.*, 
	-- urine output
	u.uo, 
	-- vaspressors
	v.rate_dobutamine, v.rate_dopamine, v.rate_epinephrine, v.rate_norepinephrine, v.rate_vasopressin,
	-- flags
	f.prone_24h, f.crrt_24h, f.ino_24h, f.diuretic_24h, f.steroid_24h, f.transfusion_24h, f.transfusion_type, f.neuroblock, f.opioids, f.is_sedated, f.sedation_type,
	f.infection_at_icu_admission, f.site_of_infection, f.admission_category, f.ards, f.septic_shock,
	--vital sign
	vs.gcs, vs.heartrate, vs.sysbp, vs.diasbp, vs.meanbp, vs.resprate, vs.tempc, vs.spo2,
	round((vs.heartrate/vs.sysbp)::NUMERIC,2) as shock_index,
	--ventilator
	vp.tidal_volume, vp.peep, vp.fio2, vp.vent_mode, vp.vent_type,
	(l.paco2/vp.fio2)*100 as pao2fio2ratio
	
from tesi.getalllabvalues_time l 
join tesi.geturineoutput_time u on u.subject_id = l.subject_id and u.hadm_id = l.hadm_id and u.stay_id = l.stay_id and u.icu_day_start = l.icu_day_start
join tesi.getvasopressor_time v on v.subject_id = l.subject_id and v.hadm_id = l.hadm_id and v.stay_id = l.stay_id and v.icu_day_start = l.icu_day_start
join tesi.allflags f on f.subject_id = l.subject_id and f.hadm_id = l.hadm_id and f.stay_id = l.stay_id and f.icu_day_start = l.icu_day_start
join tesi.getallvitalsigns_time vs on vs.subject_id = l.subject_id and vs.hadm_id = l.hadm_id and vs.stay_id = l.stay_id and vs.icu_day_start = l.icu_day_start
join tesi.vent_param vp on vp.subject_id = f.subject_id and vp.stay_id = f.stay_id and vp.icu_day_start = f.icu_day_start
order by l.subject_id, l.hadm_id, l.stay_id, l.icu_day_start
)
select d.*, a.icu_day_start,
	-- lab values
	ph,paco2, pao2,lactate,hemoglobin,albumin,platelet,wbc,bilirubin, creatinine, bun,sodium,potassium, bicarbonate, 
	-- urine output
	uo, 
	-- vaspressors
	rate_dobutamine, rate_dopamine, rate_epinephrine, rate_norepinephrine, rate_vasopressin,
	-- flags
	prone_24h, crrt_24h, ino_24h, diuretic_24h, steroid_24h, transfusion_24h, transfusion_type, neuroblock, opioids, is_sedated, sedation_type,
	infection_at_icu_admission, site_of_infection, admission_category, ards, septic_shock,
	--vital sign
	gcs, heartrate, sysbp, diasbp, meanbp, resprate, tempc, spo2,
	shock_index,
	--ventilator
	tidal_volume, peep, fio2, vent_mode, vent_type,
	 pao2fio2ratio
from tesi.alldemocohort d 
right join a on d.subject_id=a.subject_id and d.hadm_id=a.hadm_id and d.stay_id=a.stay_id 
order by d.subject_id, d.hadm_id, d.stay_id, a.icu_day_start;

CREATE INDEX idx_over_1 on tesi.overalltable1(subject_id, hadm_id, stay_id, icu_day_start);