DROP TABLE IF EXISTS tesi.final_data; CREATE TABLE tesi.final_data AS 
SELECT *
FROM tesi.overalltableprova
where subject_id in (
	SELECT subject_id
	FROM tesi.overalltablePROVA
	GROUP BY subject_id
	HAVING MAX(is_intubated)>0 and max(ph) is not null
)