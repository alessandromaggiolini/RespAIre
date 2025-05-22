DROP TABLE IF EXISTS tesi.sofaDays; CREATE TABLE tesi.sofaDays AS
WITH daily_data AS (
    SELECT
        subject_id, hadm_id, stay_id, 
        -- Rimuovo i timestamp per ottenere solo la data del giorno
        DATE(icu_day_start) AS icu_day_start,
        
        -- Respiratory: PaO2/FiO2 (se il tuo parametro è per esempio pao2_fio2_ratio)
        MAX(pao2fio2ratio) AS pao2fio2ratio,
        
        -- Coagulation: Platelets
        MIN(platelet) AS platelet,

        -- Liver: Bilirubin
        MAX(bilirubin) AS bilirubin,

        -- Cardiovascular: MAP + vasopressors (assumiamo che sia una variabile booleana per l'uso di vasopressori)
        MIN(meanbp) AS meanbp,
        --MAX(using_vasopressors) AS vasopressors_used, -- 0 o 1
          max(rate_dopamine) as rate_dopamine, 
		  max(rate_norepinephrine) as rate_norepinephrine,
		  max(rate_epinephrine) as rate_epinephrine, 
		  max(rate_dobutamine) as rate_dobutamine,
        -- CNS: GCS
        MIN(gcs) AS gcs,

        -- Renal: Creatinine or Urine Output (se usi creatinine, altrimenti urine output)
        MAX(creatinine) AS creatinine, SUM(uo) as uo
    FROM tesi.overalltable1
    GROUP BY subject_id, hadm_id,stay_id, DATE(icu_day_start)
), scorecalc as
(
SELECT stay_id, subject_id, hadm_id, icu_day_start , PaO2FiO2ratio ,
		gcs, meanbp , rate_dopamine , rate_norepinephrine, rate_epinephrine
       , bilirubin , platelet , creatinine, uo 
	   , case
	  when PaO2FiO2ratio < 100  then 4
      when PaO2FiO2ratio < 200  then 3
      when PaO2FiO2ratio < 300  then 2
      when PaO2FiO2ratio < 400  then 1
      when PaO2FiO2ratio is null then null
      else 0
    end as respiration	
	  -- Neurological failure (GCS)
  , case
      when (gcs >= 13 and gcs <= 14) then 1
      when (gcs >= 10 and gcs <= 12) then 2
      when (gcs >=  6 and gcs <=  9) then 3
      when  gcs <   6 then 4
      when  gcs is null then null
  else 0 end
    as cns	
  -- Cardiovascular
  , case
      when rate_dopamine > 15 or rate_epinephrine >  0.1 or rate_norepinephrine >  0.1 then 4
      when rate_dopamine >  5 or rate_epinephrine <= 0.1 or rate_norepinephrine <= 0.1 then 3
      when rate_dopamine <=  5 or rate_dobutamine is not null then 2
      when MeanBP < 70 then 1
      when coalesce(MeanBP, rate_dopamine, rate_dobutamine, rate_epinephrine, rate_norepinephrine) is null then null
      else 0
    end as cardiovascular	
	-- Liver
  , case
      -- Bilirubin checks in mg/dL
        when Bilirubin >= 12.0 then 4
        when Bilirubin >= 6.0  then 3
        when Bilirubin >= 2.0  then 2
        when Bilirubin >= 1.2  then 1
        when Bilirubin is null then null
        else 0
      end as liver	  
	  -- Coagulation
  , case
      when platelet < 20  then 4
      when platelet < 50  then 3
      when platelet < 100 then 2
      when platelet < 150 then 1
      when platelet is null then null
      else 0
    end as coagulation
	
	-- Renal failure - high creatinine or low urine output
  , case
    when (Creatinine >= 5.0) then 4
    when  uo < 200 then 4
    when (Creatinine >= 3.5 and Creatinine < 5.0) then 3
    when  uo < 500 then 3
    when (Creatinine >= 2.0 and Creatinine < 3.5) then 2
    when (Creatinine >= 1.2 and Creatinine < 2.0) then 1
    when coalesce(uo, Creatinine) is null then null
  else 0 end
    as renal
	
	from daily_data
)

	SELECT stay_id, subject_id , hadm_id, icu_day_start
		   -- parameters from scorecomp
	       , PaO2FiO2ratio 
		   , gcs, meanbp , rate_dopamine , rate_norepinephrine, rate_epinephrine
	       , bilirubin , platelet , creatinine, uo
		   -- parameters from scorecalc, contains separate scores to estimate the final SOFA score
		   , respiration , cns , cardiovascular , liver , coagulation , renal
		   , (SUM(CASE WHEN respiration IS NULL THEN 1 ELSE 0 END) OVER (PARTITION BY stay_id, icu_day_start) + 
		   		SUM(CASE WHEN cns IS NULL THEN 1 ELSE 0 END) OVER (PARTITION BY stay_id, icu_day_start) + 
				   SUM(CASE WHEN liver IS NULL THEN 1 ELSE 0 END) OVER (PARTITION BY stay_id, icu_day_start) + 
				   SUM(CASE WHEN coagulation IS NULL THEN 1 ELSE 0 END) OVER (PARTITION BY stay_id, icu_day_start) + 
				   SUM(CASE WHEN renal IS NULL THEN 1 ELSE 0 END) OVER (PARTITION BY stay_id, icu_day_start) + 
				   SUM(CASE WHEN cardiovascular IS NULL THEN 1 ELSE 0 END) OVER (PARTITION BY stay_id, icu_day_start)) *100/6
		   	AS percentual_missing_value
		   -- overall SOFA score calculation
	       , coalesce(respiration,0) + coalesce(cns,0) 
	       + coalesce(cardiovascular,0) + coalesce(liver,0) 
	       + coalesce(coagulation,0) + coalesce(renal,0) as SOFA
		   
	FROM scorecalc
	
	ORDER BY stay_id, subject_id , hadm_id, icu_day_start;

create index idx_sofaday on tesi.sofaDays(stay_id, subject_id , hadm_id, icu_day_start );
