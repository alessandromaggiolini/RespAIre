DROP TABLE IF EXISTS tesi.vent_time; CREATE TABLE tesi.vent_time AS 
/* Classify oxygen devices and ventilator modes into six clinical categories. */
/* Categories include.. */ 
/*  Invasive oxygen delivery types: */ 
/*      Tracheostomy (with or without positive pressure ventilation) */ 
/*      InvasiveVent (positive pressure ventilation via endotracheal tube, */
/*          could be oro/nasotracheal or tracheostomy) */ 
/*  Non invasive oxygen delivery types (ref doi:10.1001/jama.2020.9524): */ 
/*      NonInvasiveVent (non-invasive positive pressure ventilation) */ 
/*      HFNC (high flow nasal oxygen / cannula) */
/*      SupplementalOxygen (all other non-rebreather, */ 
/*          facemask, face tent, nasal prongs...) */ 
/*  No oxygen device: */
/*      None */ 
/* When conflicting settings occur (rare), the priority is: */ 
/*  trach > mech vent > NIV > high flow > o2 */
/* Some useful cases for debugging: */ 
/*  stay_id = 30019660 has a tracheostomy placed in the ICU */
/*  stay_id = 30000117 has explicit documentation of extubation */ 
/* first we collect all times which have relevant documentation */
WITH vs AS (
  SELECT
    vs.stay_id,
    vs.charttime, /* source data columns, here for debug */
    o2_delivery_device_1,
    COALESCE(ventilator_mode, ventilator_mode_hamilton) AS vent_mode, /* case statement determining the type of intervention */ /* done in order of priority: trach > mech vent > NIV > high flow > o2 */
    CASE WHEN o2_delivery_device_1 IN ('Tracheostomy tube' , 'Trach mask ')
      THEN vs.charttime end as tracheo,
	CASE
      WHEN o2_delivery_device_1 IN ('Endotracheal tube', 'Tracheostomy tube') 
      or ventilator_mode IN ('(S) CMV', 'APRV', 'APRV/Biphasic+ApnPress', 
	  							'APRV/Biphasic+ApnVol', 'APV (cmv)', 'Apnea Ventilation', 
								 'CMV', 'CMV/ASSIST', 'CMV/ASSIST/AutoFlow', 'CMV/AutoFlow', 
								 'MMV', 'MMV/AutoFlow', 'MMV/PSV', 'MMV/PSV/AutoFlow', 'P-CMV', 'PCV+', 
								 'PCV+/PSV', 'PCV+Assist', 'PRES/AC', 'PRVC/AC', 'PRVC/SIMV', 'PSV/SBT',
								 'SIMV', 'SIMV/AutoFlow', 'SIMV/PRES', 'SIMV/PSV', 'SIMV/PSV/AutoFlow',
								 'SIMV/VOL', 'SYNCHRON MASTER', 'SYNCHRON SLAVE', 'VOL/AC')
		or (ventilator_mode in ('CPAP/PPS',
								 'CPAP/PSV', 'CPAP/PSV+Apn TCPL', 'CPAP/PSV+ApnPres', 'CPAP/PSV+ApnVol', 'SPONT') and o2_delivery_device_1 in ('Endotracheal tube', 'Tracheostomy tube'))
      OR ventilator_mode_hamilton IN ('APRV', 'APV (cmv)',  '(S) CMV', 'P-CMV', 'SIMV', 'APV (simv)', 'P-SIMV', 'VS', 'ASV','SPONT')
	  or (ventilator_mode_hamilton = 'DuoPaP' and o2_delivery_device_1 in ('Endotracheal tube', 'Tracheostomy tube'))
      THEN 'InvasiveVent'
      WHEN o2_delivery_device_1 IN ('Bipap mask ' /* 8997 observations */, 'CPAP mask ' /* 5568 observations */)
      OR ventilator_mode_hamilton IN ('DuoPaP', 'NIV', 'NIV-ST')
      THEN 'NonInvasiveVent'
      WHEN o2_delivery_device_1 IN ('High flow nasal cannula' /* 925 observations */)
      THEN 'HFNC'
      WHEN o2_delivery_device_1 IN ('Non-rebreather' /* 5182 observations */, 'Face tent' /* 24601 observations */, 'Aerosol-cool' /* 24560 observations */, 'Venti mask ' /* 1947 observations */, 'Medium conc mask ' /* 1888 observations */, 'Ultrasonic neb' /* 9 observations */, 'Vapomist' /* 3 observations */, 'Oxymizer' /* 1301 observations */, 'High flow neb' /* 10785 observations */, 'Nasal cannula')
      THEN 'SupplementalOxygen'
      WHEN o2_delivery_device_1 IN ('None')
      THEN 'None'
      ELSE NULL
    END AS ventilation_status
  FROM mimiciv_derived.ventilator_setting AS vs
  LEFT JOIN mimiciv_derived.oxygen_delivery AS od
    ON vs.stay_id = od.stay_id AND vs.charttime = od.charttime
), vd0 AS (
  SELECT
    stay_id,
    charttime, /* source data columns, here for debug */ /* , o2_delivery_device_1 */ /* , vent_mode */ /* carry over the previous charttime which had the same state */
    LAG(charttime, 1) OVER (PARTITION BY stay_id, ventilation_status ORDER BY charttime NULLS FIRST) AS charttime_lag, /* bring back the next charttime, regardless of the state */ /* this will be used as the end time for state transitions */
    LEAD(charttime, 1) OVER w AS charttime_lead,
    ventilation_status,
    LAG(ventilation_status, 1) OVER w AS ventilation_status_lag,
	tracheo
  FROM vs
  WHERE
    NOT ventilation_status IS NULL
  WINDOW w AS (PARTITION BY stay_id ORDER BY charttime NULLS FIRST)
) 
, vd1 AS (
  SELECT
    stay_id,
    charttime,
    charttime_lag,
    charttime_lead,
    ventilation_status, /* source data columns, here for debug */ /* , o2_delivery_device_1 */ /* , vent_mode */ /* calculate the time since the last event */
    ventilation_status_lag,
	tracheo,
	CAST(EXTRACT(EPOCH FROM charttime - charttime_lag) / 60.0 AS DOUBLE PRECISION) / 60 AS ventduration, /* now we determine if the current ventilation status is "new", */ /* or continuing the previous event */
    CASE
      WHEN ventilation_status_lag IS NULL
      THEN 1
      WHEN ventilation_status_lag <> ventilation_status
      THEN 1
      ELSE 0
    END AS new_ventilation_event
  FROM vd0
) 
, vd2 AS (
  SELECT
    vd1.stay_id,
    vd1.charttime,
    vd1.charttime_lead,
	tracheo,
    vd1.ventilation_status,
    ventduration,
    new_ventilation_event, /* create a cumulative sum of the instances of new ventilation */ /* this results in a monotonically increasing integer assigned */ /* to each instance of ventilation */
    case when ventilation_status='InvasiveVent' then SUM(new_ventilation_event) OVER (PARTITION BY stay_id ORDER BY charttime NULLS FIRST) end as vent_seq
  FROM vd1
) 

