libname decode "/folders/myfolders/MiniProjet/sources/groupe4/format/";
libname source "/folders/myfolders/MiniProjet/sources/groupe4/";
options fmtsearch = (decode SOURCE WORK);
options ls = 256;

/* -------------------- 1 description des datasets -----------------------*/
%INCLUDE '/folders/myfolders/MiniProjet/1_Desc_tables.sas';

/* -------------------- 2.1 Demographie -----------------------*/
%INCLUDE '/folders/myfolders/MiniProjet/2.1_Demographie.sas';

/* -------------------- 2.2 Examen physique -----------------------*/
%INCLUDE '/folders/myfolders/MiniProjet/2.2_Examen_physique.sas';

/* -------------------- 2.3 Signes vitaux -----------------------*/
%INCLUDE '/folders/myfolders/MiniProjet/2.3_Signes_vitaux.sas';

/* -------------------- 2.4 Test cognitifs -----------------------*/
%INCLUDE '/folders/myfolders/MiniProjet/2.4_Test_cognitifs.sas';

/* -------------------- 2.5 Evenements indesirables -----------------------*/
%INCLUDE '/folders/myfolders/MiniProjet/2.5_Evenements_indesirables.sas';

/* -------------------- 3 Reporting -----------------------*/
%INCLUDE '/folders/myfolders/MiniProjet/3_Reporting.sas';

