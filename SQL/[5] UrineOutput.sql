DROP table IF EXISTS tesi.getUrineOutput;CREATE table tesi.getUrineOutput AS
WITH uo AS (
  SELECT
    oe.subject_id , oe.hadm_id ,oe.stay_id,
    oe.charttime,
	oe.value as urineoutput
	/* volumes associated with urine output ITEMIDs */ /* note we consider input of GU irrigant as a negative volume */ /* GU irrigant volume in usually has a corresponding volume out */ /* so the net is often 0, despite large irrigant volumes */
   -- CASE WHEN oe.itemid = 227488 AND oe.value > 0 THEN -1 * oe.value ELSE oe.value END AS urineoutput
  FROM mimiciv_icu.outputevents AS oe
  WHERE
    itemid IN (226559 /* Foley */, 
				226560 /* Void */, 
				226561 /* Condom Cath */, 
				226584 /* Ileoconduit */, 
				226563 /* Suprapubic */, 
				226564 /* R Nephrostomy */, 
				226565 /* L Nephrostomy */, 
				226567 /* Straight Cath */,
				226557 /* R Ureteral Stent */, 
				226558 /* L Ureteral Stent */ 
				--, 227488 /* GU Irrigant Volume In */, 227489 /* GU Irrigant/Urine Volume Out */
				)
)
SELECT
  subject_id , hadm_id ,stay_id, charttime,
  SUM(urineoutput) AS urineoutput
FROM uo
GROUP BY subject_id, hadm_id, stay_id, charttime
order by subject_id, hadm_id , stay_id, charttime;


