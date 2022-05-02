%LET job=final_project;
%LET onyen=aballou;
%LET outdir=/home/u60659721/assignments/final_project;

proc printto log="&outdir/&job._&onyen..log" new; run;

*********************************************************************
*  Assignment:    Final Projet                                       
*                                                                    
*  Description:   Analysis of 2019 CrossFit Open & Games data
*
*  Name:          Anna Ballou
*
*  Date:          4/27/22                                      
*------------------------------------------------------------------- 
*  Job name:      final_project_aballou.sas   
*
*  Purpose:       Data Analysis
*                                         
*  Language:      SAS, VERSION 9.4  
*
*  Input:         2019 open and games data
*
*  Output:        reports and visual analyses
*                                                                    
********************************************************************;

OPTIONS NODATE MPRINT MERGENOBY=WARN VARINITCHK=WARN NOFULLSTIMER;
*ODS _ALL_ CLOSE;
FOOTNOTE "Job &job._&onyen run on &sysdate at &systime";

LIBNAME FP "/home/u60659721/assignments/final_project";

/******** SET UP *********/

*read in open athlete information;
PROC IMPORT datafile = "/home/u60659721/assignments/final_project/subset_2019_open_athletes.csv"
	out = open_2019
    dbms = csv;
RUN;

*read in games athlete information;
PROC IMPORT datafile = "/home/u60659721/assignments/final_project/2019_games_athletes.csv"
	out = games_2019
	dbms = csv;
RUN;

*read in games scores;
PROC IMPORT datafile = "/home/u60659721/assignments/final_project/subset_2019_games_scores.csv"
	out = games_scores_2019
	dbms = csv;
RUN;

*read in games event information;
PROC IMPORT datafile = "/home/u60659721/assignments/final_project/games_2019_events.xlsx"
	out = games_2019_events
	dbms = xlsx;
RUN;

*link games scores with event details;
PROC SQL;
	CREATE TABLE work.games_2019_combined AS
		SELECT *
			FROM work.games_scores_2019 AS S, work.games_2019_events AS E
			WHERE S.ordinal = E.event;
QUIT;


/******** DATA WRANGLING: MEN *********/

*select only male Open competitors into new dataset;
PROC SQL;
	CREATE TABLE work.open_2019_men AS
		SELECT competitorid, competitorname, gender, countryoforiginname, age, height,
			(height*3.281) AS height_ft, weight, (weight*2.205) AS weight_lbs, 
			overallrank AS open_rank, overallscore AS open_score 
			/* derive new height & weight variables in ft./kg. */
			FROM work.open_2019
			WHERE division = "Men"
			ORDER BY overallrank;
QUIT; *note: 99 men;

*check coding of new height and weight variables;
PROC MEANS DATA = work.open_2019_men N NMISS MEAN MIN MAX;
	VARS height height_ft weight weight_lbs;
	TITLE "Check coding of new height and weight variables";
	TITLE2 "height_ft should be 3.281*height and weight_lbs should be 2.205*weight";
RUN;

*merge Open data with games athlete data;
PROC SQL;
	CREATE TABLE work.combined_2019_men AS
		SELECT O.competitorname, O.competitorid, O.gender, O.countryoforiginname, 
			O.age, O.height_ft, O.weight_lbs, O.open_rank, O.open_score,
			G.overallrank AS games_rank, G.overallscore AS games_score, G.status, G.bibid
				FROM work.open_2019_men AS O
					/* left join to keep only those men with data about the open */ 
					LEFT JOIN games_2019 AS G ON G.competitorid = O.competitorid
				ORDER BY open_rank;
QUIT;


*top 10 open finishers (analysis dataset for Top 10 Male finishers report);
PROC SQL;
	CREATE TABLE work.top_male_open AS	
		SELECT open_rank, competitorname, countryoforiginname, age, height_ft FORMAT = 5.2, 
			weight_lbs FORMAT = 6.2
			FROM work.combined_2019_men
			WHERE open_rank <= 10; *only want top 10;
QUIT;

