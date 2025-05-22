DROP table if exists tesi.sedatives; CREATE TABLE tesi.sedatives as
WITH icu_days AS (
  SELECT
    icu.subject_id,
    icu.hadm_id,
    icu.stay_id,
    icu.icu_intime, icu.icu_outtime,
    generate_series(icu.icu_intime, icu.icu_outtime, interval '4 hours') AS icu_day_start
  FROM tesi.cohort icu
), halo as (
	SELECT icu.subject_id, icu.hadm_id, icu.stay_id, p.starttime , di.label ,di.itemid
	from tesi.cohort icu
	left join mimiciv_icu.procedureevents p on p.stay_id = icu.stay_id
	left join mimiciv_icu.d_items di on di.itemid = p.itemid
	where lower(label) ~ 'desflurane|enflurane|halothane|isoflurane|methoxyflurane|sevoflurane'
			and p.starttime between icu.icu_intime and icu.icu_outtime
), sed as (
	SELECT icu.subject_id, icu.hadm_id, icu.stay_id, i.starttime , di.label, di.itemid
	from tesi.cohort icu
	left join mimiciv_icu.inputevents i on i.stay_id = icu.stay_id
	left join mimiciv_icu.d_items di on di.itemid = i.itemid
	where lower(di.label)~ 'alprazolam|bromazepam|brotizolam|chlordiazepoxide|cinolazepam|clobazam|clonazepam|clotiazepam|diazepam|estazolam|flurazepam|halazepam|lorazepam|lormetazepam|medazepam|midazolam|nitrazepam|nordazepam|oxazepam|prazepam|quazepam|temazepam|triazolam'
		  or lower(di.label)~'chlorpromazine|levomepromazine|perphenazine|prochlorperazine|thioridazine|trifluoperazine|droperidol|pimozide|zuclopenthixol|flupentixol|clotiapine|loxapine|amisulpride|aripiprazole|asenapine|brexpiprazole|cariprazine|clozapine|iloperidone|lurasidone|olanzapine|paliperidone|quetiapine|risperidone|sertindole|ziprasidone'
		  or lower(di.label)~ 'propofol'
		  or lower(di.label)~'dexmedetomidine'
		  or lower(di.label)~'haloperidol'
		  or lower(di.label)~'ketamine'
		  and category<>'Ingredients' and linksto='inputevents'
			and i.starttime between icu.icu_intime and icu.icu_outtime

) 
select d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start, --i.starttime,
		max(case when i.starttime between icu_day_start and icu_day_start + interval '4 hours' --and
						--lower(di.label)~ 'alprazolam|bromazepam|brotizolam|chlordiazepoxide|cinolazepam|clobazam|clonazepam|clotiazepam|diazepam|estazolam|flurazepam|halazepam|lorazepam|lormetazepam|medazepam|midazolam|nitrazepam|nordazepam|oxazepam|prazepam|quazepam|temazepam|triazolam|chlorpromazine|levomepromazine|perphenazine|prochlorperazine|thioridazine|trifluoperazine|droperidol|pimozide|zuclopenthixol|flupentixol|clotiapine|loxapine|amisulpride|aripiprazole|asenapine|brexpiprazole|cariprazine|clozapine|iloperidone|lurasidone|olanzapine|paliperidone|quetiapine|risperidone|sertindole|ziprasidone|'	
						--and category<>'Ingredients' and linksto='inputevents'
						then 1
				when h.starttime between icu_day_start and icu_day_start + interval '4 hours' --and 
						--lower(h.label) ~ 'desflurane|enflurane|halothane|isoflurane|methoxyflurane|sevoflurane'
						--and category<>'Ingredients' and linksto='inputevents'
						then 1 else 0  end) as is_sedated,
		
		STRING_AGG(distinct 
				case when i.starttime between icu_day_start and icu_day_start + interval '4 hours' and 
									lower(i.label) ~ 'alprazolam|bromazepam|brotizolam|chlordiazepoxide|cinolazepam|clobazam|clonazepam|clotiazepam|diazepam|estazolam|flurazepam|halazepam|lorazepam|lormetazepam|medazepam|midazolam|nitrazepam|nordazepam|oxazepam|prazepam|quazepam|temazepam|triazolam'
									 then 'benzodiazepines'
				 when i.starttime between icu_day_start and icu_day_start + interval '4 hours' and 
									lower(i.label) ~ 'chlorpromazine|levomepromazine|perphenazine|prochlorperazine|thioridazine|trifluoperazine|droperidol|pimozide|zuclopenthixol|flupentixol|clotiapine|loxapine|amisulpride|aripiprazole|asenapine|brexpiprazole|cariprazine|clozapine|iloperidone|lurasidone|olanzapine|paliperidone|quetiapine|risperidone|sertindole|ziprasidone'
									then 'neuroleptics'
				 when h.starttime between icu_day_start and icu_day_start + interval '4 hours' and lower(h.label) ~ 'desflurane|enflurane|halothane|isoflurane|methoxyflurane|sevoflurane' then 'inhaledHalogenated'					
				 when i.starttime between icu_day_start and icu_day_start + interval '4 hours' and lower(i.label) ILIKE 'propofol' then 'propofol'
				 when i.starttime between icu_day_start and icu_day_start + interval '4 hours' and lower(i.label) ILIKE 'midazolam' then 'midazolam'
				 when i.starttime between icu_day_start and icu_day_start + interval '4 hours' and lower(i.label) ILIKE 'dexmedetomidine' then 'dexmedetomidine'
				 when i.starttime between icu_day_start and icu_day_start + interval '4 hours' and lower(i.label) ILIKE 'haloperidol' then 'haloperidol'
				 when i.starttime between icu_day_start and icu_day_start + interval '4 hours' and lower(i.label)~ 'ketamine' then 'ketamine'
				 end, ', ') as sedation_type
