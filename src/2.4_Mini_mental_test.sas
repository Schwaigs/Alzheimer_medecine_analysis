/*---------------------------2.4.1---------------------------*/

/* Tri du dataset MMSE_RESULT par patient et visite */
PROC SORT DATA = source.MMSE_RESULT OUT = source.MMSE_SORT;
  BY  USUBJID VISDESC;
RUN ;
/* Passage des questions en colonne, variables pivots : patient et visite*/
PROC TRANSPOSE DATA = source.MMSE_SORT OUT = source.MMSE_PRP1 PREFIX=question;
  BY USUBJID VISDESC;
  VAR MMSED1 MMSED2 MMSED3 MMSED5 MMSED6 MMSED7 MMSED8 MMSED9 MMSED10;
RUN ;

/* Passage des résultats en colonne, variables pivots : patient et visite*/
PROC TRANSPOSE DATA = source.MMSE_SORT OUT = source.MMSE_PRP2 PREFIX=score;
  BY USUBJID VISDESC;
  VAR MMSES1 MMSES2 MMSES3 MMSES5 MMSES6 MMSES7 MMSES8 MMSES9 MMSES10;
RUN ;

/* Fusion des deux datasets par patient et visite */
DATA source.MMSE_P_VQS ;
  MERGE source.MMSE_PRP1 source.MMSE_PRP2 ;
  BY  USUBJID VISDESC;
  KEEP USUBJID VISDESC question1 score1;
  RENAME VISDESC=Visite question1=Label_de_la_question score1=Score;
RUN;


/*---------------------------2.4.2---------------------------*/
/* Tri du dataset MMSE_P_VQS par patient et question */
PROC SORT DATA = source.MMSE_P_VQS OUT = source.MMSE_SORT2;
  BY  usubjid Label_de_la_question;
RUN ;

/* Passage des score en ligne, variables pivots : patient et question*/
PROC TRANSPOSE DATA = source.MMSE_SORT2 OUT = source.MMSE_PQ_S;
  BY usubjid Label_de_la_question;
  VAR Score;
  ID Visite;
RUN ;


/*---------------------------2.4.3---------------------------*/
/* Création du score total par addition des score par question */
DATA source.MMSE_Score_total;
SET source.mmse_result;
  ATTRIB Score_total
  LABEL="Score total"
  LENGTH=3;
  Score_total=MMSES1+MMSES2+MMSES3+MMSES5+MMSES6+MMSES7+MMSES8+MMSES9+MMSES10;
RUN;

/* Tri du dataset MMSE_Score_total par patient et visite */
PROC SORT DATA = source.MMSE_Score_total OUT = source.MMSE_SORT3;
  BY  USUBJID VISID;
RUN;

/* Création d'un dataset sans le numéro de la visite d'assignation de groupe de traitement */
DATA source.trt_temp;
  SET source.treatment_assignment;
  KEEP USUBJID TRTDESC;
RUN;

/* Fusion des deux datasets par patient */
DATA source.MMSE_Score;
  MERGE source.MMSE_SORT3 source.trt_temp;
  BY  USUBJID;
  KEEP USUBJID VISID Score_total TRTDESC;
  RENAME VISID=Visite TRTDESC=Groupe_traitement;
RUN;


/*---------------------------2.4.4---------------------------*/
/* Calcul des moyennes par groupe de traitement et visite */
PROC MEANS DATA=source.MMSE_SCORE MEAN;
	CLASS Groupe_traitement Visite;
	VAR Score_total; 
	ODS EXCLUDE summary;
	ODS OUTPUT summary = source.temp;
RUN;

/* Cast des visite d'alphanumérique en numérique */
DATA source.temp_cast;
    SET source.temp;
    num_visit = input(Visite,Best12.);
    DROP Visite; 
RUN;

/* Tri du dataset temp_cast par visite */
PROC SORT DATA = source.temp_cast OUT = source.temp_sort;
    BY num_visit;
RUN;

/* Création du graphique avec les visites en ordonné et les moyennes des scores en abscisse */
PROC SGPLOT DATA=source.temp_sort;
   title 'Evolution des scores totaux par groupe de traitement en fonction du temps (visite)';
   series x=num_visit y=Score_total_Mean / group=Groupe_traitement  name='grouping';
   keylegend 'grouping' / type=linecolor;
RUN;