*top 10 games finishers (next code chucks are looking at OPEN rank of top 10 GAMES finishers);
PROC SQL;
	CREATE TABLE work.best_games_men AS	
		SELECT O.competitorname, O.open_rank, O.games_rank, G.rank AS event_rank
		FROM work.combined_2019_men AS O, work.games_2019_combined AS G
		WHERE O.competitorID = G.competitorID AND
			.z < O.games_rank <= 10 ; *only want top 10 games finishers;
QUIT;

DATA work.best_games_men2;
	SET work.best_games_men;
	*set athletes who were cut or withdrew (WD) to missing so we can do numerical calcs;
	IF event_rank = "CUT" OR event_rank = "WD" OR event_rank = " " THEN event_rank = .;
	*only want the placing information, which is the 1st 2 characters;
	event_rank = SUBSTR(event_rank, 1, 2);
	*coerce to numeric;
	event_rank_num = input(event_rank, 8.);
RUN;

*Got a note about coercion, so proof that nothing is being "weirdly" coerced and all numeric
event_rank_num derivations are doing as intended with categorial event_rank;
PROC FREQ DATA = work.best_games_men2;
	TABLES event_rank*event_rank_num / LIST MISSING;
	TITLE "Checking charaction --> numeric coersion";
RUN;

*sort dataset by competitor name so we can run PROC MEANS for each competitor;
PROC SORT DATA = work.best_games_men2;
	BY competitorname;
RUN;

*get the mean event rank, open rank, and games rank for each competitor;
PROC MEANS DATA = work.best_games_men2 MEAN;
	TITLE "Mean event_rank, open rank and games rank for each athlete";
	*note: mean open_rank and games_rank aren't actually means 
	(each competitor has the same rank for all rows in the dataset, just forcing SAS to 
	report 1 number for easier use in creating the report);
	VARS open_rank games_rank event_rank_num; 
	BY competitorname;
	OUTPUT OUT = work.best_games_means
		MEAN = open_rank games_rank mean_event_finish;
RUN;

*order by ascending games_rank for report;
PROC SQL;
	CREATE TABLE work.best_games_men_ordered AS
		SELECT competitorname, open_rank, games_rank, mean_event_finish FORMAT = 4.1
			FROM work.best_games_means
			ORDER BY games_rank ASC;
QUIT;

*now, doing the reverse as above, looking at GAMES placement of top OPEN finishers (note: not
in presentation or paper, just for explorative purposes);
PROC SQL;
	CREATE TABLE work.best_open_men AS	
		SELECT O.competitorname, O.open_rank, O.games_rank, G.rank AS event_rank
		FROM work.combined_2019_men AS O, work.games_2019_combined AS G
		WHERE O.competitorID = G.competitorID AND
			.z < O.open_rank <= 10 ; *only want top 10 open finishers;
QUIT;

DATA work.best_open_men2;
	SET work.best_open_men;
	*set athletes who were cut or withdrew (WD) to missing so we can do numerical calcs;
	IF event_rank = "CUT" OR event_rank = "WD" OR event_rank = " " THEN event_rank = .;
	*only want the placing information, which is the 1st 2 characters;
	event_rank = SUBSTR(event_rank, 1, 2);
	*coerce to numeric;
	event_rank_num = input(event_rank, 8.);
RUN;

*Similar to above, got a note about coercion, so proof that nothing is being "weirdly" coerced and 
all numeric event_rank_num derivations are doing as intended with categorial event_rank;
PROC FREQ DATA = work.best_open_men2;
	TABLES event_rank*event_rank_num / LIST MISSING;
	TITLE "Checking character --> numeric coersion";
RUN;

*sort by competitorname so we can run proc means on each competitor;
PROC SORT DATA = work.best_open_men2;
	BY competitorname;
RUN;

*get mean open rank, games rank and event rank for each competitor;
PROC MEANS DATA = work.best_open_men2 MEAN;
	TITLE "Mean event rank, games rank and open rank for each athlete";
	*as above, open_rank and games_rank means aren't actual means;
	VARS open_rank games_rank event_rank_num;
	BY competitorname;
	OUTPUT OUT = work.best_open_men_means
		MEAN = open_rank games_rank mean_event_finish;
RUN;

