/* 2.1.1 format */
PROC FORMAT;
        VALUE ED_GROUP_sas 1="Niveau d'étude supérieur"
                                        2="Niveau d'étude secondaire";
RUN;

/* 2.1.1 */
DATA source.DM;
SET source.demography;
TITLE "Âge et niveau d'étude";

ATTRIB AGE_TODAY
LABEL="Âge en années"
LENGTH=3;
AGE_TODAY=year(today())-BIRTHDTYY;

ATTRIB ED_GROUP
LABEL="Niveau d'étude"
LENGTH = 8;
IF EDCCNT < 15 THEN
        ED_GROUP = 1 ;
ELSE ED_GROUP= 2 ;

format ED_GROUP ED_GROUP_sas.;

KEEP AGE_TODAY ED_GROUP USUBJID EDCCNT SEX;
PROC PRINT DATA=source.DM NOOBS label;
RUN;

/* 2.1.2 */

DATA  source.DM_TRT;
MERGE source.DM (IN=USUBJID1) source.treatment_assignment (IN=USUBJID2);
by  USUBJID ;
if USUBJID1 then
output;
RUN;

TITLE "Fusion";
PROC PRINT DATA=source.DM_TRT;
RUN;


/* 2.1.3 */
PROC MEANS DATA=source.DM_TRT MIN MAX MEAN STD VAR MEDIAN;
CLASS TRTCD;
VAR AGE_TODAY;
RUN;
