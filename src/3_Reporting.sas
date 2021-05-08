/* -------------------- 3.2 import du fichier des patiens -----------------------*/
Data source.Patient;
 INFILE "/folders/myfolders/MiniProjet/groupe14.csv" FIRSTOBS=2;
 INPUT usubjid $;
 ATTRIB usubjid  LABEL="Unique Subject Identifer" LENGTH=$7. FORMAT=$7.;
RUN;

/* -------------------- 3.3 création d'un pdf par patient -----------------------*/
/*Tri par patient des tables avant la fusion*/
PROC SORT DATA = source.Patient OUT = source.Patient;
  BY USUBJID;
RUN;
PROC SORT DATA = source.DM_TRT OUT = source.DM_TRT;
  BY USUBJID;
RUN;
PROC SORT DATA = source.VS_DM OUT = source.VS_DM;
  BY USUBJID;
RUN;
PROC SORT DATA = source.MMSE_Score OUT = source.MMSE_Score;
  BY USUBJID;
RUN;
PROC SORT DATA = source.adverse_event OUT = source.adverse_event;
  BY USUBJID;
RUN;

/*Fusions des différentes données obtenues dans la partie 2*/
DATA source.Patient_data;
MERGE source.Patient (IN=mark1)
      source.DM_TRT (IN=mark2) /*Partie démographie*/
      source.VS_DM (IN=mark3) /*Partie signes vitaux*/
      source.MMSE_Score (IN=mark4) /*Partie mini mental test*/
      source.adverse_event (IN=mark5); /*Partie evenements indésirables*/
BY usubjid;	
if mark1 /*On ne s'intéresse qu'as nos 5 patients*/
then output;
RUN;

/*Mise en page du pdf*/
PROC TEMPLATE;
/*Nom du style pour pouvoir l'appeler lors de la génération du pdf*/
define style styles.reportM31;
parent=styles.rtf;
options papersize=A4;
/*Style du corps global du doccument*/
style body from Document /
	bottommargin = 2cm
	topmargin	= 2cm
	rightmargin  = 1cm
	leftmargin   = 1cm;
/*Style du texte du doccument*/
style usertext from usertext /
	font_size = 12pt
	font_face = 'Arial';
end;
run;