*order by ascending games_rank;
PROC SQL;
	CREATE TABLE work.best_open_men_ordered AS
		SELECT competitorname, open_rank, games_rank, mean_event_finish FORMAT = 4.1
			FROM work.best_open_men_means
			ORDER BY games_rank ASC;
QUIT;


/******** DATA WRANGLING: WOMEN *********/

*select only female open competitors into new dataset;
PROC SQL;
	CREATE TABLE work.open_2019_women AS
		/* derive new height and weight vars that are in ft/kg */
		SELECT competitorid, competitorname, gender, countryoforiginname, age, height,
			(height*3.281) AS height_ft, (weight*2.205) AS weight_lbs, weight, 
			overallrank AS open_rank, overallscore AS open_score 
			FROM work.open_2019
			WHERE division = "Women" 
			ORDER BY overallrank;
QUIT; *note: 95 women;

*check coding of new height and weight variables;
PROC MEANS DATA = work.open_2019_women N NMISS MEAN MIN MAX;
	VARS height height_ft weight weight_lbs;
	TITLE "Check coding of new height and weight variables";
	TITLE2 "height_ft should be 3.281*height and weight_lbs should be 2.205*weight";
RUN;


*merge with games athlete data;
PROC SQL;
	CREATE TABLE work.combined_2019_women AS
		SELECT O.competitorname, O.competitorid, O.gender, O.countryoforiginname, 
			O.age, O.height_ft, O.weight_lbs, O.open_rank, O.open_score,
			G.overallrank AS games_rank, G.overallscore AS games_score, G.status, G.bibid
				FROM work.open_2019_women AS O
					/* left join to keep all men in open */ 
					LEFT JOIN games_2019 AS G ON G.competitorid = O.competitorid
				ORDER BY open_rank;
QUIT;


*top 10 open finishers (analysis dataset for Top 10 Female finishers report);
PROC SQL;
	CREATE TABLE work.top_female_open AS	
		SELECT open_rank, competitorname, countryoforiginname, age, height_ft FORMAT = 5.2, 
			weight_lbs FORMAT = 6.2
			FROM work.combined_2019_women
			WHERE open_rank <= 10; *only want top 10 finishers;
QUIT;

*top 10 games finishers (next code chucks are looking at OPEN rank of top 10 GAMES finishers);
PROC SQL;
	CREATE TABLE work.best_games_women AS	
		SELECT O.competitorname, O.open_rank, O.games_rank, G.rank AS event_rank
		FROM work.combined_2019_women AS O, work.games_2019_combined AS G
		WHERE O.competitorID = G.competitorID AND
			.z < O.games_rank <= 10; *only want top 10 games finishers;
QUIT;

DATA work.best_games_women2;
	SET work.best_games_women;
	*set athletes who were cut or withdrew (WD) to missing so we can do numerical calcs;
	IF event_rank = "CUT" OR event_rank = "WD" OR event_rank = " " THEN event_rank = .;
	*only want placing info which is in the 1st 2 characters;
	event_rank = SUBSTR(event_rank, 1, 2);
	*coerce to numeric;
	event_rank_num = input(event_rank, 8.);
RUN;

*Similar to with men, got a note about coercion, so proof that nothing is being "weirdly" coerced and 
all numeric event_rank_num derivations are doing as intended with categorial event_rank;
PROC FREQ DATA = work.best_games_women2;
	TABLES event_rank*event_rank_num / LIST MISSING;
	TITLE "Checking character --> numeric coersion";
RUN;

*sort by competitorname so we can calculate means for each athlete;
PROC SORT DATA = work.best_games_women2;
	BY competitorname;
RUN;

*get mean open rank, games rank and event rank;
PROC MEANS DATA = work.best_games_women2 MEAN;
	TITLE "Getting mean event rank, open rank and games rank for each athlete";
	VARS open_rank games_rank event_rank_num;
	BY competitorname;
	OUTPUT OUT = work.best_games_women_means
		MEAN = open_rank games_rank mean_event_finish;
RUN;

