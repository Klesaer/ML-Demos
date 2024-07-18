/*  kill command */
proc datasets library=work kill nolist;
quit;

/*  import datasets */

FILENAME REFFILE DISK '/homedir/demo98/casuser/default of credit card clients.xls'; /*change path */

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLS
	OUT=WORK.CreditDemo;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.CreditDemo; RUN;

/* with python */
/* load data with python dataframe. */
proc python;
submit;

import pandas as pd

df_raw = pd.read_csv(r"/homedir/demo98/casuser/default of credit card clients.csv")

print(df_raw.head(5))

SAS.df2sd(df_raw, 'work.CreditDemo_sas')

endsubmit;
quit;

/* load this table to cas */
cas conn;

proc casutil;
	droptable casdata='creditdemo' incaslib="casuser" quiet;
	load data=work.creditdemo casout='creditdemo' outcaslib='casuser' promote;
	list tables;
quit;

cas conn terminate;

/* Samething with python */
proc python;
submit;

loadtoCas = '''
cas conn;
proc casutil;
	droptable casdata='creditdemo' incaslib="casuser" quiet;
	load data=work.creditdemo casout='creditdemo' outcaslib='casuser' promote;
	list tables;
quit;
cas conn terminate;
'''
SAS.submit(loadtoCas)

endsubmit;
quit;

cas data_prep;

proc format casfmtlib='creditdemo' sessref=data_prep;
	value $fbi
	'X2' = 'Gender:1=male;2=Female'
	'X3' = 'Education (1 = graduate school; 2 = university; 3 = high school; 4 = others)';
run;

ods graphics / width=5in antialiasmax=5600;
proc sgplot data=work.creditdemo;
  title "Overall Default Cases";
  vbar y;
run;

proc sgplot data=work.creditdemo;
    title "Default Cases in Gender";
	vbar x2 / response=y;    
run;

cas data_prep terminate;

/* data partition with developing data 70% and validation data 30% */
proc partition data=casuser.creditdemo partind seed=12345 samppct=30;
	target y;
	output out=casuser.cdatasets copyvars=(_all_);
run;

proc sql;
	select _PartInd1_, sum(Y) as defaults, count(Y) as Obs from casuser.cdatasets
	group by _PartInd1_
;quit;

/* Macro variables for ML models */
%let dset=casuser.cdatasets;
%let outdir=~;
%let target=y;
%let nom_input=x2 x3 x4 x5;
%let int_input=x6-x23;


/* creating a decision tree */
proc treesplit data=&dset. minleafsize=5 outmodel=casuser.model_treesplit;
    target &target. /level=nominal;
    input &nom_input. /level=nominal;
    input &int_input. /level=interval;
    partition rolevar=_PartInd1_(train='0' validate='1');
    output out=casuser.ap_scored_treesplit copyvars=(_PartInd1_ &target);
    title "Decision Tree";
run;

/* using logistic regression. */

proc logselect data=&dset. noclprint;
   class &target. &nom_input.;
   model &target.(event='1') = &nom_input. &int_input.;
   selection method=stepwise (choose=validate) ;
   partition rolevar=_PartInd1_(train='0' validate='1');
   code file="&outdir./casuser/logselect1.sas";
   title "Logistic Regression";
run;

/* The SAS log can include notes for operations on missing values. */
data casuser.ap_scored_logistic;
   set &dset.;
   %include "&outdir./casuser/logselect1.sas";
   p_&target.1=p_&target.;
   p_&target.0=1-p_&target.;
run;











