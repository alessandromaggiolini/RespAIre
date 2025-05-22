Per poter compilare i file bisogna aver fatto eseguire le seguenti query presenti nel mimic:
	* height: https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/firstday/first_day_height.sql
	* weight_durations: https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/demographics/weight_durations.sql
	* antibiotic: https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/medication/antibiotic.sql
	* suspicion_of_infection: https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/sepsis/suspicion_of_infection.sql
	* oxygen_delivery: https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/oxygen_delivery.sql
	* ventilator_settings: https://github.com/MIT-LCP/mimic-code/blob/main/mimic-iv/concepts_postgres/measurement/ventilator_setting.sql 

Ordine esecuzione query:
	* Demographics: crea la tabella 'tesi.demographics' aggregando dati anagrafici e clinici da patients, admissions e icustays.
					Calcola l’età al momento del ricovero, durata della degenza ospedaliera e ICU, indicatori di mortalità (ospedaliera, 28/90 giorni, in-ICU)
   					e integra l’informazione DNR estratta da chartevents.
	* Cohort: Crea la tabella 'tesi.cohort' selezionando pazienti adulti (età ≥ 18 anni) dal primo ricovero ospedaliero e ICU. 
			  Include solo soggetti con informazioni complete sulla mortalità ospedaliera e in terapia intensiva, ed esclude quelli con ordini DNR.  
	* Charlson_comorbidity: crea la tabella 'tesi.charlson' estrae tutte le informazioni per poter calcolare Charlson Comorbidity Index (CCI) considerando codici ICD-9 e ICD-10. 
	* Bmi_w_h: crea la tabella 'tesi.bmi' aggregando dati provenienti da chartevents. Questa query preleva il peso (Kg) e l'altezza (cm) di ogni paziente e ne calcola il bmi come 
				peso/((altezza/100)^2) [Kg/m^2]
	* Vasopressors: Crea la tabella 'tesi.vasopressors' contenente il dosaggio aggregato dei principali vasopressori somministrati nei pazienti ICU.  
					Estrae le infusioni da inputevents per norepinefrina(mg) , dopamina(mg), vasopressina(unit), dobutamina(mg) ed epinefrina(mg), normalizzando le unità di misura.  
	* UrineOutput: Crea la tabella 'tesi.getUrineOutput', che aggrega il volume di output urinario per ciascun paziente ('subject_id'), ricovero ospedaliero ('hadm_id') e degenza
	                  in terapia intensiva ('stay_id') a livello di 'charttime'.
					  La query considera diversi tipi di output urinario (catetere Foley, urinazione spontanea, stent, ecc.) 
					  e tratta i volumi di irrigazione genito-urinaria in ingresso ('GU Irrigant Volume In', 'itemid = 227488') come negativi, per rappresentare correttamente il bilancio netto.  
					  Il volume urinario viene poi sommato per ogni 'charttime', fornendo così una misura temporale aggregata dell'output urinario del paziente.
	* AllLabValues: Questa query crea la tabella 'tesi.getAllLabvalues', contenente i principali valori di laboratorio rilevati durante la degenza in terapia intensiva. 
					I dati provengono da 'labevents' e 'chartevents' e vengono associati agli ICU stay attraverso join con la tabella 'tesi.cohort', considerando un intervallo di tempo 
					che va da 6 ore prima dell'ingresso in ICU fino a un giorno dopo l'uscita. Vengono selezionati valori clinicamente rilevanti 
									- ALBUMINA g/dL 						- POTASSIO mEq/L
									- BICARBONATO mEq/L 					- SODIO mEq/L 
									- BILIRUBINA mg/dL						- PO2 mmHg
									- CREATININEMIA mg/dL					- PCO2 mmHg
									- EMOGLOBINA g/dL						- AZOTEMIA mg/dL
									- LATTATI mmol/L 						- Leuociti K/uL
									- PIASTRINE K/uL 
	* AllVitalSigns: La query crea la tabella 'tesi.getAllVitalSigns', che aggrega i principali segni vitali e il punteggio GCS (Glasgow Coma Scale) per ciascun paziente ricoverato in terapia intensiva (ICU), 
	                 utilizzando i dati di 'chartevents'.
					1. Estrazione dei segni vitali : Seleziona valori validi per:
   							- Frequenza cardiaca (HeartRate)
   							- Pressione arteriosa (sistolica, diastolica e media)
   							- Frequenza respiratoria
   							- Temperatura corporea in °C (con conversione da Fahrenheit se necessario)
   							- Saturazione di ossigeno (SpO₂)
					2. Calcolo del punteggio GCS:
   						- Recupera i 3 componenti GCS: motorio, verbale e apertura occhi.
   						- Gestisce i casi in cui il paziente è intubato (con flag 'EndoTrachFlag') e applica una logica di imputazione del valore precedente (fino a 6 ore prima) se i dati attuali sono mancanti.
   						- Calcola il GCS totale usando componenti correnti o precedenti (o valori predefiniti se entrambi mancanti).
					3. Aggregazione finale: Per ciascuna combinazione di 'stay_id' e 'charttime', calcola:
   						- Medie di HeartRate, BP, Respiratory Rate e SpO₂
   						- Massimo della temperatura (TempC)
   						- Riporta il punteggio GCS associato
					Il risultato è una tabella temporale di osservazioni vitali arricchita con GCS.
	* Infection: Questa query crea la tabella 'tesi.infection', che identifica per ogni ricovero in ICU se vi è evidenza di infezione sospetta al momento dell'ammissione e, se disponibile, la sede dell'infezione.
				 Utilizza i dati da 'mimiciv_derived.suspicion_of_infection' per determinare il tempo della sospetta infezione, confrontandolo con il tempo di ingresso in ICU (entro 6 o 48 ore). 
				 La sede dell'infezione viene dedotta da 'microbiologyevents', classificando il tipo di campione microbiologico. 
				 Si mantiene una sola riga per ICU stay, selezionando il primo evento rilevante. 
	* Sedatives: Questo script crea la tabella 'tesi.sedatives', che contiene informazioni sull'esposizione a sedativi per ogni finestra di 4 ore durante la degenza in ICU (unità di terapia intensiva) per i pazienti della coorte.
				 Si identificano gli eventi relativi a:
					- sedativi (inclusi benzodiazepine, neurolettici, propofol, ketamina, etc.) da 'inputevents' 
					- anestetici inalatori alogenati da 'procedureevents'.
				Per ogni intervallo di 4 ore, viene verificata la presenza di almeno un sedativo ('is_sedated = 1') e viene fornito un elenco ('sedation_type') dei tipi di sedativi somministrati in quel periodo.
	* Opioids: Crea la tabella 'tesi.opioids', che contiene informazioni sull'esposizione a oppioidi per ciascuna finestra di 4 ore durante la degenza in ICU per i pazienti della coorte.
			   Verifica se è stato somministrato almeno un oppioide (fentanyl, morfina, tramadolo, ecc.)
	* Neuroblocks: Crea la tabella 'tesi.neuroblock', che registra l'esposizione a bloccanti neuromuscolari (es. rocuronio, vecuronio, succinilcolina) per ogni intervallo di 4 ore durante la degenza in ICU.
	* Flags: Questo script crea la tabella 'flags' che raccoglie vari indicatori di trattamento e condizione per ogni paziente in un'unità di terapia intensiva (ICU) a intervalli di 24 ore.
			 Viene creata la tabella finale 'flags', che contiene informazioni su ciascun paziente per ogni intervallo di 4 ore:
				- CRRT_24h: Indica se è stato effettuata CRRT nelle 24 ore precedenti l'intervallo.
				- INO_24h: Indica se è stato inalato ossido nitrico nelle 24 ore precedenti.
				- PRONE_24h: Indica se al paziente è stato fatta pronazione nelle 24 ore precedenti.
				- Diuretico_24h: Indica se è stato somministrato un diuretico nelle 24 ore precedenti.
				- Steroid_24h: Indica se è stata usata una terapia con steroide nelle 24 ore precedenti.
				- Transfusion_24h: Indica se è stata somministrata una trasfusione di sangue nelle 24 ore precedenti.
				- Transfusion_type: Categorizza il tipo di trasfusione somministrata (ad esempio, sangue intero, plasma, piastrine).
	* Ards_shock_admission: Crea la tabella 'tesi.ards_shock_admission' che assegna una categoria clinica di ammissione in ICU e rileva la presenza di ARDS e shock settico in base ai codici ICD.
	* Flag_all: Creazione della tabella 'tesi.allFlags' che unisce informazioni provenienti da più tabelle: 
  				- I dati sui neuroblocco ('neuroblock'), oppioidi ('opioids'), sedativi ('sedatives') e flag ('flags') sono combinati in un'unica riga per ogni paziente, giorno e ammissione.
  				- Vengono aggiunti anche i dati relativi a infezioni e shock/ARDS provenienti dalle tabelle 'infection' e 'ards_shock_admission', permettendo un'analisi completa delle condizioni del paziente in ICU.
	* AllLabValues_times: Questo script crea la tabella 'getalllabvalues_time' che raccoglie i valori medi di vari parametri di laboratorio per ogni paziente in unità di terapia intensiva (ICU), suddivisi in intervalli di 4 ore.
   						  La tabella 'getalllabvalues' contiene i valori dei parametri di laboratorio registrati per ciascun paziente. Viene calcolata la media di ciascun parametro di laboratorio per ogni paziente e 
						  per ogni intervallo di 4 ore ('icu_day_start').
	* UrineOutput_times: Questo script crea una tabella 'geturineoutput_time' che contiene la media della produzione urinaria per ogni paziente ('subject_id'), ricovero ('hadm_id'), 
						 e soggiorno ('stay_id') per ogni intervallo di 4 ore ('icu_day_start') durante la sua permanenza in ICU.
	* AllVitalSigns_times: La tabella 'getallvitalsigns_time' contiene la media e il valore massimo di questi parametri vitali per ogni paziente ('subject_id'), ricovero ('hadm_id'),
						   e soggiorno ('stay_id') per ogni intervallo di 4 ore ('icu_day_start') durante la sua permanenza in ICU.
	* Vasopressors_times: Questo script crea la tabella 'getvasopressor_time' che raccoglie le informazioni relative alle infusioni di vasopressori somministrate ai pazienti durante la loro permanenza in unità di terapia intensiva (ICU).
							Viene calcolato il tasso medio di somministrazione per ogni vasopressore  durante ogni intervallo di 4 ore ('icu_day_start').
    * AllDemoCohort: Creazione della tabella 'alldemocohort'. La tabella 'alldemocohort' unisce i dati delle tabelle 'cohort', 'bmi' e 'charlson. 
    * Vent_time: Creazione della tabella 'vent_time' che restituisce per ogni paziente ogni evento di ventilazione invasiva. La tabella contiene l'inzio e la fine di ogni evento di ventilazione,
					se il paziente è stato tracheotomizzato e la data presunta; La data di fine ventilazione meccanica.
    * VentParam: Creazuibela tabella 'tesi.vent_param' che aggrega ogni 4 ore i parametri ventilatori per ciascun paziente in ICU, provenienti dalla tabella 'ventilator_setting'.
    * OverallTable1: Creazione della tabella 'tesi.overalltable1'. Aggrega per ogni giornata di degenza (icu_day_start):
							- Valori di laboratorio
							- Output urinario 
							- Farmaci vasopressori
							- Flags clinici
							- Segni vitali
							- Parametri ventilatori
				   Viene inoltre calcolato lo shock index come rapporto tra frequenza cardiaca e pressione sistolica e PaO₂/FiO₂ ratio come indicatore dell’efficienza respiratoria.
    * Sapsii: Creazione della tabella 'tesi.sapsii' che calcola il punteggio SAPS II per i pazienti in terapia intensiva durante le prime 24 ore di ricovero, utilizzando 
   			 vari parametri clinici: età, segni vitali, esami di laboratorio, comorbidità e tipo di ammissione. 
			 Il risultato è un punteggio di severità della malattia e una probabilità stimata di mortalità ospedaliera.
    * Sofa: Creazione della tabella 'tesi.sofa' che calcola il punteggio SOFA giornaliero per ogni paziente ricoverato in terapia intensiva. 
           Aggrega parametri fisiologici : respirazione, coagulazione, fegato, cardiovascolare, sistema nervoso centrale e renale.
		   Aassegnando i punteggi secondo le soglie SOFA espresse nel CFR e calcola anche la percentuale di valori mancanti.
    * Extub_intub_time: Creazione della tabella 'tesi.prova_intubation' per identificare, ogni 4 ore, se un paziente era intubato in base a parametri ventilatori completi e modalità compatibili. 
   					   Incrocia i dati di vent_param con i periodi di ventilazione da vent_time, segnando is_intubated = 1 se le condizioni sono soddisfatte (incluse modalità e tipo di ventilazione).
					   Aggiunge anche i timestamp di intubazione/estubazione e il successivo evento.
    * OverallTable2: Crea una nuova tabella chiamata overalltablePROVA. Unisce i dati giornalieri presenti nella tabella overalltable1 con informazioni sull'intubazione e ventilazione meccanica
   					e con i punteggi SOFA e SAPS 2 calcolati per ogni giornata di ICU. 
    * Final: Restituisce una tabella che contiene i dati finali. Considera i pazienti che sono stati intubati almeno una volta e hanno almeno un valore di ph.
