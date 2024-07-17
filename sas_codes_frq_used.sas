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