*sort by ascending games_rank;
PROC SQL;
	CREATE TABLE work.best_games_women_ordered AS
		SELECT competitorname, open_rank, games_rank, mean_event_finish FORMAT = 4.1
			FROM work.best_games_women_means
			ORDER BY games_rank ASC;
QUIT;

*now, doing the reverse as above, looking at GAMES placement of top OPEN finishers (note: not
in presentation or paper, just for explorative purposes); 
PROC SQL;
	CREATE TABLE work.best_open_women AS	
		SELECT O.competitorname, O.open_rank, O.games_rank, G.rank AS event_rank
		FROM work.combined_2019_women AS O, work.games_2019_combined AS G
		WHERE O.competitorID = G.competitorID AND
			.z < O.open_rank <= 10; *only want top 10 open finishers;
QUIT;

DATA work.best_open_women2;
	SET work.best_open_women;
	*set athletes who were cut or withdrew (WD) to missing so we can do numerical calcs;
	IF event_rank = "CUT" OR event_rank = "WD" OR event_rank = " " THEN event_rank = .;
	*only want placing info which is in the first 2 characters;	
	event_rank = SUBSTR(event_rank, 1, 2);
	*coerce to numeric;
	event_rank_num = input(event_rank, 8.);
RUN;

*Similar to with men, got a note about coercion, so proof that nothing is being "weirdly" coerced and 
all numeric event_rank_num derivations are doing as intended with categorial event_rank;
PROC FREQ DATA = work.best_open_women2;
	TABLES event_rank*event_rank_num / LIST MISSING;
	TITLE "Checking character --> numeric coercion";
RUN;

*sort by competitorname so we can get means for each athlete;
PROC SORT DATA = work.best_open_women2;
	BY competitorname;
RUN;

*get open_rank, games_rank and mean event_rank;
PROC MEANS DATA = work.best_open_women2 MEAN;
	TITLE "Getting mean event rank, games rank and open rank for each athlete";
	VARS open_rank games_rank event_rank_num;
	BY competitorname;
	OUTPUT OUT = work.best_open_women_means
		MEAN = open_rank games_rank mean_event_finish;
RUN;

*sort by ascending games_rank;
PROC SQL;
	CREATE TABLE work.best_open_women_ordered AS
		SELECT competitorname, open_rank, games_rank, mean_event_finish FORMAT = 4.1
			FROM work.best_open_women_means
			ORDER BY games_rank ASC;
QUIT;

/******** DATA WRANGLING: MACRO *********/

*create male and female combined open and games data;
PROC SQL;
	CREATE TABLE work.all_data AS
		SELECT O.competitorid, O.competitorname, O.gender, O.countryoforiginname, O.age,
			(O.height*3.281) AS height_ft, (O.weight*2.205) AS weight_lbs, O.overallrank AS open_rank,
			G.overallrank AS games_rank, O.overallscore AS open_score, G.overallscore AS games_score,
			E.Name AS event_name, E.event, E.rank AS event_rank
			FROM work.open_2019 AS O
				/* Left join to keep only those with data on the open */
				/* games_2019 has games score data */
				LEFT JOIN games_2019 AS G ON G.competitorid = O.competitorid
				/* games_2019_combined has event descriptive data */
				LEFT JOIN games_2019_combined AS E ON E.competitorid = O.competitorid;
QUIT; 

DATA work.all_data2;
	SET work.all_data;
	*set athletes who were cut or withdrew (WD) to missing so we can do numerical calcs;
	IF event_rank = "CUT" OR event_rank = "WD" OR event_rank = " " THEN event_rank = .;
	*only want event rank which is in the 1st 2 characters;
	event_rank = SUBSTR(event_rank, 1, 2);
	*coerce to numeric;
	event_rank_num = input(event_rank, 8.);
RUN;

*Similar to with men, got a note about coercion, so proof that nothing is being "weirdly" coerced and 
all numeric event_rank_num derivations are doing as intended with categorial event_rank;
PROC FREQ DATA = work.all_data2;
	TABLES event_rank*event_rank_num / LIST MISSING;
	TITLE "Checking character --> numeric coercion";
RUN;

/******** DATA WRANGLING: EVENT DESCRIPTIONS *********/

