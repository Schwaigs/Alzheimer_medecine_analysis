/* -------------------- 2.2.1 Calcul de l'IMC -----------------------*/

/*Pour chaque patient seule une visite nous donne sa taille 
et plusieurs nous donnent son poids*/

/*On extrait donc la taille pour la liée à chaque mesure de poids*/
DATA source.physical_exam_taille;
SET source.physical_exam;
/*On garde l'identifiant des patient et leur taille 
uniquement si la taille est belle est bien renseignée*/
KEEP usubjid HGT; 
IF (^missing(HGT)) 
then output;
RUN;

/*Puis on la trie par patient*/
PROC SORT 
DATA =source.physical_exam_taille;
BY usubjid;
RUN;

/*On enlève la taille de la table 
pour ne l'avoir qu'une fois lors de la fusion */
DATA source.physical_exam_sans_taille;
SET source.physical_exam;
DROP HGT;
RUN;

/*De même on la trie par patient pour avoir 
le meme ordre que la table contenant les tailles*/
PROC SORT
DATA =source.physical_exam_sans_taille; 
BY usubjid;
RUN;

/* Puis on fusionne les deux tables afin de faire correspondre la taille
avec chaque mesure de poids que l'on possède par patient*/
DATA source.physical_exam_taille_poids;
MERGE source.physical_exam_sans_taille (IN=mark1) 
	  source.physical_exam_taille (IN=mark2);
BY usubjid;
if mark1 
then output;
RUN;

/*Enfin on calcul l'imc des patient pour chaque visite médicale*/
DATA source.physical_exam_imc;
set source.physical_exam_taille_poids;
ATTRIB IMC
	LABEL="IMC";
if (WGT > 200)
then WGT = (WGT/35.2739619);
IMC = round(WGT/((HGT/100)**2),0.01);
if (^missing(HGT) AND ^missing(WGT)) 
then output;
RUN;



/* -------------------- 2.2.2 Fusion physicam_exam, date_of_visit et DM_TRT -----------------------*/
/*On trie les 3 tables*/
PROC SORT 
DATA =source.physical_exam_imc;
BY usubjid visid;
RUN;

PROC SORT 
DATA =source.date_of_visit;
BY usubjid visid;
RUN;

PROC SORT 
DATA =source.DM_TRT;
BY usubjid visid;
RUN;


/*On fusionnes les 3 tables*/
/*Dans un premier temp on fusionne physical_exam et date_of_visit 
afin de faire correspondre une date à chaque visite 
ayant donner lieu à un examen physique */
DATA source.phyExam_dateVisit;
MERGE source.physical_exam_imc (IN=mark1) 
	  source.date_of_visit (IN=mark2);
BY usubjid visid;
if mark1
then output;
RUN;

PROC SORT 
DATA =source.phyExam_dateVisit;
BY usubjid visid;
RUN;

/*Puis on fusionne phyExam_dateVisit et DM_TRT 
afin de faire correspondre à chaque visite medicale
les informations sur le patient et son groupe de traitement */
DATA source.PE;
MERGE source.phyExam_dateVisit (IN=mark1) 
	  source.DM_TRT (IN=mark2);
BY usubjid;
if mark1
then output;
RUN;



/* -------------------- 2.2.3 Création de PE_Last_Visit et analyse graphique de l'imc -----------------------*/

/*Creation de PE_Last_Visit*/

/*On trie par patient et par ordre decroissant de date de visite*/
PROC SORT DATA=source.PE nodupkey;
BY usubjid descending visdt;
RUN;

/*Puis on ne garde que la première ligne en eliminant les doublons par patient
Et on stocke cela dans une nouvelle table PE_Last_Visit
La visdt est donc la date de dernère visite*/
PROC SORT DATA=source.PE
Out=source.PE_Last_Visit nodupkey;
BY usubjid;
RUN;

/*A) IMC moyen par groupes de traitement*/
/*L'option mean permet d'obtenir la moyenne*/
PROC MEANS DATA=source.PE_Last_Visit mean;
class trtcd;
var imc;
RUN;
/*Affichage sous forme de boites à moustaches*/
PROC SGPLOT DATA=source.PE_Last_Visit;
Hbox imc /Category=trtcd;
Title "IMC par groupe de traitement";
RUN;

/*B) Test d'égalité d'IMC avec ANOVA*/
Proc anova data=source.PE_Last_Visit;
	class trtcd;
	model imc=trtcd;
RUN;
/* 
Precisez les hypothèses du test et les verifications a faire pour l'utiliser.
	On a pour hypothèse H0 que l'imc de chaque groupe est égal,
 	c'est-à-dire qu'il n'est pas influencé par le traitement.
 	On prends pour valeur de rejet 5%. 
 	Donc si l'air obtenue avec la p-valeur est inférieure à 0.05 on rejète H0.
Réalisez le test et tirez des conclusions.
	Avec la procedure Anova on obtient une aire de 0.5523,
	donc on ne rejète pas H0.
*/


/* -------------------- 2.2.4 Analyse descriptive de PE -----------------------*/
/*On analysera les variables poids et tailles*/

/* Analyse par rapport à tout les patients (minimum, maximum et moyenne) */
/*Poids*/
Proc Means data=source.PE max min mean;
var wgt;
title "Poids par rapport à tout les patients";
RUN;

/*Taille*/
Proc Means data=source.PE max min mean;
var hgt;
title "Taille par rapport à tout les patients";
RUN;
/* Commentaire du resultat : 
On observe une grande disparité les maximum et minimum pour les deux variables.
Toutefois, si l'on regarde les moyennes il s'agit de résultats que 
l'on peut s'attendre facilement à obtenir.*/

/* Analyse par rapport au sexe (minimum, maximum et moyenne) */
/*Poids*/
Proc Means data=source.PE max min mean;
var wgt;
class sex;
title "Poids par rapport au sexe";
RUN;

/*Taille*/
Proc Means data=source.PE max min mean;
var hgt;
class sex;
title "Taille par rapport au sexe";
RUN;
/* Commentaire du resultat : 
De la même manière que pour l'analyse précédante,
on observe un très grand écart entre les maximum et minimum pour les deux variables.
Toutefois, on observe de grandes disparités entre hommes et femmes ce qui permet de nuancer ces écarts, 
ceux-ci étants moins grands car les bornes n'appartienent pas au même sexe.*/


/* Analyse par rapport au groupe de traitement 
Affichage sous forme de boites à moustaches */
/*Poids*/
PROC SGPLOT DATA=source.PE;
Hbox wgt /Category=trtcd;
Title "Poids par groupe de traitement";
RUN;
/* Commentaire du resultat : 
Les moyennes du poids par groupes de traitement sont très 
proches les unes des autres. Cependant, on observe des disparités
au niveau des maximum et minimum. Les groupe 1 et 2 sont assez semblables
car ils ont les mêmes ordres de grandeurs, avec tout deux une grande différence 
entre le minimum et le maximum.
Le groupe 3 lui connait une plus peite difference entre ses patient ayant 
le poids minimum et maximum.*/


/*Taille*/
PROC SGPLOT DATA=source.PE;
Hbox hgt /Category=trtcd;
Title "Taille par groupe de traitement";
RUN;
/* Commentaire du resultat : 
Les moyennes de la taille par groupes de traitement sont très 
proches pour les groupe 1 et 2, celle du 3 est plus faible.
Pour ce qui est des maximum et minimum on observe de grandes différences. 
Le groupe 3 est, comme pour le poids, le groupe avec la plus petite 
différence entre les deux extrêmes.*/