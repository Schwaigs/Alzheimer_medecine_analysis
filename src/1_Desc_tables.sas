/* -------------------- 1 Description des datasets fournis dans la lib source -----------------------*/
/*Content permet d'afficher les informations générales d'une table*/
PROC CONTENTS DATA=source.demography;
TITLE 'Description de demography';
RUN;

PROC CONTENTS DATA=source.physical_exam;
TITLE 'Description de physical_exam';
RUN;

PROC CONTENTS DATA=source.vital_signs;
TITLE 'Description de vital_signs';
RUN;

PROC CONTENTS DATA=source.date_of_visit;
TITLE 'Description de date_of_visit';
RUN;

PROC CONTENTS DATA=source.mmse_result;
TITLE 'Description de mmse_result';
RUN;

PROC CONTENTS DATA=source.adverse_event;
TITLE 'Description de adverse_event';
RUN;

PROC CONTENTS DATA=source.treatment_assignment;
TITLE 'Description de treatment_assignement';
RUN;