*data_input = name & library of input dataset;
*data_putput = desired name of generated output dataset;
%MACRO classify_events(data_input=, data_output=); 
	DATA &data_output;
	    SET &data_input;
	    /* common words associated with strength-based events */
	    IF find(Description, "clean", "i") ^= 0 THEN lifting = 1;
	    	ELSE IF find(Description, "snatch", "i") ^= 0 OR find(Description, "snatches", "i") ^= 0
	    		THEN lifting = 1;
	    	ELSE IF find(Description, "squats", "i") ^= 0 THEN lifting = 1;
	    	ELSE IF find(Description, "deadlift", "i") ^= 0 THEN lifting = 1;
	    	ELSE lifting = 0;
	    /* common words associated with cardiovascular-based events */
	    IF find(Description, "run", "i") ^= 0 THEN cardio = 1;
	    	ELSE IF find(Description, "swim", "i") ^= 0 THEN cardio = 1;
	    	ELSE IF find(Description, "paddle", "i") ^= 0 THEN cardio = 1;
	    	ELSE IF find(Description, "rucksack", "i") ^= 0 THEN cardio = 1;
	    	ELSE IF find(Description, "rowing", "i") ^= 0 OR find(Description, "row", "i") ^= 0 
	    		THEN cardio = 1;
	    	ELSE IF find(Description, "sprint", "i") ^= 0 THEN cardio = 1;
	    	ELSE IF find(Description, "bike", "i") ^= 0 THEN cardio = 1;
	    	ELSE IF find(Description, "burpees", "i") ^= 0  THEN cardio = 1;
	    	ELSE cardio = 0;
	    /* initialize a event_type variable that combines information gathered in above IF blocks */	
	    LENGTH event_type $ 15;
	    /* Mixed = doesn't fit any category completely */
	    IF (lifting = 1 & cardio = 1) OR (lifting = 0 & cardio = 0) THEN event_type = "Mixed";
	    	ELSE IF lifting = 1 & cardio = 0 THEN event_type = "Strength";
	    	ELSE IF lifting = 0 & cardio = 1 THEN event_type = "Cardiovascular";
	RUN;

%MEND;

*run classifying event macro on event dataset;
%classify_events(data_input = work.games_2019_events, data_output = work.event_type);

*check coding of event_type;
PROC FREQ DATA = work.event_type;
	TABLES lifting*cardio*event_type / LIST MISSING;
	TITLE "Checking coding of macro-generated lifting, cardio and event_type variables";
RUN;

DATA work.event_details;
	SET work.event_type;
	*create binary indicator variable for whether or not event occured during the 
	1st half of competition;
	IF Event <= 6 THEN first_half = 1;
		ELSE IF Event > 6 THEN first_half = 0;
	*add variable that includes No. athletes cut after each event;
	IF Event = 1 THEN num_cut = 45;
		ELSE IF Event = 2 THEN num_cut = 15;
		ELSE IF Event IN (3:6) THEN num_cut = 10;
		ELSE num_cut = 0;
RUN;

ODS PDF FILE="&outdir/&job._&onyen..PDF" STYLE=JOURNAL;

/******** REPORTS *********/

/* MEN demographic summary */
PROC MEANS DATA = work.combined_2019_men MIN MEAN MEDIAN MAX;
	TITLE "Characteristics of Male Competitors (Open, 2019)";
	VAR age height_ft weight_lbs;
	LABEL height_ft = "Height (ft.)";
	LABEL weight_lbs = "Weight (lbs.)";
RUN;

/* WOMEN demographic summary */
PROC MEANS DATA = work.combined_2019_women MIN MEAN MEDIAN MAX;
	TITLE "Characteristics of Female Competitors (Open, 2019)";
	VAR age height_ft weight_lbs;
	LABEL height_ft = "Height (ft.)";
	LABEL weight_lbs = "Weight (lbs.)";
RUN;

/* MEN finishes by Country */
*sort by countryoforigin so we can run PROC MEANS by country;
PROC SORT DATA = work.combined_2019_men OUT = work.combined_2019_men_sorted;
	BY countryoforiginname;
RUN;

