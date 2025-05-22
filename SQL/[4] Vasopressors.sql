DROP TABLE IF EXISTS tesi.vasopressors; create table tesi.vasopressors as 
WITH norepinephrine_dose as (
	SELECT
	stay_id,
	linkorderid, /* two rows in mg/kg/min... rest in mcg/kg/min */ /* the rows in mg/kg/min are documented incorrectly */ /* all rows converted into mcg/kg/min (equiv to ug/kg/min) */
	CASE
	WHEN rateuom = 'mg/kg/min' AND patientweight = 1
	THEN rate
	WHEN rateuom = 'mg/kg/min'
	THEN rate * 1000.0
	ELSE rate
	END AS vaso_rate,
	amount AS vaso_amount,
	starttime,
	endtime
	FROM mimiciv_icu.inputevents
	WHERE
	itemid = 221906 /* norepinephrine */
), dopamine_dose as (
		SELECT
		stay_id,
		linkorderid, /* all rows in mcg/kg/min */
		rate AS vaso_rate,
		amount AS vaso_amount,
		starttime,
		endtime
		FROM mimiciv_icu.inputevents
		WHERE
		itemid = 221662 /* dopamine */
), vasopressin_dose as (
		SELECT
		stay_id,
		linkorderid, /* three rows in units/min, rest in units/hour */ /* the three rows in units/min look reasonable and */ /* fit with the patient course */ /* convert all rows to units/hour */
		CASE WHEN rateuom = 'units/min' THEN rate * 60.0 ELSE rate END AS vaso_rate,
		amount AS vaso_amount,
		starttime,
		endtime
		FROM mimiciv_icu.inputevents
		WHERE
		itemid = 222315 /* vasopressin */
), dobutamine_dose as (
		SELECT
		stay_id,
		linkorderid, /* all rows in mcg/kg/min */
		rate AS vaso_rate,
		amount AS vaso_amount,
		starttime,
		endtime
		FROM mimiciv_icu.inputevents
		WHERE
		itemid = 221653 /* dobutamine */	
), epinephrine_dose as(
		SELECT
		stay_id,
		linkorderid, /* all rows in mcg/kg/min */
		rate AS vaso_rate,
		amount AS vaso_amount,
		starttime,
		endtime
		FROM mimiciv_icu.inputevents
		WHERE
		itemid = 221289 /* epinephrine */
),vaso_union AS (
	SELECT stay_id, starttime, 
			vaso_rate as rate_norepinephrine,
			CAST(null AS DOUBLE PRECISION) as rate_dopamine,
			CAST(null AS DOUBLE PRECISION) as rate_vasopressin,
			CAST(null AS DOUBLE PRECISION) as rate_dobutamine,
			CAST(null AS DOUBLE PRECISION) as rate_epinephrine
	FROM norepinephrine_dose

	UNION ALL 

	SELECT stay_id, starttime, 
		CAST(null AS DOUBLE PRECISION) as rate_norepinephrine,
		vaso_rate as rate_dopamine,
		CAST(null AS DOUBLE PRECISION) as rate_vasopressin,
		CAST(null AS DOUBLE PRECISION) as rate_dobutamine,
		CAST(null AS DOUBLE PRECISION) as rate_epinephrine
	FROM dopamine_dose

	UNION ALL 

	SELECT stay_id, starttime, 
		CAST(null AS DOUBLE PRECISION) as rate_norepinephrine,
		CAST(null AS DOUBLE PRECISION) as rate_dopamine,
		vaso_rate as rate_vasopressin,
		CAST(null AS DOUBLE PRECISION) as rate_dobutamine,
		CAST(null AS DOUBLE PRECISION) as rate_epinephrine
		
	FROM vasopressin_dose 

	UNION ALL

	SELECT stay_id, starttime, 
		CAST(null AS DOUBLE PRECISION) as rate_norepinephrine,
		CAST(null AS DOUBLE PRECISION) as rate_dopamine,
		CAST(null AS DOUBLE PRECISION) as rate_vasopressin,
		vaso_rate as rate_dobutamine,
		CAST(null AS DOUBLE PRECISION) as rate_epinephrine
	FROM dobutamine_dose

	UNION ALL

	SELECT stay_id, starttime, 
		CAST(null AS DOUBLE PRECISION) as rate_norepinephrine,
		CAST(null AS DOUBLE PRECISION) as rate_dopamine,
		CAST(null AS DOUBLE PRECISION) as rate_vasopressin,
		CAST(null AS DOUBLE PRECISION) as rate_dobutamine,
		vaso_rate as rate_epinephrine
	FROM epinephrine_dose
	
) --select * from vaso_union;
,vaso as
(SELECT stay_id,starttime, 
  -- max command is used to merge different vasopressors taken at the same time into a single row.
	max(rate_norepinephrine) as rate_norepinephrine,
	max(rate_dopamine) as rate_dopamine,
	max(rate_vasopressin) as rate_vasopressin,
	max(rate_dobutamine) as rate_dobutamine,
	max(rate_epinephrine) as rate_epinephrine
	
	FROM vaso_union

	GROUP BY stay_id, starttime
 )
 
 SELECT *,
    coalesce(rate_norepinephrine,0) + + coalesce(rate_dopamine/100,0) +
	coalesce(rate_vasopressin*8.33,0) + coalesce(rate_dobutamine/100,0) +
	coalesce(rate_epinephrine,0)  as vaso_total
	
FROM vaso
ORDER BY stay_id, starttime;

select * from tesi.vasopressors