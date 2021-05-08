/* -------------------- 2.5.1 Création variables ae_start_date - ae_stop_date et restriction -----------------------*/
/*création ae_start_date et ae_stop_date*/

DATA source.ae_update;
set source.adverse_event;
ATTRIB ae_start_date
    LABEL="AE_Start_Date"
    LENGTH=8
    FORMAT=DATE9.;
if (^missing(AESTDT))
then ae_start_date = AESTDT;
else if (missing(AESTDT))
then
    if (^missing(AESTDTYY) AND ^missing(AESTDTMO))
    then ae_start_date = input(Cat(01,AESTDTMO,AESTDTYY),DATE9.);
    else if (^missing(AESTDTYY))
    then ae_start_date = mdy(01,01,AESTDTYY);
;
ATTRIB ae_stop_date
    LABEL="AE_Stop_Date"
    LENGTH=8
    FORMAT=DATE9.;
if (^missing(AEENDT))
then ae_stop_date = AEENDT;
else if (missing(AEENDT))
then
    if (^missing(AEENDTYY) AND ^missing(AEENDTMO))
    then ae_stop_date = input(Cat(31,AEENDTMO,AEENDTYY),DATE9.);
    else if (^missing(AEENDTYY))
    then ae_stop_date = mdy(12,31,AEENDTYY);
;
RUN;

/*Exclusions et remplacements*/
/*On trie par patient et par ordre croissant de date de visite*/
PROC SORT DATA=source.date_of_visit;
BY usubjid visdt;
RUN;

/*Puis on ne garde que la première ligne en eliminant les doublons par patient
Et on stocke cela dans une nouvelle table Date_First_Visit
La visdt est donc la date de première visite*/
PROC SORT DATA=source.date_of_visit
Out=source.Date_First_Visit nodupkey;
BY usubjid;
RUN;

/*Pour limiter le nombre de colonnes qui ne serviront pas 
on ne garde que la date de 1e visite et le code patient*/
DATA source.Date_First_Visit;
SET source.Date_First_Visit (rename=(visdt=visdt_first));
KEEP usubjid visdt_first;
RUN;

/*On fusionne nos deux tables pour rajouter la date de première visite 
afin d'exclure les AE s'étant terminées avant la prise du traitement*/
DATA source.ae_first_visit;
MERGE source.ae_update (IN=mark1) 
      source.Date_First_Visit (IN=mark2);
BY usubjid;
if mark1
then do;
    /*Si l'ae a commencée après la 1e visite et qu'elle continue ensuite 
    alors on ne change rien et on garde la ligne*/
    if (((ae_stop_date > visdt_first) or (missing(ae_stop_date))) and (ae_start_date > visdt_first))
    then output;
    /*Si l'ae a commencée avant la 1e visite et qu'elle continue ensuite
    ou que l'on ne connait pas la date de début de l'ae et que l'on sait qu'elle s'est fini pendant le traitement
    alors la date de debut d'ae devient la date de 1e visite et on garde la ligne*/
    else if (((ae_stop_date > visdt_first)  or (missing(ae_stop_date))) and (ae_start_date < visdt_first)
    		or ((missing(ae_start_date)) and (ae_stop_date > visdt_first)))
    then do;
        ae_start_date = visdt_first;
        output;
        end;
/*Dans tout les autres cas on ne garde pas la ligne*/
end;
RUN;


/* -------------------- 2.5.2 Fusion adverse_event et traitement -----------------------*/

/*On trie par patient et par ordre decroissant de date de visite*/
PROC SORT DATA=source.date_of_visit;
BY usubjid descending visdt;
RUN;

/*Puis on ne garde que la première ligne en eliminant les doublons par patient
Et on stocke cela dans une nouvelle table Date_Last_Visit
La visdt est donc la date de dernière visite*/
PROC SORT DATA=source.date_of_visit
Out=source.Date_Last_Visit nodupkey;
BY usubjid;
RUN;

/*Pour limiter le nombre de colonnes qui ne serviront pas 
on ne garde que la date de dernière visite et le code patient*/
DATA source.Date_Last_Visit;
SET source.Date_Last_Visit (rename=(visdt=visdt_last));
KEEP usubjid visdt_last;
RUN;

/*Pour limiter le nombre de colonnes qui ne serviront pas 
on ne garde que le groupe de traitement, sa date d'assignation et le code patient*/
DATA source.ta_grp_date;
SET source.treatment_assignment;
KEEP usubjid trtcd asgndttm;
RUN;

