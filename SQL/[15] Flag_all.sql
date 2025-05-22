create index idx_neuro ON tesi.neuroblock( subject_id, hadm_id, stay_id, icu_day_start);
create index idx_opio ON tesi.opioids( subject_id, hadm_id, stay_id, icu_day_start);
create index idx_sed ON tesi.sedatives( subject_id, hadm_id, stay_id, icu_day_start);
create index idx_inf ON tesi.infection( subject_id, hadm_id, stay_id);
create index idx_flag ON tesi.flags( subject_id, hadm_id, stay_id, icu_day_start);
create index idx_ards on tesi.ards_shock_admission(subject_id, hadm_id);

DROP TABLE IF EXISTS tesi.allFlags; CREATE TABLE tesi.allFlags AS
WITH p1 as (
	SELECT f.*, n.neuroblock, o.opioids, s.is_sedated, s.sedation_type 
			--,i.infection_at_icu_admission, i.site_of_infection, a.admission_category, a.ards, a.septic_shock
	from tesi.neuroblock n
	join tesi.opioids o on o.subject_id = n.subject_id and o.hadm_id = n.hadm_id and o.stay_id = n.stay_id and o.icu_day_start = n.icu_day_start
	join tesi.sedatives s on s.subject_id = n.subject_id and s.hadm_id = n.hadm_id and s.stay_id = n.stay_id and s.icu_day_start = n.icu_day_start
	join tesi.flags f on f.subject_id = n.subject_id and f.hadm_id = n.hadm_id and f.stay_id = n.stay_id and f.icu_day_start = n.icu_day_start
)
select p1.*,i.infection_at_icu_admission, i.site_of_infection, a.admission_category, a.ards, a.septic_shock
from p1
join tesi.infection i on p1.subject_id = i.subject_id and p1.hadm_id = i.hadm_id and p1.stay_id = i.stay_id
join tesi.ards_shock_admission a on p1.subject_id = a.subject_id and a.hadm_id = p1.hadm_id
