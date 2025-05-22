DROP TABLE IF EXISTS tesi.prova_intubation; CREATE TABLE tesi.prova_intubation AS
WITH vent_time_clean AS (
  SELECT 
   stay_id,
    starttime as intubation_time,
    COALESCE(endtime , starttime + interval '12 hour') AS extubation_time,
	is_tracheo,
	tracheo_ts,
	end_mech_vent,
	time_no_mech_vent,
	LEAD(starttime) OVER (PARTITION BY stay_id ORDER BY starttime) AS next_intubation_time
  FROM tesi.vent_time
)
  SELECT 
    vp.*,
    CASE 
      WHEN vt.intubation_time IS NOT NULL
        AND peep is not null and fio2 is not null and tidal_volume is not null and (vent_type !='Hamilton' or vent_type is null) and vent_mode in ('(S) CMV', 'APRV', 'APRV/Biphasic+ApnPress',
					'APRV/Biphasic+ApnVol', 'APV (cmv)', 'Apnea Ventilation', 'CMV', 'CMV/ASSIST', 'CMV/ASSIST/AutoFlow', 'CMV/AutoFlow', 'CPAP/PPS', 
					'CPAP/PSV', 'CPAP/PSV+Apn TCPL', 'CPAP/PSV+ApnPres', 'CPAP/PSV+ApnVol', 'MMV', 'MMV/AutoFlow', 'MMV/PSV', 'MMV/PSV/AutoFlow', 'P-CMV', 'PCV+',
					'PCV+/PSV', 'PCV+Assist', 'PRES/AC', 'PRVC/AC', 'PRVC/SIMV', 'PSV/SBT', 'SIMV', 'SIMV/AutoFlow', 'SIMV/PRES', 'SIMV/PSV', 'SIMV/PSV/AutoFlow', 
					'SIMV/VOL', 'SYNCHRON MASTER', 'SYNCHRON SLAVE', 'VOL/AC') 
        THEN 1 
	  WHEN vt.intubation_time IS NOT NULL
		AND peep is not null and fio2 is not null and tidal_volume is not null and vent_type ='Hamilton' 
			 		and vent_mode in ('APRV', 'APV (cmv)',  '(S) CMV', 'P-CMV', 'SIMV', 'APV (simv)', 'P-SIMV', 'VS', 'ASV','SPONT','DuoPaP')
		THEN 1
		WHEN vt.intubation_time is not null and (peep is null or fio2 is null or tidal_volume is null or vent_mode is null ) and is_tracheo=0
		then 1
		WHEN vt.intubation_time is not null and is_tracheo=1 and coalesce(peep, tidal_volume) is not null and fio2 is not null
		then 1
		ELSE 0
    END AS is_intubated,
    vt.intubation_time,
    vt.extubation_time,
	is_tracheo,
	tracheo_ts,
	end_mech_vent,
	time_no_mech_vent,
	next_intubation_time
  FROM tesi.vent_param vp
  LEFT JOIN vent_time_clean vt 
    ON vp.stay_id = vt.stay_id
	and vt.intubation_time <= vp.icu_day_start + interval '239' MINUTE
	and  extubation_time >= vp.icu_day_start
order by stay_id, icu_day_start, intubation_time;

DROP INDEX IF EXISTS tesi.idx; CREATE INDEX idx on tesi.prova_intubation(subject_id,stay_id,icu_day_start);
SELECT * from tesi.prova_intubation;