/*Enfin on fusionne nos 3 tables pour créer AE*/
DATA source.AE;
MERGE source.ae_First_Visit (IN=mark1)
      source.Date_Last_Visit (IN=mark2)
      source.ta_grp_date (IN=mark3);
BY usubjid;
if mark1
then do;
    /*Si la date de fin d'ae n'est pas renseignée et
    alors on à la date de fin donne la valeur de la dernière visite du patient*/
    if (missing(ae_stop_date))
    then do;
       ae_stop_date = visdt_last;
    end;
    /*la dernière visite à lieu après le début de l'ae*/
    if (ae_stop_date >= ae_start_date)
    then output;
end;
RUN;


/* -------------------- 2.5.3 Representation graphique de chaque AE -----------------------*/

/*On supprime les AE n'ayant pas de sévérité*/
DATA source.AE;
SET source.AE;
if (^missing(AESEV))
then output;
RUN;

TITLE "Représentation graphique des AE des patients du groupe 1";
PROC SGPLOT DATA=source.AE (WHERE=(trtcd="1"));
/*On choisit le type highlow pour représenter chaque AE par une barre différente*/
/*En abscisse on trouve le temps d'étude, 
    début = date de la 1ere visite de l'étude
    fin = date de la dernière visite de l'étude
 En ordonnée on trouve les différents patients*/
highlow y=USUBJID low=ae_start_date high=ae_stop_date /
    /*Une distinction des AE est faite selon la sévérité*/
    name='Sévérité'
    group=AESEV
    /*Affichage de type bar permet de jouer sur l'épaisseur du trait*/
    type=bar
    barwidth=0.75
    /*Option cluster pour que chaque sévérité d'AE soit sur un axe différent 
    afin que les ae de sevérité différentes d'un même patient ne se supperposent pas*/
    groupdisplay=cluster;    
/*Titres des axes du graphique*/
yaxis label="ID du patient";
xaxis label="Temps de réalisation de l'étude";
yaxis grid;
/*Légende du graphique*/
keylegend 'Sévérité' / 
    title='Niveaux de sévérite'
    sortorder = ascending;
/*Définition générale du graphique*/
ods graphics on / 
    width=7.5in 
    height=7.5in ;
RUN;


TITLE "Représentation graphique des AE des patients du groupe 2";
PROC SGPLOT DATA=source.AE (WHERE=(trtcd="2"));
/*On choisit le type highlow pour représenter chaque AE par une barre différente*/
/*En abscisse on trouve le temps d'étude, 
    début = date de la 1ere visite de l'étude
    fin = date de la dernière visite de l'étude
 En ordonnée on trouve les différents patients*/
highlow y=USUBJID low=ae_start_date high=ae_stop_date /
    /*Une distinction des AE est faite selon la sévérité*/
    name='Sévérité'
    group=AESEV
    /*Affichage de type bar permet de jouer sur l'épaisseur du trait*/
    type=bar
    barwidth=0.75
    /*Option cluster pour que chaque sévérité d'AE soit sur un axe différent 
    afin que les ae de sevérité différentes d'un même patient ne se supperposent pas*/
    groupdisplay=cluster;    
/*Titres des axes du graphique*/
yaxis label="ID du patient";
xaxis label="Temps de réalisation de l'étude";
yaxis grid;
/*Légende du graphique*/
keylegend 'Sévérité' / 
    title='Niveaux de sévérite'
    sortorder = ascending;
/*Définition générale du graphique*/
ods graphics on / 
    width=7.5in 
    height=7.5in;
RUN;

TITLE "Représentation graphique des AE des patients du groupe 3";
PROC SGPLOT DATA=source.AE (WHERE=(trtcd="3"));
/*On choisit le type highlow pour représenter chaque AE par une barre différente*/
/*En abscisse on trouve le temps d'étude, 
    début = date de la 1ere visite de l'étude
    fin = date de la dernière visite de l'étude
 En ordonnée on trouve les différents patients*/
highlow y=USUBJID low=ae_start_date high=ae_stop_date /
    /*Une distinction des AE est faite selon la sévérité*/
    name='Sévérité'
    group=AESEV
    /*Affichage de type bar permet de jouer sur l'épaisseur du trait*/
    type=bar
    barwidth=0.75
    /*Option cluster pour que chaque sévérité d'AE soit sur un axe différent 
    afin que les ae de sevérité différentes d'un même patient ne se supperposent pas*/
    groupdisplay=cluster;    
