create index idx_cohort on tesi.cohort(subject_id, hadm_id, stay_id);
create index idx_bmi on tesi.bmi(subject_id,stay_id);
create index idx_cci on tesi.charlson(subject_id,hadm_id);

DROP TABLE IF EXISTS tesi.alldemocohort; CREATE TABLE tesi.alldemocohort AS
select c.*, b.weight, b.height, b.bmi, ch.charlson_comorbidity_index as comorb_score 
from tesi.cohort c
left join tesi.bmi b on c.subject_id = b.subject_id and c.stay_id=b.stay_id
left join tesi.charlson ch on ch.subject_id = c.subject_id and ch.hadm_id = c.hadm_id;

create index idx_all_cohort on tesi.alldemocohort(subject_id, hadm_id, stay_id);