from icu_days d 
left join sed i on i.stay_id = d.stay_id and i.starttime between d.icu_intime and d.icu_outtime
--left join mimiciv_icu.inputevents i on i.stay_id = d.stay_id and i.starttime between d.icu_intime and d.icu_outtime
--left join mimiciv_icu.d_items di on di.itemid = i.itemid 
left join halo h on h.stay_id = d.stay_id
/*where lower(di.label) LIKE ANY(ARRAY[
	  'alprazolam%', 'bromazepam%', 'brotizolam%', 'chlordiazepoxide%', 
	  'cinolazepam%', 'clobazam%', 'clonazepam%', 'clotiazepam%',
	  'diazepam%', 'estazolam%', 'flurazepam%', 'halazepam%', 'lorazepam%', 
	  'lormetazepam%', 'medazepam%', 'midazolam%', 'nitrazepam%', 'nordazepam%',
	  'oxazepam%', 'prazepam%', 'quazepam%', 'temazepam%', 'triazolam%', 'chlorpromazine%', 'levomepromazine%', 'perphenazine%', 'prochlorperazine%', 'thioridazine%', 
	  'trifluoperazine%',  'droperidol%', 'pimozide%', 'zuclopenthixol%', 'flupentixol%', 'clotiapine%', 'loxapine%', 'amisulpride%', 'aripiprazole%'
	  'asenapine%', 'brexpiprazole%', 'cariprazine%', 'clozapine%', 'iloperidone%', 'lurasidone%', 'olanzapine%', 'paliperidone%'
	  'quetiapine%', 'risperidone%', 'sertindole%', 'ziprasidone%', 'desflurane%', 'enflurane%', 'halothane%', 'isoflurane%', 
	  'methoxyflurane%', 'sevoflurane%','propofol%', 'midazolam%', '%dexmedetomidina%', 'haloperidol%'])
and category<>'Ingredients' and linksto='inputevents' */
group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
order by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start