/*Titres des axes du graphique*/
yaxis label="ID du patient";
xaxis label="Temps de réalisation de l'étude";
yaxis grid;
/*Légende du graphique*/
keylegend 'Sévérité' / 
    title='Niveaux de sévérite'
    sortorder = ascending;
/*Définition générale du graphique*/
ods graphics on / 
        width=7.5in 
        height=7.5in;
RUN;

/*Commentaire des graphiques :
Pour ce qui est du nombre d'AE en globalité le groupe deux semble être plus touché que les deux autres. 
On a notement beaucoup d'AE pour lequels la date de fin est celle de la dernière visite du patient, 
on peut donc imaginer qu'ils n'ont pas été résolus.
En terme de sévérité les groupes 2 et 3 semblent assez similaires. 
En effet, les patients du groupe 1 semblent avoir des AE plus sévères.
Au total il n'y a pas eu énormément d'AE classés sévères mais le groupe 3 est celui qui en compte le moins.*/



/* -------------------- 2.5.4 Ajouts d'icones sur le graphique -----------------------*/

/*On récupère la partie date du datetime d'assignement de traitement 
et on la place dans une nouvelle colonne*/
DATA source.AE;
SET source.AE;
ATTRIB ae_asgn_date
    LABEL="AE_ASGN_DATE"
    LENGTH=8
    FORMAT=DATE9.;
ae_asgn_date = DATEPART(asgndttm);
RUN;

TITLE "Représentation graphique des AE des patients du groupe 1 avec date de début de traitement et de dernière visite";
PROC SGPLOT DATA=source.AE (WHERE=(trtcd="1"));
/*On choisit le type highlow pour représenter chaque AE par une barre différente*/
/*En abscisse on trouve le temps d'étude, 
    début = date de la 1ere visite de l'étude
    fin = date de la dernière visite de l'étude
 En ordonnée on trouve les différents patients*/
highlow y=USUBJID low=ae_start_date high=ae_stop_date /
    /*Une distinction des AE est faite selon la sévérité*/
    name='Sévérité'
    group=AESEV
    /*Affichage de type bar permet de jouer sur l'épaisseur du trait*/
    type=bar
    barwidth=0.75
    /*Option cluster pour que chaque sévérité d'AE soit sur un axe différent 
    afin que les ae de sevérité différentes d'un même patient ne se supperposent pas*/
    groupdisplay=cluster;
/*Ajout des icones*/
symbolchar name=sym1 char=delta_u / textattrs=(Weight=Bold);
scatter x=ae_asgn_date y=usubjid/ name="asgn" markerattrs=(symbol=sym1 size=15pt);
scatter x=visdt_last y=usubjid /name="last";
/*Titres des axes du graphique*/
yaxis label="ID du patient";
xaxis label="Temps de réalisation de l'étude";
yaxis grid;
/*Légende du graphique*/
keylegend 'Sévérité' / 
    title='Niveaux de sévérite'
    sortorder = ascending
    position= bottom;
keylegend 'asgn' / 
    title='Date assignement du traitement'
    position=bottom;
keylegend 'last' / 
    title='Date de dernière visite'
    position=bottom;
/*Définition générale du graphique*/
ods graphics on / 
    width=7.5in 
    height=7.5in ;
RUN;


TITLE "Représentation graphique des AE des patients du groupe 2 avec date de début de traitement et de dernière visite";
PROC SGPLOT DATA=source.AE (WHERE=(trtcd="2"));
/*On choisit le type highlow pour représenter chaque AE par une barre différente*/
/*En abscisse on trouve le temps d'étude, 
    début = date de la 1ere visite de l'étude
    fin = date de la dernière visite de l'étude
 En ordonnée on trouve les différents patients*/
highlow y=USUBJID low=ae_start_date high=ae_stop_date /
    /*Une distinction des AE est faite selon la sévérité*/
    name='Sévérité'
    group=AESEV
    /*Affichage de type bar permet de jouer sur l'épaisseur du trait*/
    type=bar
    barwidth=0.75
    /*Option cluster pour que chaque sévérité d'AE soit sur un axe différent 
    afin que les ae de sevérité différentes d'un même patient ne se supperposent pas*/
    groupdisplay=cluster;