%macro pdf(idPatient);
	/*Génération des pdf*/
	/*Symbole pour reconnaitre les instructions de mises en forme du texte*/
	ods escapechar="^";
	/*On enlève la date et le numero de la page qui se placent en haut*/
	options nodate nonumber;
	ods pdf file="/folders/myfolders/MiniProjet/rapport_&idPatient. .pdf" style=styles.reportM31;
	/*Mise en page du cartouche au début du pdf*/
	ods text ="^S={FONT_SIZE=14pt FONTWEIGHT=bold just=c asis=on 
					borderleftcolor=black borderleftwidth=1pt
	    			borderrightcolor=black borderrightwidth=1pt
	   	 			borderbottomcolor=black borderbottomwidth=1pt
	    			bordertopcolor=black bordertopwidth=1pt} 
	    			Etude Mentalor    |                   PATIENT &idPatient.                   |    UPBRAIN";
	/*Saut de ligne*/
	ods pdf text=' ';
	
	ods pdf text='^S={FONT_SIZE=14pt FONTWEIGHT=bold} Démographie';
	ods pdf text=' ';
	    DATA source.DM_TRT_PATIENT1;  
	        set source.DM_TRT;
	        if usubjid = "&idPatient."
	        then output;
	        KEEP SEX AGE_TODAY EDCCNT TRTDESC;
	        LABEL SEX = "Sexe";
	        LABEL AGE_TODAY = "Age";
	        LABEL TRTDESC = "Groupe de traitement";
	        LABEL EDCCNT = "Années d'éducation";
	
	    PROC TRANSPOSE DATA= source.DM_TRT_PATIENT1 OUT = source.DM_TRT_PATIENT1_TRANSPOSE;
	        VAR SEX AGE_TODAY EDCCNT TRTDESC;
	
	    DATA source.DM_TRT_PATIENT_PDF;  
	        SET source.DM_TRT_PATIENT1_TRANSPOSE;
	        DROP _NAME_;
	    RUN;
	    
		proc report noheader data=source.DM_TRT_PATIENT_PDF nowd style(report)=[rules=none frame=void];
		run; 
		
	/*Saut de page*/
	ods pdf STARTPAGE=now;
	ods pdf text='^S={FONT_SIZE=14pt FONTWEIGHT=bold} Signes vitaux';
	ods pdf text=' ';
	    DATA source.vital_signs_X;  
	        set source.vs_dm;
	        if usubjid = "&idPatient."
	        then output;
        Run;

        proc sort data = source.vital_signs_X;
        	by visdt;
        run;
        
        proc report data=source.vital_signs_X nowd;
            column VISDESC TEMP HRT SYS DIA Tension;
            define VISDESC / "Nom de Visite(trié par date)" ;
            define TEMP / display "Temperature (Celsius)";
            define HRT / display "Rythme Cardiaque" WIDTH= 0;
            define SYS / display "Tension Systolique(mmHg)" ;
            define DIA / display "Tension Diastolique(mmHg)";
            define tension / display "Diagnostique tension";
         run;
         
	/*Saut de page*/
	ods pdf STARTPAGE=now;
	ods pdf text='^S={FONT_SIZE=14pt FONTWEIGHT=bold} Mini Mental Test';
	ods pdf text=' ';
		 /*pour le score à chaque visite*/
         DATA source.mmse_pq_s_X;
            set source.mmse_pq_s;
            if usubjid = "&idPatient."
            then output;
         Run;

    	 /*pour l'évolution à chaque visite *(le graphique)*/
         data source.MMSE_SCORE_temp;
            set source.MMSE_SCORE;
            if usubjid = "&idPatient." then output;
         run;

         DATA source.temp_pdf;
            SET source.MMSE_SCORE_temp;
            num_visit = input(Visite,Best12.);
            DROP Visite; 
         RUN;

         PROC SORT DATA = source.temp_pdf;
             BY num_visit;
         RUN;
        
         proc report data=source.mmse_pq_s_X nowd;
            column label_de_la_question visit_1 visit_2 visit_13 visit_17 visit_20 visit_ed;
            define label_de_la_question / "Question";
         run; 

         PROC SGPLOT DATA=source.temp_pdf;
            series x=num_visit y=score_total;
         run;
         
	/*Saut de page*/
	ods pdf STARTPAGE=now;
	ods pdf text='^S={FONT_SIZE=14pt FONTWEIGHT=bold} Evènements indésirables';
	ods pdf text=' ';
		/*On récupère les colonnes utiles pour cette partie*/
		DATA source.ae_patient;
		SET source.adverse_event (WHERE=(USUBJID="&idPatient."));
		KEEP usubjid socterm aeterm aestdtdd aestdtmo aestdtyy aestdt aeendtdd aeendtmo aeendtyy aeendt aesev; 
		RUN;
		
		/*On créer les nouvelles variables de fin et de début d'ae*/
		DATA source.ae_patient;
		SET source.ae_patient;
		ATTRIB ae_start
		    LABEL="Date de début"
		    LENGTH=$15.
		    FORMAT=$15.;
		/*Si il nous manque une info sur la date de début on dit qu'elle est inconnue*/
		if (missing(AESTDTDD) OR missing(AESTDTMO))
		then ae_start = "UNK";
		/*Sinon on prends la date de début et on la caste en chaine de caractère*/
		else ae_start = PUT(AESTDT,DDMMYY10.);
		ATTRIB ae_stop
		    LABEL="Date de fin"
		    LENGTH=$15.
		    FORMAT=$15.;
		/*Si il nous manque une info sur la date de fin on dit qu'elle est inconnue*/
		if ((missing(AEENDTDD) OR missing(AEENDTMO)) AND ^missing(AEENDTYY))
		then ae_stop = "UNK";
		/*Si il nous manque la date entière (pour une autre raison que le cas précédent) 
		c'est que l'ae n'est pas finie*/
		else if (missing (AEENDT))
		then ae_stop = "En cours";
		/*Sinon on prends la date de fin et on la caste en chaine de caractère*/
		else ae_stop = PUT(AEENDT,DDMMYY10.);
		RUN;
		
		/*Report permet un affichage plus poussé que print*/
		PROC REPORT DATA=source.ae_patient;
		/*On séléctionne les colonnes à afficher*/
		column socterm aeterm ae_start ae_stop aesev;
		/*On redéfinit certains labels */
		define socterm / 
			display 'SOC Term' 
			/*et on choisit d'ordonner par socterm pour eviter les répétitions*/
			order 
			order=internal;
		define aeterm/ display 'AE Term';
		define aesev/ display 'Sévérité';
		RUN;
		
	ods pdf close;
%mend pdf;

/*On lis chaque ligne du tableau de patient 
pour récuperer leur id et leur générer un pdf*/
%macro bouclePatient;
	/*i le compteur d'itération déjà faite*/
	%LET i = 1;
	/*id la variable où l'on stocke l'usubjid du patient*/
	%LET id = 0;
	/*On creer une macro variable pour chaque id de patient (id1, id2...)*/
	DATA _NULL_ ;
	SET source.Patient ;
	CALL SYMPUTX(CATS("id",_N_), usubjid) ;
	RUN;
	/*Tant qu'on a pas fait un pdf pour chacun des 5 patients*/
	%do %while (&i.<=5); 
		/*On assigne à idP une des macro variable (id1,id2...)*/
	    %LET idP = &&id&i.;
	    /*On appel le code macro qui génère le pdf pour l'idP courrant*/
	    %pdf(&idP.);
	   	RUN;
		/*On incrémente i*/
		%LET i=%eval(&i.+1);
	%end;
%mend bouclePatient;

%bouclePatient;
