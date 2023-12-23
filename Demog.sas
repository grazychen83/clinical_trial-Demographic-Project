/*Import the raw data*/
filename  ref '/home/u63294231/sasuser.v94/Clinical Trial Demog project/project+-+demog.xlsx' ;
proc import datafile= ref
		dbms=xlsx          out=DEMOG replace;
	getnames=yes;
run;

/*Summary stats for age*/
data DEMOG1;
	set DEMOG;
	format dob1 date9.;

	/*creating a new variable for date of birth*/
	dob=compress(cat(month, '/', day, '/', year));
	dob1=input(dob, mmddyy10.);

	/*calculating the age of patients*/
	age=(diagdt-dob1)/365;
	output;
	trt=2;
	output;
run;

/*Evaluating the statistical parameters for age (continuous)*/
proc sort data=demog1;
	by trt;
run;

proc means DATA=DEMOG1 noprint;
	VAR age;
	output out=agestat;
	by trt;
run;

data agestat;
	length value $10. _stat_ $50.;
	set agestat;
	ord=1;

	if _stat_='N' then
		do;
			subord=1;
			value=strip(put(age, 8.));
		end;
	else if _stat_='MEAN' then
		do;
			subord=2;
			value=strip(put(age, 8.1));
			_stat_='Mean';
		end;
	else if _stat_='STD' then
		do;
			subord=3;
			value=strip(put(age, 8.2));
			_stat_='Standard Deviation';
		end;
	else if _stat_='MIN' then
		do;
			subord=4;
			value=strip(put(age, 8.1));
			_stat_='Minimum';
		end;
	else if _stat_='MAX' then
		do;
			subord=5;
			value=strip(put(age, 8.1));
			_stat_='Maximum';
		end;
	rename _stat_=stat;
	drop _type_ _freq_ age;
run;

/*Evaluating the  statistical parameters for age group  */
proc format;
	value agegrp low-18='<=18 years' 18-65='18-65 years' 65-high='>65 years';

data demog4;
	set demog1;
	agegroup=put(age, agegrp.);
run;

proc freq data=demog4 noprint;
	table trt*agegroup/ outpct out=agegroup;
run;

data agegroup;
	set agegroup;
	value=cat(count, ' (', strip(put(round(PCT_ROW, .1) , 8.1)), '%)');
	ord=2;

	if agegroup='<=18 years' then
		subord=1;
	else if agegroup='18-65 years' then
		subord=2;
	else if agegroup='>65 years' then
		subord=3;
	rename agegroup=stat;
	drop count percent pct_col pct_row;
run;

/*Create derive dataset gender*/
proc format;
	value genfmt 1='Male' 2='Female';
run;

data demog2;
	set demog1;
	sex=put(gender, genfmt.);
run;

/*use outpct to show all the percentage*/
proc freq data=demog2 noprint;
	table trt*sex / outpct out=genderstat;
run;

data genderstat;
	set genderstat;
	ord=3;
	value=cat(count, ' (', strip(put(round(pct_row, .1), 8.1)), '%)');

	if sex='male' then
		subord=1;
	else
		subord=2;
	rename sex=stat;
	drop count percent pct_row pct_col;
run;

/*obtain derived paramenters for race*/
proc format;
	value racefmt 1='White' 2='African American' 3='Hispanic' 4='Asian' 5='Other';
run;

data demog3;
	set demog2;
	racec=put(race, racefmt.);
run;

/*use outpct to show all the percentage*/
proc freq data=demog3 noprint;
	table trt*racec / outpct out=racestat;
run;


data racestat;
	set racestat;
	ord=4;

	if racec='Asian' then
		subord=1;
	else if racec='African American' then
		subord=2;
	else if racec='Hispanic' then
		subord=3;
	else if racec='White' then
		subord=4;
	else if racec='Other' then
		subord=5;
	value=cat(count,' (',strip(put(round(pct_row,.1),8.1)), '%)');
	rename racec=stat;
	drop count percent pct_row pct_col;
run;

/*appending all stats together*/
data allstat;
	length stat $50.;
	set agestat agegroup genderstat racestat;
run;

/*transposing data by treatment groups*/
proc sort data=allstat;
	by ord subord stat;
run;

proc transpose data=allstat out=t_allstats prefix=_;
	var value;
	id trt;
	by ord subord stat;
run;

data final;
	length stat $50.;
	set t_allstats;
	by ord subord;
	output;

	if first.ord then
		do;

			if ord=1 then
				stat='Age (years)';

			if ord=2 then
				stat='Age Group';

			if ord=3 then
				stat='Gender';

			if ord=4 then
				stat='Race';
			subord=0;
			_0='';
			_1='';
			_2='';
			output;
		end;

proc sort data=final;
	by ord subord;
run;

proc sql noprint;
	select count(*) into :placebo from DEMOG1 where trt=0;
	select count(*) into :active from DEMOG1 where trt=1;
	select count(*) into :total from DEMOG1 where trt=2;
quit;
/*removing the leading space in each macro variable*/
%let placebo=&placebo;
%let active=&active;
%let total=&total;


/*constructing the final report*/
title 'Table 1.1';
title2 'Demographic and Baseline Characteristics by Treatment Group';
title3 'Randomized Population';
footnote 'Note: Percentages are based on the number of non-missing values in each treatment group.';

proc report data=final split='|';
	columns ord subord stat _0 _1 _2;
	define ord/noprint order;
	define subord/ noprint order;
	define stat / display width=50 "";
	define _0 /display width=30 "Placebo | (N=&placebo)";
	define _1 /display width=30 "Active Treatment | (N=&active)";
	define _2 /display width=30 "All Patients | (N=&total)";
run;
