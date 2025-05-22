DROP TABLE IF EXISTS tesi.vent_param; CREATE TABLE tesi.vent_param AS 

with icu_days as (
	SELECT
    icu.subject_id,
    icu.hadm_id,
    icu.stay_id,
	icu.icu_intime,
	icu.icu_outtime,
    generate_series(icu.icu_intime, icu.icu_outtime, interval '4 hours') AS icu_day_start
  FROM tesi.cohort icu
),
vent_par as (
	select subject_id, v.stay_id, charttime, 
			case when coalesce( tidal_volume_observed, tidal_volume_set, tidal_volume_spontaneous)<1500 then coalesce( tidal_volume_observed, tidal_volume_set, tidal_volume_spontaneous) else null end as tidal_volume, peep, fio2,
			coalesce(ventilator_mode, ventilator_mode_hamilton) as vent_mode,
			ventilator_type
	from tesi.vent_time v 
	left join mimiciv_derived.ventilator_setting vs on vs.stay_id = v.stay_id
)
select v.subject_id, v.stay_id, icu_day_start, 
		avg(case when charttime between icu_day_start and icu_day_start + interval '4 hours' then tidal_volume end ) as tidal_volume, 
		avg(case when charttime between icu_day_start and icu_day_start + interval '4 hours' then peep end) as peep, 
		avg(case when charttime between icu_day_start and icu_day_start + interval '4 hours' then fio2 end) as fio2, 
		max(case when charttime between icu_day_start and icu_day_start + interval '4 hours' then vent_mode end) as vent_mode, 
		max(case when charttime between icu_day_start and icu_day_start + interval '4 hours' then ventilator_type end) as vent_type
from vent_par as v
left join icu_days d on d.stay_id=v.stay_id and charttime BETWEEN d.icu_intime and d.icu_outtime
group by v.subject_id, v.stay_id, icu_day_start
order by v.subject_id, v.stay_id, icu_day_start