*get minimum (i.e. best) finish for each country;
PROC MEANS DATA = work.combined_2019_men_sorted MIN NOPRINT;
	TITLE "Best Games Finish by Country (Men)";
	VAR games_rank;
	BY countryoforiginname;
	OUTPUT OUT = work.best_country_games_men
		MIN = / autoname;
RUN;

*re-sort by best finish;
PROC SORT DATA = work.best_country_games_men;
	BY games_rank_min;
RUN;

PROC PRINT DATA = work.best_country_games_men LABEL NOOBS;
	TITLE "Best Games Finish by Country (Men)";
	VAR countryoforiginname games_rank_min;
	LABEL countryoforiginname = "Country of Origin";
	LABEL games_rank_min = "Best Games Finish";
RUN;

 /* WOMEN Finishes by Country */
*sort by countryoforiginname so we can run proc means on each country;
PROC SORT DATA = work.combined_2019_women OUT = work.combined_2019_women_sorted;
	BY countryoforiginname;
RUN;

*get min (i.e. best) finish for each country;
PROC MEANS DATA = work.combined_2019_women_sorted MIN NOPRINT;
	TITLE "Best Games Finish by Country (Women)";
	VAR games_rank;
	BY countryoforiginname;
	WHERE games_rank NE .;
	OUTPUT OUT = work.best_country_games_women
		MIN = / autoname;
RUN;

*re-sort by best finish;
PROC SORT DATA = work.best_country_games_women;
	BY games_rank_min;
RUN;

PROC PRINT DATA = work.best_country_games_women LABEL NOOBS;
	TITLE "Best Games Finish by Country (Women)";
	VAR countryoforiginname games_rank_min;
	LABEL countryoforiginname = "Country of Origin";
	LABEL games_rank_min = "Best Games Finish"; 
RUN;

/* Best Male Finishers in the Open */
PROC REPORT DATA = work.top_male_open NOWD;
	TITLE "Top 10 Male Finishers (Open, 2019)";
	COLUMNS open_rank competitorname countryoforiginname age height_ft weight_lbs;
	DEFINE open_rank / DISPLAY "Open/ Overall Rank" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE competitorname / DISPLAY "Competitor" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE countryoforiginname / DISPLAY "Country of Origin" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE age / DISPLAY "Age (years)" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE height_ft / DISPLAY "Height (ft.)" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE weight_lbs / DISPLAY "Weight (lbs.)" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
RUN;

/* Best Female Finishers in the Open */
PROC REPORT DATA = work.top_female_open NOWD;
	TITLE "Top 10 Female Finishers (Open, 2019)";
	COLUMNS open_rank competitorname countryoforiginname age height_ft weight_lbs;
	DEFINE open_rank / DISPLAY "Open/ Overall Rank" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE competitorname / DISPLAY "Competitor" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE countryoforiginname / DISPLAY "Country of Origin" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE age / DISPLAY "Age (years)" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE height_ft / DISPLAY "Height (ft.)" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE weight_lbs / DISPLAY "Weight (lbs.)" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
RUN;

/* Comparing Oepn & Games Performance (MEN) */
PROC REPORT DATA = work.best_games_men_ordered NOWD;
	TITLE "Open Performance of Top 10 Male Games Finishers";
	TITLE2 "Does a good open performance predict a good games finish?";
	COLUMNS competitorname open_rank ("Games Statistics" games_rank mean_event_finish);
	DEFINE competitorname / DISPLAY "Competitor" STYLE = [JUST = LEFT]
		STYLE(HEADER) = [FONTWEIGHT = BOLD];
	DEFINE open_rank / DISPLAY "Open/ Overall Rank" 
		STYLE = [Asis=on CELLWIDTH = 1.25in JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE games_rank / DISPLAY "Games Finish" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD];
	DEFINE mean_event_finish / DISPLAY "Mean Event Finish" 
		STYLE = [Asis=on CELLWIDTH = 1.25in JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD];
	*highlight rows where athlete finished in top 10 in both Open & Games;	
	COMPUTE open_rank; 
		IF open_rank IN (1:10) THEN DO; 
			CALL DEFINE(_row_,"STYLE","STYLE=[BACKGROUND= cxDDDDDD]"); 
		END;
	ENDCOMP;