/*---------------------------2.4.5---------------------------*/
/*Créez un dataset MMSE_freq contenant le numéro de patient, son groupe de traitement, 
    son premier score total  MMSE, et son dernier score MMSE. */
DATA source.MMSE_score_1;
    SET source.MMSE_SCORE;
    IF Visite = '1' /*première visite*/
    THEN score_total_1 = Score_total;
    Else delete;
    KEEP usubjid Groupe_traitement score_total_1;
RUN;

/*Certains patient ont comme numéro de leur dernière visite 21 et d'autres 20 et parfois meme 17*/
DATA source.MMSE_score_end_20;
    SET source.MMSE_SCORE;
    IF Visite = '20'
    THEN score_total_end = Score_total;
    Else delete;
    KEEP usubjid Groupe_traitement score_total_end;
RUN;

DATA source.MMSE_score_end_21;
    SET source.MMSE_SCORE;
    IF Visite = '21'
    THEN score_total_end = Score_total;
    Else delete;
    KEEP usubjid Groupe_traitement score_total_end;
RUN;

DATA source.MMSE_score_end_17;
    SET source.MMSE_SCORE;
    IF Visite = '17'
    THEN score_total_end = Score_total;
    Else delete;
    KEEP usubjid Groupe_traitement score_total_end;
RUN;

DATA source.MMSE_score_end;
    merge source.MMSE_score_end_20  source.MMSE_score_end_21 source.MMSE_score_end_17;
    by usubjid;
    KEEP usubjid Groupe_traitement score_total_end;
RUN;


DATA source.MMSE_freq;
    merge source.MMSE_score_1  source.MMSE_score_end;
    by usubjid;
RUN;


/*---------------------------2.4.6---------------------------*/
*Comparaison des score lors de la première et la dernière visite;
PROC ANOVA DATA = source.MMSE_freq;
	CLASS Groupe_traitement;
	model score_total_1=Groupe_traitement;
RUN;

PROC ANOVA DATA = source.MMSE_freq;
	CLASS Groupe_traitement;
	model score_total_end=Groupe_traitement;
RUN;


/*---------------------------2.4.7---------------------------*/
*Analyse statistique des scores obtenus à la première et à la dernière visite en fonciton de différent paramètres;
data source.mmse_sexe_age_education;
	set source.dm_trt;
	KEEP usubjid SEX TRTDESC age_today ed_group;
run;

data source.mmse_sexe_age_education;
    merge source.mmse_freq source.mmse_sexe_age_education;
    by usubjid;
    drop trtdesc;
run;

/*On décide ici de grouper les scores des patients (c'est fait de manière complètement arbitraire) et on mettra: en dessous de 10, entre 10 et 20 et plus de 20;*/
data source.mmse_sexe_age_education;
	set source.mmse_sexe_age_education;
	attrib p_score label="Score lors de la première Visite" length= $40;
	attrib d_score label="Score lors de la dernière Visite" length= $40;
	if(0<=score_total_1<=10) then  p_score = "Inférieur à 10(inclus)" ;
	else if(11<=score_total_1<=20) then p_score = "Entre 10 (exclu) et 20(inclus)";
	else if(21<=score_total_1) then  p_score = "Supérieur à 20(exclus)" ;
	if(0<=score_total_end<=10) then  d_score = "Inférieur à 10(inclus)" ;
	else if(11<=score_total_end<=20) then d_score = "Entre 10 (exclu) et 20(inclus)";
	else if(21<=score_total_end) then  d_score = "Supérieur à 20(exclus)" ;
run;

/*grouper les patients par tranches d'age*/
data source.mmse_sexe_age_education;
	set source.mmse_sexe_age_education;
	attrib t_age label = "tranche d'age du patient" length= $30;
	if(age_today <= 70) then t_age = "De 50 à 70(inclus) ans";
	else if(71<=age_today<= 80) then t_age = "Entre 70(exclus) et 80(inclus) ans";
	else if(81<=age_today) then t_age = "Plus de 80 ans";

proc sort data= source.mmse_sexe_age_education;
	by Groupe_traitement;

PROC FREQ data = source.mmse_sexe_age_education;
	by Groupe_traitement; *Pour chaque groupe traitement on veux voir si un des facteurs suivants(le sexe, l'age, le niveau d'étude) influe sur l'effet du traitement; 
	table p_score*sex d_score*sex p_score*t_age d_score*t_age p_score*ed_group d_score*ed_group /chisq;

RUN;