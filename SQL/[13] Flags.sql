DROP TABLE IF EXISTS tesi.flags; CREATE TABLE tesi.flags AS 
WITH icu_days AS (
  SELECT
    icu.subject_id,
    icu.hadm_id,
    icu.stay_id,
	icu.icu_intime,
	icu.icu_outtime,
    generate_series(icu.icu_intime, icu.icu_outtime, interval '4 hours') AS icu_day_start
  FROM tesi.cohort icu
), crrt as (
	select d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start, 
		max(case when p.subject_id is not null 
				and p.starttime::date >= d.icu_day_start::date - interval '24 hours' 
				and p.starttime <d.icu_day_start
				and COALESCE(p.endtime, p.starttime + interval '1 hour') >= d.icu_day_start
				and itemid in (225802, 225955, 225809, 225803) 
				then 1 else 0 end) as crrt_24h
	from  icu_days d
	left join mimiciv_icu.procedureevents p on p.subject_id=d.subject_id and p.hadm_id=d.hadm_id and p.stay_id=d.stay_id and starttime between d.icu_intime and d.icu_outtime
	group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
) 
,ino as (
	select d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start,
			max(case when p.subject_id is not null 
				and chartdate::date >= d.icu_day_start::date - interval '24 hours' 
				and chartdate <d.icu_day_start
				and icd_code in ('0012','3E0F7SD','3E0F8SD','3E0F3SD') 
				then 1 else 0 end) as ino_24h
	from icu_days d
	left join mimiciv_hosp.procedures_icd p on p.subject_id=d.subject_id and p.hadm_id=d.hadm_id and chartdate between d.icu_intime and d.icu_outtime
	group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
)
,tmp1 as (
	select subject_id, hadm_id, stay_id, charttime, itemid, value
	from mimiciv_icu.chartevents
	where itemid=224093 and value in ('Prone', 'Swimmers Position - L', 'Swimmers Position - R') 
)
,prone as (
	select d.subject_id, d.hadm_id,d.stay_id, icu_day_start, 
		max(case when ch.subject_id is not null
			and ch.charttime::date >= d.icu_day_start::date - interval '24 hours' 
			and ch.charttime <d.icu_day_start 
			and ch.subject_id is not null 
			and itemid=224093 and value in ('Prone', 'Swimmers Position - L', 'Swimmers Position - R') 
			then 1 else 0 end) as prone_24h
	from icu_days d
	/*left join mimiciv_icu.chartevents ch on ch.subject_id=d.subject_id and ch.hadm_id=d.hadm_id and ch.stay_id=d.stay_id and charttime between d.icu_intime and d.icu_outtime*/		
	left join tmp1 ch on ch.subject_id=d.subject_id and ch.hadm_id=d.hadm_id and ch.stay_id=d.stay_id and charttime between d.icu_intime and d.icu_outtime
	group by d.subject_id, d.hadm_id,d.stay_id, d.icu_day_start
) 
, tmp as (
	SELECT ie.subject_id, ie.hadm_id, ie.stay_id, ie.starttime, di.category, di.label
	FROM mimiciv_icu.inputevents ie 
	LEFT JOIN mimiciv_icu.d_items di ON ie.itemid = di.itemid
	WHERE di.category = 'Blood Products/Colloids' 
			or LOWER(di.label) ~ 'furosemide|bumetanide|ethacrynic acid|piretanide|chlorothiazide|hydrochlorothiazide|chlorthalidone|metolazone|quinethazone|acetazolamide|diclofenamide|spironolactone|triamterene|amiloride|mannitol'
)
,drug_events AS (
  SELECT
    d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start,
    MAX( case when category = 'Blood Products/Colloids'  then label end 
	) AS transfusion_type,
    MAX(CASE 
      WHEN starttime IS NOT NULL 
	  		and ie.subject_id is not null
	  		and starttime::date >= d.icu_day_start::date - interval '24 hours' 
			and starttime <d.icu_day_start
	  		and LOWER(label) ~ 'furosemide|bumetanide|ethacrynic acid|piretanide|chlorothiazide|hydrochlorothiazide|chlorthalidone|metolazone|quinethazone|acetazolamide|diclofenamide|spironolactone|triamterene|amiloride|mannitol'
			THEN 1 else 0
		end) as diuretic_24h,
	 MAX(CASE when starttime IS NOT NULL 
	 		and ie.subject_id is not null
	  		and starttime::date >= d.icu_day_start::date - interval '24 hours' 
			and starttime <d.icu_day_start
	  		and category = 'Blood Products/Colloids' 
			then 1 else 0 
    END) AS transfusion_24h
  FROM icu_days d
  LEFT JOIN tmp ie on ie.subject_id = d.subject_id and ie.hadm_id = d.hadm_id and ie.stay_id= d.stay_id and ie.starttime between icu_intime and icu_outtime
 /* mimiciv_icu.inputevents ie on 
  LEFT JOIN mimiciv_icu.d_items di ON ie.itemid = di.itemid*/
  group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
), tmp2 as (
	select p.subject_id, p.hadm_id, p.starttime, p.drug, p.stoptime
	from mimiciv_hosp.prescriptions p
	where LOWER(p.drug) ~ 'hydrocortisone|methylprednisolone|prednisolone|dexamethasone'
)
, steroid as (
	SELECT d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start, 
		max(case when p.subject_id is not null 
				and p.starttime::date >= d.icu_day_start::date - interval '24 hours' 
				and p.starttime <d.icu_day_start
				and COALESCE(p.stoptime, p.starttime + interval '1 hour') >= d.icu_day_start
				and LOWER(p.drug) ~ 'hydrocortisone|methylprednisolone|prednisolone|dexamethasone'
				then 1 else 0 end) as steroid_24h
	FROM icu_days d
	/*left join mimiciv_hosp.prescriptions p on p.subject_id = d.subject_id and p.hadm_id = d.hadm_id and p.starttime between icu_intime and icu_outtime*/
	left join tmp2 p on p.subject_id = d.subject_id and p.hadm_id = d.hadm_id and p.starttime between icu_intime and icu_outtime
	group by d.subject_id, d.hadm_id, d.stay_id, d.icu_day_start
) --select * from steroid;
SELECT
  c.subject_id, c.hadm_id, c.stay_id, c.icu_day_start,
  c.crrt_24h,
  i.ino_24h,
  de.diuretic_24h,
  p.prone_24h,
  s.steroid_24h,
  de.transfusion_24h,
  de.transfusion_type
FROM crrt c 
JOIN ino i ON c.subject_id = i.subject_id and c.hadm_id = i.hadm_id and c.stay_id = i.stay_id and c.icu_day_start = i.icu_day_start
JOIN prone p ON p.subject_id = i.subject_id and p.hadm_id = i.hadm_id and i.stay_id = p.stay_id and i.icu_day_start = p.icu_day_start
JOIN steroid s ON s.subject_id = p.subject_id and s.hadm_id = p.hadm_id and s.stay_id = p.stay_id and p.icu_day_start = s.icu_day_start
JOIN drug_events de ON s.subject_id = de.subject_id and s.hadm_id = de.hadm_id and s.stay_id = de.stay_id and s.icu_day_start = de.icu_day_start
ORDER BY c.subject_id, c.stay_id, c.icu_day_start;

CREATE INDEX idx_f on tesi.flags(subject_id, hadm_id,stay_id, icu_day_start);