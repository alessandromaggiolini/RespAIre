/* Crea la tabella 'tesi.cohort' selezionando il primo ricovero ospedaliero e ICU per pazienti adulti (≥18 anni),
   con dati completi su mortalità e senza ordine DNR. La coorte rappresenta un sottogruppo clinicamente rilevante 
   per analisi di outcome standardizzati. */

drop table if exists tesi.cohort; create table tesi.cohort as 

select subject_id, hadm_id, stay_id,
	gender, age, 
	dod, admittime, admission_type, dischtime, los_hospital_day, 
	hospmort, hospmort28day, hospmort90day, 
	icumort, icu_intime, icu_outtime, los_icu_day
from tesi.demographics
where age >= 18 and hospstay_seq=1 and icustay_seq=1 
		and hospmort is not null and icumort is not null 
		and dnr=0; 

select * from tesi.cohort; 