, vd3 as (
SELECT
  stay_id,
  MIN(charttime) AS starttime, /* for the end time of the ventilation event, the time of the *next* setting */ /* i.e. if we go NIV -> O2, the end time of NIV is the first row */ /* with a documented O2 device */ /* ... unless it's been over 14 hours, */ /* in which case it's the last row with a documented NIV. */
  MAX(
    CASE
      WHEN charttime_lead IS NULL
      THEN charttime
      ELSE charttime_lead
    END
  ) AS endtime, /* all rows with the same vent_num will have the same ventilation_status */ /* for efficiency, we use an aggregate here, */ /* but we could equally well group by this column */
  MAX(ventilation_status) AS ventilation_status,
  min(tracheo) as tracheo
FROM vd2
WHERE ventilation_status='InvasiveVent'
GROUP BY stay_id, vent_seq
HAVING MIN(charttime) <> MAX(charttime)
)

select vd3.stay_id, c.icu_intime, c.icu_outtime, vd3.starttime, vd3.endtime, vd3.tracheo as tracheo_ts
	,CASE WHEN COUNT(tracheo) OVER (PARTITION BY vd3.stay_id )>0 then 1 else 0 end as is_tracheo
	,ROUND(EXTRACT(EPOCH from endtime-starttime)/3600) as ventduration
	,ROW_NUMBER() OVER (PARTITION BY vd3.stay_id ORDER BY starttime) as num_event
	--,LEAD(starttime) OVER (PARTITION BY stay_id ORDER BY starttime) AS reintubazione_start
	,MAX(endtime) OVER (PARTITION BY vd3.stay_id ORDER BY starttime desc) as end_mech_vent
	,round(EXTRACT(EPOCH FROM (LEAD(starttime) OVER (PARTITION BY vd3.stay_id ORDER BY starttime) - endtime))/3600) AS time_no_mech_vent
from tesi.cohort c
left join vd3 on c.stay_id=vd3.stay_id and starttime between icu_intime and icu_outtime
where EXTRACT(EPOCH from endtime-starttime)/3600>=1
order by vd3.stay_id, vd3.starttime, c.icu_intime, num_event;

select * from tesi.vent_time;
