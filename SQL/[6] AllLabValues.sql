DROP TABLE IF EXISTS tesi.getAllLabvalues; CREATE TABLE tesi.getAllLabvalues AS 
with le as
(
  select ic.icu_intime,ic.icu_outtime,le.subject_id , le.hadm_id, ic.stay_id
    , le.charttime
    , (CASE WHEN itemid = 50862 and valuenum>0 and valuenum <    10 THEN valuenum else null end) as ALBUMIN --  g/dL 'ALBUMIN')
    , (CASE WHEN itemid = 50882 and valuenum>0 and valuenum <10000 THEN valuenum else null end) as BICARBONATE --  mEq/L 'BICARBONATE'
    , (CASE WHEN itemid = 50885 and valuenum>0 and valuenum <150 THEN valuenum else null end) as BILIRUBIN --  mg/dL 'BILIRUBIN'
    , (CASE WHEN itemid = 50912 and valuenum>0 and valuenum <150 THEN valuenum else null end) as CREATININE--  mg/dL 'CREATININE'
    , (CASE WHEN itemid in (50810,51221) and valuenum>0 and valuenum <100 THEN valuenum else null end) as HEMATOCRIT --  % 'HEMATOCRIT'
    , (CASE WHEN itemid in (50811,51222) and valuenum>0 and valuenum <50 THEN valuenum else null end) as HEMOGLOBIN --  g/dL 'HEMOGLOBIN'
    , (CASE WHEN itemid = 50813 and valuenum>0 and valuenum <50 THEN valuenum else null end) as LACTATE --  mmol/L 'LACTATE'
    , (CASE WHEN itemid = 51265 and valuenum>0 and valuenum <10000 THEN valuenum else null end) as PLATELET --  K/uL 'PLATELET'
    , (CASE WHEN itemid in (50822,50971) and valuenum>0 and valuenum <30 THEN valuenum else null end) as POTASSIUM --  mEq/L 'POTASSIUM'
    , (CASE WHEN itemid in (50824,50983) and valuenum>0 and valuenum <200 THEN valuenum else null end) as SODIUM --  mEq/L == mmol/L 'SODIUM'
    , (CASE WHEN itemid = 51006 and valuenum>0 and valuenum <300 THEN valuenum else null end) as BUN --  'BUN'
    , (CASE WHEN itemid in (51300,51301) and valuenum>0 and valuenum <1000 THEN valuenum else null end) as WBC --  'WBC'
	, (CASE WHEN itemid in (50820) THEN valuenum else null end) as pH
	, (CASE WHEN itemid in (50821) THEN valuenum else null end) as PaO2--  mmHg 'PaO2' (units taken from loinc code 11556-8, this actually corresponds to PO2(not PaO2 where 'a' stands for arterial) but couls not find any other related value)
	, (CASE WHEN itemid in (50818) THEN valuenum else null end) as PaCO2--  mmHg 'PaCO2' (units taken from loinc code 11557-6, this actually corresponds to PCO2(not PaCO2 where 'a' stands for arterial) but couls not find any other related value)
  from mimiciv_hosp.labevents le
	--  LABEVENTS do not have a stay_id recorded. However, that can be obtained using clues such as the subject_id and hadm_id; and comparing the charttime of the measurement with an icustay time.
	--  This idea of adding icustays has been retrieved from https://github.com/MIT-LCP/mimic-code/blob/master/concepts/firstday/blood-gas-first-day.sql.
		left join tesi.cohort ic
		on le.subject_id = ic.subject_id and le.hadm_id = ic.hadm_id
		and le.charttime between (ic.icu_intime - interval '6' hour) and (ic.icu_outtime + interval '1' day )
  where le.itemid in
  (
  --  comment is: LABEL | CATEGORY | FLUID | NUMBER OF ROWS IN LABEVENTS
    50862, --  ALBUMIN | CHEMISTRY | BLOOD | 146697
    50882, --  BICARBONATE | CHEMISTRY | BLOOD | 780733
    50885, --  BILIRUBIN, TOTAL | CHEMISTRY | BLOOD | 238277
    50912, --  CREATININE | CHEMISTRY | BLOOD | 797476
    51221, --  HEMATOCRIT | HEMATOLOGY | BLOOD | 881846
    50810, --  HEMATOCRIT, CALCULATED | BLOOD GAS | BLOOD | 89715
    51222, --  HEMOGLOBIN | HEMATOLOGY | BLOOD | 752523
    50811, --  HEMOGLOBIN | BLOOD GAS | BLOOD | 89712
    50813, --  LACTATE | BLOOD GAS | BLOOD | 187124
    51265, --  PLATELET COUNT | HEMATOLOGY | BLOOD | 778444
    50971, --  POTASSIUM | CHEMISTRY | BLOOD | 845825
    50822, --  POTASSIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 192946
    50983, --  SODIUM | CHEMISTRY | BLOOD | 808489
    50824, --  SODIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 71503
    51006, --  UREA NITROGEN | CHEMISTRY | BLOOD | 791925
    51301, --  WHITE BLOOD CELLS | HEMATOLOGY | BLOOD | 753301
    51300,  --  WBC COUNT | HEMATOLOGY | BLOOD | 2371

	50820, --  pH
	50821, --  pO2
	50818 --  pCO2	
	 )   
), final_le as (

 select
  subject_id , hadm_id , stay_id , charttime as charttime,
  avg(PH) as PH, avg(paCO2) as paCO2, avg(paO2) as paO2,
  avg(LACTATE) as LACTATE, avg(HEMOGLOBIN) as HEMOGLOBIN, 
  avg(ALBUMIN) as ALBUMIN,avg(PLATELET) as PLATELET,
  avg(WBC) as WBC,avg(BILIRUBIN) as BILIRUBIN, avg(CREATININE) as CREATININE,
  -- calcolo saps
  avg(BUN) as BUN, avg(SODIUM) as SODIUM, avg(POTASSIUM) as POTASSIUM, avg(BICARBONATE) as BICARBONATE
from le
group by stay_id,subject_id,hadm_id,charttime 
order by stay_id,subject_id,hadm_id,charttime
),stg_po2 AS (
  SELECT
    subject_id,
    charttime, 
    AVG(valuenum) AS po2
  FROM mimiciv_icu.chartevents
  WHERE itemid = 220224
  GROUP BY subject_id, charttime
), 
stg_pco2 AS (
  SELECT
    subject_id,
    charttime, 
    AVG(valuenum) AS pco2
  FROM mimiciv_icu.chartevents
  WHERE itemid = 220235
  GROUP BY subject_id,charttime
),
stg2 AS (
  SELECT
    le.*,
    po2_data.po2,
    ROW_NUMBER() OVER (
      PARTITION BY le.subject_id, le.charttime
      ORDER BY po2_data.charttime DESC
    ) AS lastrowpo2
  FROM final_le le
  LEFT JOIN stg_po2 po2_data
    ON le.subject_id = po2_data.subject_id
    AND po2_data.charttime BETWEEN le.charttime - INTERVAL '2 hour' AND le.charttime
) 
,stg3 AS (
  SELECT
    stg2.*,
    pco2_data.pco2,
    ROW_NUMBER() OVER (
      PARTITION BY stg2.subject_id, stg2.charttime
      ORDER BY pco2_data.charttime DESC
    ) AS lastrowpco2
  FROM stg2
  LEFT JOIN stg_pco2 pco2_data
    ON stg2.subject_id = pco2_data.subject_id
    AND pco2_data.charttime BETWEEN stg2.charttime - INTERVAL '2 hour' AND stg2.charttime
)
select subject_id, charttime,
		ph, coalesce(paco2, pco2) as paco2, coalesce(pao2, po2) as pao2,
		lactate, hemoglobin, albumin, platelet,
		wbc, bilirubin, creatinine, bun, sodium, potassium, bicarbonate
from stg3 where lastrowpo2 = 1 AND lastrowpco2 = 1;

select * from tesi.getalllabvalues;