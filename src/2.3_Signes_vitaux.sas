/*2.3.1 Mise en place de la variable tension*/

Data source.Vital_Signs_calc;
set source.vital_signs;
sys_t = -1;
dia_t = -1;
array t{6} $40 ('Tension Optimale','Tension Normale','Hypertension Normale Elevée','Hypertension Légère','Hypertension Modérée','Hypertension Sévère');
attrib Tension label="Diagnostique tension" length= $40;
*On verifie la systolique;
if(SYS<120) then  sys_t = 1 ;
else if(120<=SYS<=129) then sys_t = 2 ;
else if(130<=SYS<=139) then sys_t = 3;
else if(140<=SYS<=159) then sys_t = 4;
else if(160<=SYS<=179) then sys_t = 5;
else sys_t = 6;

*On vérifie la diastolique;
if(DIA<80) then  dia_t = 1 ;
else if(80<=DIA<=84) then dia_t = 2 ;
else if(85<=DIA<=89) then dia_t = 3;
else if(90<=DIA<=99) then dia_t = 4;
else if(100<=DIA<=109) then dia_t = 5;
else dia_t = 6;
*On prend la valeurqui est la plus basse au cas où les 2 valeurs osnt en désaccord;
if(dia_t=-1 OR sys_t=-1)then tension =.;
if(dia_t>sys_t)then        tension = t{dia_t};
else tension=t{sys_t};
DATA source.Vital_Signs;
*on enleve les variables qu'on vuet pas dans le tableau;
SET source.Vital_Signs_calc(drop= sys_t dia_t t1 t2 t3 t4 t5 t6);

*2.3.2;
*table intermediare;
*on fusionne les 2 tableaux pour pouvoir avoir une date sur les diagnostiques de tension réalisés;
DATA source.VS_facultatif;
merge source.Vital_Signs (IN=mark1) source.date_of_visit (IN=mark2);
by usubjid visid;
if mark1 or mark2 then output;
RUN;

*On va mettre la valeur "Non calculé" sur les tensions qui 
n'ont pas été pris lors de certaines visites;
DATA source.VS;
set source.VS_facultatif;
if(SYS=. AND DIA =.)then tension = "Non calculé";
RUN;

*2.3.3;
*creation de VS_DM en fusionnant  VS et DM_TRT cela va nous permettre 
de regarder l'évolution de la tension en fonction du traitement que les individus suivent;
DATA source.VS_DM;
merge source.VS (IN=mark1) source.DM_TRT (IN=mark2);
by usubjid;
if mark1 or mark2 then output;
RUN;

*2.3.4;
*La fréquence des tensions en fonction du groupe de traitement;
PROC FREQ data = source.VS_DM;
table Tension*TRTCD;
RUN;

*2.3.5;
*Comparaison des moyennes des systoliques des patients.;
PROC ANOVA DATA = source.VS_DM;
CLASS TRTCD;
model SYS=TRTCD;
RUN;
*Comparaison des moyennes des diastoliques des patients.;
PROC ANOVA DATA = source.VS_DM;
CLASS TRTCD;
model DIA=TRTCD;
RUN;
*Comparaison des moyennes des tensions des patients;
PROC FREQ data = source.VS_DM;
table Tension*TRTCD/chisq;
RUN;