-- ------------------------------------------------------------------
-- Title: Extract height and weight for BMI
-- Description: This query gets the first weight and height for a single stay.
-- It extracts data from the chartevents table.
-- ------------------------------------------------------------------

DROP TABLE IF EXISTS tesi.bmi; CREATE TABLE tesi.bmi AS

With height as (
	SELECT
	  ie.subject_id,
	  ie.stay_id,
	  ROUND(CAST(AVG(height) AS DECIMAL), 2) AS height
	FROM tesi.cohort AS ie
	LEFT JOIN mimiciv_derived.height AS ht
	  ON ie.stay_id = ht.stay_id
	  AND ht.charttime >= ie.icu_intime - INTERVAL '6 HOUR'
	  AND ht.charttime <= ie.icu_intime + INTERVAL '1 DAY'
	GROUP BY
	  ie.subject_id,
	  ie.stay_id
), weight as (
	SELECT
	ie.subject_id,
	ie.stay_id,
	AVG(CASE WHEN weight_type = 'admit' THEN ce.weight ELSE NULL END) AS weight_admit,
	round(CAST(AVG(ce.weight) as decimal) ,2) AS weight,
	MIN(ce.weight) AS weight_min,
	MAX(ce.weight) AS weight_max
	FROM tesi.cohort AS ie
	/* admission weight */
	LEFT JOIN mimiciv_derived.weight_durations AS ce
	ON ie.stay_id = ce.stay_id
	AND /* we filter to weights documented during or before the 1st day */ ce.starttime <= ie.icu_intime + INTERVAL '1 DAY'
	GROUP BY
	ie.subject_id,
	ie.stay_id
)
select w.subject_id, w.stay_id, weight_admit as weight, height,
		ROUND(cast(w.weight_admit/((h.height/100)^2) as decimal), 2) as bmi
from weight w
left join height h on w.stay_id=h.stay_id and w.subject_id = h.subject_id;

select * from tesi.bmi;