RUN;

/* Comparing Open & Games Performance (WOMEN) */
PROC REPORT DATA = work.best_games_women_ordered NOWD;
	TITLE "Open Performance of Top 10 Female Games Finishers";
	TITLE2 "Does a good open performance predict a good games finish?";
	COLUMNS competitorname open_rank ("Games Statistics" games_rank mean_event_finish);
	DEFINE competitorname / DISPLAY "Competitor" STYLE = [JUST = LEFT]
		STYLE(HEADER) = [FONTWEIGHT = BOLD];
	DEFINE open_rank / DISPLAY "Open/ Overall Rank" 
		STYLE = [Asis=on CELLWIDTH = 1.25in JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = CENTER];
	DEFINE games_rank / DISPLAY "Games Finish" STYLE = [JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD];
	DEFINE mean_event_finish / DISPLAY "Mean Event Finish" 
		STYLE = [Asis=on CELLWIDTH = 1.25in JUST = CENTER]
		STYLE(HEADER) = [FONTWEIGHT = BOLD];
	*highlight rows where athlete finished in top 10 in both Open & Games;	
	COMPUTE open_rank; 
		IF open_rank IN (1:10) THEN DO; 
			CALL DEFINE(_row_,"STYLE","STYLE=[BACKGROUND= cxDDDDDD]"); 
		END;
	ENDCOMP;
RUN;

*Create plot that compares athletes' performances on each event head-to-head;
%MACRO head_2_head(athlete1=, athlete2=);
	PROC SQL;
		CREATE TABLE work.plottingds AS
			SELECT competitorname, Event, event_rank_num 
				FROM work.all_data2
				/* 2 athletes being compared */
				WHERE competitorname IN ("&athlete1", "&athlete2") 
				ORDER BY competitorname, event;
	RUN;
	
	
	PROC SGPLOT DATA = work.plottingds;
		TITLE "Athlete Performance at 2019 Games";
		TITLE2 "Comparing &athlete1 vs. &athlete2";
		SERIES x=Event y=event_rank_num / group=competitorname  
			MARKERS MARKERATTRS = (SYMBOL = CIRCLEFILLED);
		KEYLEGEND / TITLE = "Athlete";
		/* make sure to show all events on the x axis */
		XAXIS INTEGER 
			VALUES = (1 TO 12 BY 1) 
			LABEL = "Event Number";
		YAXIS LABEL = "Event Finish";
	RUN;
%mend;

*run macro on key pairings of athletes;
%head_2_head(athlete1 = Mathew Fraser, athlete2 = Noah Ohlsen);
%head_2_head(athlete1 = Will Moorad, athlete2 = Uldis Upenieks)
%head_2_head(athlete1 = Tia-Clair Toomey, athlete2 = Kristin Holte);
%head_2_head(athlete1 = Thuridur Erla Helgadottir, athlete2 = Ragnheiður Sara Sigmundsdottir);

*Examining event details for all events at the games;
PROC REPORT DATA = work.event_details NOWD;
	TITLE "Events at the 2019 CrossFit Games";
	COLUMNS Event Name event_type num_cut;
	DEFINE Event / DISPLAY "Event No." STYLE(HEADER) = [FONTWEIGHT = BOLD];
	DEFINE Name / DISPLAY "Event Name" STYLE(HEADER) = [FONTWEIGHT = BOLD];
	DEFINE event_type / DISPLAY "Type of Event" STYLE(HEADER) = [FONTWEIGHT = BOLD];
	DEFINE num_cut / DISPLAY "No. Athletes Cut After Event" STYLE = [ASIS=on CELLWIDTH = 1.25in]
		STYLE(HEADER) = [FONTWEIGHT = BOLD JUST = RIGHT];
RUN;

*Examining distribution of event types at the games;
PROC FREQ DATA = work.event_details;
	TITLE "Distribution of Event Types";
	TABLES first_half*event_type / NOCUM NOROW NOCOL;
RUN;

ODS PDF CLOSE;



proc printto; run;