/*Ajout des icones*/
symbolchar name=sym1 char=delta_u/ textattrs=(Weight=Bold);
scatter x=ae_asgn_date y=usubjid/ name="asgn" markerattrs=(symbol=sym1 size=15pt);
scatter x=visdt_last y=usubjid /name="last";
/*Titres des axes du graphique*/
yaxis label="ID du patient";
xaxis label="Temps de réalisation de l'étude";
yaxis grid;
/*Légende du graphique*/
keylegend 'Sévérité' / 
    title='Niveaux de sévérite'
    sortorder = ascending
    position= bottom;
keylegend 'asgn' / 
    title='Date assignement du traitement'
    position=bottom;
keylegend 'last' / 
    title='Date de dernière visite'
    position=bottom;
/*Définition générale du graphique*/
ods graphics on / 
    width=7.5in 
    height=7.5in ;
RUN;


TITLE "Représentation graphique des AE des patients du groupe 3 avec date de début de traitement et de dernière visite";
PROC SGPLOT DATA=source.AE (WHERE=(trtcd="3"));
/*On choisit le type highlow pour représenter chaque AE par une barre différente*/
/*En abscisse on trouve le temps d'étude, 
    début = date de la 1ere visite de l'étude
    fin = date de la dernière visite de l'étude
 En ordonnée on trouve les différents patients*/
highlow y=USUBJID low=ae_start_date high=ae_stop_date /
    /*Une distinction des AE est faite selon la sévérité*/
    name='Sévérité'
    group=AESEV
    /*Affichage de type bar permet de jouer sur l'épaisseur du trait*/
    type=bar
    barwidth=0.75
    /*Option cluster pour que chaque sévérité d'AE soit sur un axe différent 
    afin que les ae de sevérité différentes d'un même patient ne se supperposent pas*/
    groupdisplay=cluster;
/*Ajout des icones*/
symbolchar name=sym1 char=delta_u/ textattrs=(Weight=Bold);
scatter x=ae_asgn_date y=usubjid/ name="asgn" markerattrs=(symbol=sym1 size=15pt);
scatter x=visdt_last y=usubjid /name="last";
/*Titres des axes du graphique*/
yaxis label="ID du patient";
xaxis label="Temps de réalisation de l'étude";
yaxis grid;
/*Légende du graphique*/
keylegend 'Sévérité' / 
    title='Niveaux de sévérite'
    sortorder = ascending
    position= bottom;
keylegend 'asgn' / 
    title='Date assignement du traitement'
    position=bottom;
keylegend 'last' / 
    title='Date de dernière visite'
    position=bottom;
/*Définition générale du graphique*/
ods graphics on / 
    width=7.5in 
    height=7.5in ;
RUN;


/* -------------------- 2.5.5 Tableau et représentation graphique des SOC -----------------------*/

/*On fais une analyse de la fréquence avec freq 
pour avoir les valeurs chiffrées en plus du graphique*/
PROC FREQ DATA=source.ae;
TABLE socterm*trtcd /
    /*On retire le pourcentage par ligne et colonne pour plus de lisibilité*/
    norow
    nocol;
RUN;

/*Representation graphique de la fréquence*/
TITLE "Représentation graphique de la fréquence des AE par groupe de traitement";
PROC SGPLOT DATA=source.ae;
VBAR socterm /
    name='socterm'
    /*L'axe des ordonnées sera le nombre d'AE à l'aide de stat=freq*/
    stat=freq
    /*Différenciation par goupe de traitement*/
    group=trtcd
    /*Chaque groupe aura une barre différente pour chaque type d'AE
    disposées les unes à cotés des autres*/
    groupdisplay=cluster;
/*Légende du graphique*/
keylegend 'socterm' / 
    title='Groupe de traitement'
    sortorder = ascending;
/*Définition générale du graphique*/
ods graphics on / 
    width=7.5in 
    height=7.5in;
RUN;

/*Commentaire du graphique :
Premièrement on observe que le nombre d'AE par type de SOC est hétérogène. 
Pour certain types il y a en cumulé entre 0 et 5 patients qui ont été touchés, 
pour d'autre cela se compte en plusieurs dizaines.
Pour ce qui est de l'analyse par groupe on constate que le groupe 2 
est celui pour lequel le nombre d'AE répertoriés est la plus élevé. 
Cependant, le groupe 2 est aussi celui dont le nombre de types d'AE différents 
par lesquels sont touchés les patients est le plus faible*/