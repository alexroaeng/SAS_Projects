libname  CH '/home/u59696161/sasuser.v94/ch';

/* data import */

proc import
	datafile = "/home/u59696161/sasuser.v94/ch/Churn_Modelling.csv"
	out = ch.ds_original
	dbms = csv replace;
	delimiter = ',';
	getnames = yes;
run;


proc import
	datafile = "/home/u59696161/sasuser.v94/ch/Churn_Modelling.csv"
	out = ch.ds1
	dbms = csv replace;
	delimiter = ',';
	getnames = yes;
run;



/*
DATA EXPLORATORY
*/

proc contents data=ch.ds1;
run;


/*
getting thew histograms
*/
/*

proc means data=CHURN.ds chartype mean median std min max n vardef=df;
	var RowNumber CustomerId CreditScore Age Tenure Balance NumOfProducts
		HasCrCard IsActiveMember EstimatedSalary Exited;
	output out=CHURN.MEANS_STATS mean=std=min=max=n= / autoname;
run;

proc univariate data=CHURN.ds vardef=df noprint;
	var RowNumber CustomerId CreditScore Age Tenure Balance NumOfProducts
		HasCrCard IsActiveMember EstimatedSalary Exited;
	histogram RowNumber CustomerId CreditScore Age Tenure Balance NumOfProducts
		HasCrCard IsActiveMember EstimatedSalary Exited;
	inset mean median std min max n / position=nw;
run;


/*
getting the missing values
*/

/*

proc means data=CH.ds1 chartype nmiss vardef=df;
	var  CreditScore Age Tenure Balance NumOfProducts
		HasCrCard IsActiveMember EstimatedSalary Exited;
	class Geography Gender;
run;


/*
boxplot
*/
/*
proc sgplot data=CHURN.ds;
	hbox Age / fillattrs=(color=CXCAD5E5);
	xaxis grid;
run;

proc sgplot data=CHURN.ds;
	hbox Balance / fillattrs=(color=CXCAD5E5);
	xaxis grid;
run;


proc sgplot data=CHURN.ds;
	hbox Tenure / fillattrs=(color=CXCAD5E5);
	xaxis grid;
run;

proc sgplot data=CHURN.ds;
	hbox NumOfProducts / fillattrs=(color=CXCAD5E5);
	xaxis grid;
run;



proc sgplot data=CHURN.ds;
	hbox CreditScore / fillattrs=(color=CXCAD5E5);
	xaxis grid;
run;


   /* 3. Find percentile values on losses to treat for outliers  take care of age */
   /*outliers of age are replace for median of age is 37 we dont wan to lose this information  */
  proc univariate data=ch.ds1 ;
      var age;
      histogram;
      output out=Losses_Ptile pctlpts  = 90 95 97.5 99 99.5 99.6 99.7 99.8 99.9 100 pctlpre  = P_;
   run;
    
                
    data ch.ds1;
	set ch.ds1;
	if age > 60 then age =37;
	run;       
    
         proc sgplot data=ch.ds_original;
	hbox age / fillattrs=(color=CXCAD5E5);
	xaxis grid;
	run;
	
    
       /*tratment for age variable finish here */
      
             /*tratment for creditscore start here */

	
	  proc univariate data=ch.ds1 ;
      var creditscore;
      histogram;
      output out=Losses_Ptile pctlpts  = 90 95 97.5 99 99.5 99.6 99.7 99.8 99.9 100 pctlpre  = P_;
   	  run;
   	  
   	   proc sgplot data=ch.ds1;
	   hbox creditscore / fillattrs=(color=CXCAD5E5);
		xaxis grid;
		run;
		
		data ch.ds1creditscore;
		set ch.ds1;
		if creditscore  < 430 then delete;
		run; 
		
		 /*just the 0.085% from credit score are outliar just leave unthosh*/
		
		
    
                                      
/*Find out which IV are good for the model. Do we need more IV. Can we enrich the model. */  

/* Perform bivariate (correlation matrix) for continous variables.
Compare every variable with Excited and also among themselves. */
*Bivariate profiling for continous vars;



proc corr data=ch.ds1;
var Exited CreditScore Age Tenure Balance
	EstimatedSalary ;
title 'Correlation Matrix';
run;



/*Bi Variate analysis for every continous IV with the DV .
Bar chart for every var. X axis is the DV and Y axis is the avg of the IV.    */     


*Bivariate Analysis of continous independent variable;

/* Age, credit score, tenure, balance, no.of.products, estimated salary*/

%macro mBivariateCont(var);
	proc sql;
	Create table &var._tab as
	select Exited, avg(&var) as Avg&var
	from ch.ds1
	group by Exited ;
	quit;
	
	proc SGPLOT data = &var._tab;
	vbar Exited/ response=Avg&var stat=mean;
	title "Avg &var Excited";
	run;

	proc print data = &var._tab;
	run;
%mend mBivariateCont;

%mBivariateCont(CreditScore);

%mBivariateCont(Age);

%mBivariateCont(Tenure);

%mBivariateCont(EstimatedSalary);


/* firts insights from  the Bivariate analisys 

	1 avg credit score doesnt see relevant againts exited	
	2 avg age look like there is important impact it the group of 30 years old trend stays more thatn the 40 year group 
	3 avg tenure denote no diference are 0.1 between the exited status or no (5.1 and 4.9)
	4 avg estimated salary sees too close with just a diference of $1727 beeeing just  the 1.7% respect the total  */



/*Creation of all derived variables
Age Group
Band of age to classified the popullation of the dataset
https://www.statcan.gc.ca/eng/concepts/definitions/age2
0-14 Children
15-24 Youth
25-65 Adult
>65 Seniors*

Credit Score

Classification credit score
https://www.experian.com/blogs/ask-experian/credit-education/score-basics/what-is-a-good-credit-score/
300-579 Poor
580-669 Fair
670-739 Good
740-799 Very Good
800-850 Exceptional

antiquity->
Tenure
0-3 New
3-6 Mid
>7 Senior

Level
Balance
0-49999 clasicc
50000-99999 silver
100000-179999 Gold
>180000 Platinum
*/


/* inserting derivate variables on ds1 important step before running the multicollinearity  */


data ch.ds1;

  length AgeGroup $10.;
  length CreditScoreGroup $15.;
  retain RowNumber	CustomerId	Surname	CreditScore	Geography	Gender	Age	AgeGroup Tenure	Balance	NumOfProducts	HasCrCard	IsActiveMember	EstimatedSalary	Exited;
  set ch.ds1;
  if Age <= 14 then AgeGroup = "Children";
  else if Age >14 and Age <= 24 then Agegroup = "Youth";
  else if Age>24 and Age<= 65 then AgeGroup="Adult";
  else if Age>65 then AgeGroup="Senior";

  if CreditScore <= 579 then CreditScoreGroup = "Poor";
  else if CreditScore >579 and CreditScore <= 669 then CreditScoreGroup = "Fair";
  else if CreditScore>669 and CreditScore<= 739 then CreditScoreGroup="Good";
  else if CreditScore>739 and CreditScore<=799 then CreditScoreGroup="Very Good";
  else if CreditScore>799 then CreditScoreGroup="Exceptional";

  if tenure <= 3 then antiquity = "New";
  else if tenure >3 and tenure <= 6 then antiquity = "Mid";
  else if tenure>6 then antiquity="Senior";
 
   if Balance <= 49999 then level = "Classic";
  else if Balance >49999 and Balance <=99999  then level = "Silver";
  else if Balance>99999 and Balance <=179999 then level="Gold";
  else if Balance>179999 then level="Platinum";

run;

/* ######needs to be run for  inser the dev variables on ds  above */

proc print data=ch.ds1;
  var 	 CreditScoreGroup AgeGroup  antiquity	 level;
  title 'Derived Variables';
run;

/* derivate colums variables CreditScoreGroup AgeGroup  antiquity	 level;	 */




/* Bi Variate analysis for every categorical IV with the DV
Bar chart for every var. X axis is the IV and Y axis is the % of 1's in the DV. */






data ch.ds1;
set ch.ds1;

	/*Gender*/	
	if Gender eq 'Male' then Gender_Acc_dummy_xy_1 = 1;
		else  Gender_Acc_dummy_xy_1 = 0;


	
	/*CHasCrCard*/

	if HasCrCard eq '2' then HasCrCard_dummy_2 = 1;
		else HasCrCard_dummy_2 = 0;	
	
		
	/*Geography*/
	if Geography eq 'France' then Geography_dummy_f_1 = 1;
		else Geography_dummy_f_1 = 0;
	if Geography eq 'Spain' then Geography_dummy_s_2 = 1;
		else Geography_dummy_s_2 = 0;
	if Geography eq 'Germany' then Geography_dummy_g_3 = 1;
		else Geography_dummy_g_3 = 0;
	
	/*NumOfProducts*/
	if NumOfProducts eq '1' then NumOfProducts_Acc_dummy_1 = 1;
		else NumOfProducts_Acc_dummy_1 = 0;
	if NumOfProducts eq '2' then NumOfProducts_Acc_dummy_2 = 1;
		else NumOfProducts_Acc_dummy_2 = 0;
	if NumOfProducts eq '3' then NumOfProducts_Acc_dummy_3 = 1;
		else NumOfProducts_Acc_dummy_3 = 0;
	if NumOfProducts eq '4' then NumOfProducts_Acc_dummy_4 = 1;
		else NumOfProducts_Acc_dummy_4 = 0;
	
	/*IsActiveMember*/

	if IsActiveMember eq '1' then IsActiveMember_dummy_2 = 1;
		else IsActiveMember_dummy_2 = 0;	
		
		
	/*Dummy for Derived Variables*/	

/*Age Group*/	
	if AgeGroup eq 'Children' then Age_Group_dummy_1 = 1;
		else  Age_Group_dummy_1 = 0;
	if AgeGroup eq 'Youth' then  Age_Group_dummy_2 = 1;
		else  Age_Group_dummy_2 = 0;

    if AgeGroup eq 'Adult' then  Age_Group_dummy_3 = 1;
		else  Age_Group_dummy_3 = 0;
		
    if AgeGroup eq 'Seniors*' then  Age_Group_dummy_4 = 1;
		else  Age_Group_dummy_4 = 0;
		

/*Credit Score*/	
	if CreditScore eq 'Poor' then Credit_Score_dummy_1 = 1;
		else  Credit_Score_dummy_1 = 0;
	if CreditScore eq 'Fair' then  Credit_Score_dummy_2 = 1;
		else  Credit_Score_dummy_2 = 0;

    if CreditScore eq 'Good' then  Credit_Score_dummy_3 = 1;
		else  Credit_Score_dummy_3 = 0;
		
    if CreditScore eq 'Very Good' then  Credit_Score_dummy_4 = 1;
		else  Credit_Score_dummy_4 = 0;
		
	 if CreditScore eq 'Exceptional' then  Credit_Score_dummy_5 = 1;
		else  Credit_Score_dummy_5 = 0;
		
		
/*antiquity Tenure*/	
	if antiquity eq 'New' then Tenure_dummy_1 = 1;
		else  Tenure_dummy_1 = 0;
	if antiquity eq 'Mid' then  Tenure_dummy_2 = 1;
		else  Tenure_dummy_2 = 0;

    if antiquity eq 'Senior' then  Tenure_dummy_3 = 1;
		else  Tenure_dummy_3 = 0;
		
		
/*Level Balance*/		
		
	if level eq 'classic' then Balance_dummy_1 = 1;
		else   Balance_dummy_1 = 0;
	if level eq 'silver' then  Balance_dummy_2 = 1;
		else  Balance_dummy_2 = 0;

    if level eq 'Gold' then  Balance_dummy_3 = 1;
		else  Balance_dummy_3 = 0;
		
    if level eq 'Platinum' then  Balance_dummy_4 = 1;
		else  Balance_dummy_4 = 0;	

run;

/*up to here the dataset is full with all variables and dummy variables the data  set  is the ds1 and has to be create in order to run the multicollinearity test*/	
/*macro for bicariate analisys over non continuos  variables  */	


%macro mBivariateCateg(var);
	proc sql;
	Create table &var._tab as
	select &var, count(*) as freq,
	sum(exited) as exited
	from ch.ds1
	group by &var;
	quit;
	
	data &var._tab;
	set &var._tab;
		Default_exited = exited/freq;
	run;
	
	proc SGPLOT data = &var._tab;
	vbar &var/ response=Default_exited stat=mean;
	title "Default exited for &var";
	run;

	proc print data =&var._tab;
	run;
%mend mBivariateCateg;


%mBivariateCateg(IsActiveMember);
%mBivariateCateg(HasCrCard);
%mBivariateCateg(NumOfProducts);
%mBivariateCateg(Gender);
%mBivariateCateg(Geography);


/* 
list  of all variables
/* 

objetive variable : exited

continuos variables original: 
CreditScore Age Tenure Balance EstimatedSalary

dummy original:
    Gender_Acc_dummy_xy_1 HasCrCard_dummy_2 Geography_dummy_f_1 Geography_dummy_s_2
    Geography_dummy_g_3 NumOfProducts_Acc_dummy_1 NumOfProducts_Acc_dummy_2
    NumOfProducts_Acc_dummy_3 NumOfProducts_Acc_dummy_4 IsActiveMember_dummy_2

dummy derivate :

Age_Group_dummy_1 Age_Group_dummy_2 Age_Group_dummy_3 Age_Group_dummy_4 
Credit_Score_dummy_1 Credit_Score_dummy_2 Credit_Score_dummy_3 Credit_Score_dummy_4
Credit_Score_dummy_5

Tenure_dummy_1 Tenure_dummy_2 Tenure_dummy_3

Balance_dummy_1 Balance_dummy_2 Balance_dummy_3 
Balance_dummy_4


derivate  variables :
CreditScoreGroup AgeGroup  antiquity	 level

 */


%Let Var_all = 

CreditScore Age Tenure Balance EstimatedSalary
    Gender_Acc_dummy_xy_1 HasCrCard_dummy_2 Geography_dummy_f_1 Geography_dummy_s_2
    Geography_dummy_g_3 NumOfProducts_Acc_dummy_1 NumOfProducts_Acc_dummy_2
    NumOfProducts_Acc_dummy_3 NumOfProducts_Acc_dummy_4 IsActiveMember_dummy_2
Age_Group_dummy_1 Age_Group_dummy_2 Age_Group_dummy_3 Age_Group_dummy_4 
Credit_Score_dummy_1 Credit_Score_dummy_2 Credit_Score_dummy_3 Credit_Score_dummy_4
Credit_Score_dummy_5
Tenure_dummy_1 Tenure_dummy_2 Tenure_dummy_3
Balance_dummy_1 Balance_dummy_2 Balance_dummy_3 
Balance_dummy_4

;

/*firts multicollinearity*/

proc reg data=ch.ds1;
 model Exited = &Var_all/ vif tol collin;
 title 'Sorted in the order of VIF score';
run;


%Let Var_after = 

CreditScore Age  EstimatedSalary
    Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     IsActiveMember_dummy_2
 Balance_dummy_3 
;

/*second multicollinearity*/


proc reg data=ch.ds1;
 model Exited = &Var_after/ vif tol collin;
 title 'Sorted in the order of VIF score multicollinearity';
run;



proc corr data=ch.ds1;
var Exited CreditScore Age  EstimatedSalary
    Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     IsActiveMember_dummy_2
 Balance_dummy_3  ;
title 'Correlation Matrix';
run;


/*
the one with more correlation respect   exited are :
Age
EstimatedSalary
Balance_dummy_3
*/


proc contents data = ch.ds1; run;


proc means data=ch.ds1 chartype nmiss vardef=df;
	var  CreditScore Age Tenure Balance 
		  EstimatedSalary ;
	class Geography Gender IsActiveMember Exited NumOfProducts HasCrCard Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2 Geography_dummy_g_3;
run;



/*validation Splitting the data into Training and Validation (80:20);*/


proc sql;
create table ch.ds2 as
select  Exited, CreditScore, Age,  EstimatedSalary, balance,
    Gender_Acc_dummy_xy_1,  Geography_dummy_f_1, Geography_dummy_s_2,
     IsActiveMember_dummy_2, Balance_dummy_3
from ch.ds1;
quit;


*7. Macro for iterate with different variables  the data will split in  Training and test (80:20);


%macro runModel  (Trainperc,seed,version,var);

data ch.exited_Train_&version ch.exited_Test_&version;
set ch.ds2;
	if ranuni(&seed) le &Trainperc then output ch.exited_Train_&version;
	else output ch.exited_Test_&version;
run;
proc logistic data=ch.ds2  descending outest=betas covout outmodel=mg1;
 model exited =   &var 
              / selection=stepwise
                slentry=0.01
                slstay=0.005
                details
                lackfit;
 output out=Pred_ds2 p=phat lower=lcl upper=ucl
        predprobs=(individual);
run;	
/*10. Confusion matrix */
proc freq data=Pred_ds2;
table _FROM_*_INTO_ / out=ConfusionMatrix nocol norow;
run;
%mend



%runmodel(0.75 ,123,96,) 9.06*/

%runmodel(0.75 ,10000,34) 7.29*/ 


/*testing the model whi differente  variables  */

%runmodel(0.80 ,123,12, age EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3) /* 7.29 this number will represent the total match values respect the original train*/


%runmodel(0.80 ,123,11) no age  no results


%runmodel(0.80 ,123,10,CreditScore Age  
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3) /* 7.29*/
				/*	 */



%runmodel(0.80 ,123,9,CreditScore Age  EstimatedSalary
    			    Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3 ) /* 6.32*/
				/**/


%runmodel(0.80 ,123,8,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1   Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3)/* 5.97*/
				
				 /*  */


%runmodel(0.80 ,123,7,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 
     			  IsActiveMember_dummy_2 Balance_dummy_3)/*6.15*/
/**/

%runmodel(0.80 ,123,6,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			   Balance_dummy_3) /*5.39*/
				/*	 */


%runmodel(0.80 ,123,5,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 ); /*7.06*/
				  */

%runmodel(0.80 ,123,14,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3); /*7.29 */ the version will be the 
				 /*  */



/*it shows this is the best combination of variables just getting 7.29% of accuracy with this model*/
/*Now i will get the best posible training and test split  nex macro will do the job */


/*performance table and  lifter*/

/*macro for test the model 14 with different splits*/


%macro runModel3  (version,obstrain,obstest);


*8. List of variables to be used in Logistic Regression;

%Let Varlist1 = 	
	CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3 
;
			

proc logistic data=ch.exited_Train_$version  descending outest=betas covout outmodel=mg1;
 model exited= &VarList1
              / selection=stepwise
                slentry=0.01
                slstay=0.005
                details
                lackfit;
 output out=Pred_exited_Train_&version p=phat lower=lcl upper=ucl
        predprobs=(individual);
        
        
run;	

proc sort data = Pred_exited_Train_&version; by descending phat;
run;


%Let NoOfRecords = &obstrain;
%Let NoOfBins = 10;
data Pred_exited_Train_v2;
set Pred_exited_Train_&version;
retain Cumulative_Count;
	Count = 1;
	Cumulative_Count = sum(Cumulative_Count, Count);
	Bin = round(Cumulative_Count/(&NoOfRecords/&NoOfBins) - 0.5) + 1;
	if Bin GT &NoOfBins then Bin = &NoOfBins;
run;



proc sql;
create table Gains_v1 as
select Bin as CustomerGroup, count(*) as CountOfCustomers, sum(exited) as CountOfDefaulters
from Pred_exited_Train_v2
group by Bin;
quit;

proc sql;
select count(1) into :TrainingDefaulterCount
from Pred_exited_Train_v2
where exited=1;
quit;

data Gains_v1;
set Gains_v1;
ModelPercOfDefaulters = CountOfDefaulters*100/&TrainingDefaulterCount;
RandomPercOfDefaulters = 100/&NoOfBins;
retain ModelCummPercOfDefaulters RandomCummPercOfDefaulters;
ModelCummPercOfDefaulters = sum(ModelCummPercOfDefaulters,ModelPercOfDefaulters);
RandomCummPercOfDefaulters = sum(RandomCummPercOfDefaulters,RandomPercOfDefaulters);
KS = ModelCummPercOfDefaulters-RandomCummPercOfDefaulters;
run;

proc sql;
  insert into Gains_v1
     set  CountOfCustomers=0,  CountOfDefaulters = 0,  CustomerGroup=0,
     		 KS=0,  ModelCummPercOfDefaulters=0, ModelPercOfDefaulters=0,
     		  RandomCummPercOfDefaulters=0, RandomPercOfDefaulters=0;
quit;
*Sort the records by predicted probabilities in descending order;
proc sort data = Gains_v1; by CustomerGroup;
run;

PROC sgplot DATA=Gains_v1;
   series x=CustomerGroup y=ModelCummPercOfDefaulters;
   series x=CustomerGroup y=RandomCummPercOfDefaulters;
run;

/* test*/

proc logistic inmodel=mg1;
 score data = ch.exited_Test_&version out=Pred_exited_Test_&version ;
run;

proc sort data = Pred_exited_Test_&version; by descending p_1;
run;


%Let NoOfRecords = &obstest;
%Let NoOfBins = 10;
data Pred_exited_Test_v2;
set Pred_exited_Test_&version;
retain Cumulative_Count;
	Count = 1;
	Cumulative_Count = sum(Cumulative_Count, Count);
	Bin = round(Cumulative_Count/(&NoOfRecords/&NoOfBins) - 0.5) + 1;
	if Bin GT &NoOfBins then Bin = &NoOfBins;
run;

proc sql;
create table Gains_v2 as
select Bin as CustomerGroup, count(*) as CountOfCustomers, sum(exited) as CountOfDefaulters,
max(p_1) as MaxPredProb from Pred_exited_Test_v2
group by Bin;
quit;

proc sql;
select count(1) into :TestingDefaulterCount
from Pred_exited_Test_v2
where exited=1;
quit;

data Gains_v2;
set Gains_v2;
ModelPercOfDefaulters = CountOfDefaulters*100/&TestingDefaulterCount;
RandomPercOfDefaulters = 100/&NoOfBins;
retain ModelCummPercOfDefaulters RandomCummPercOfDefaulters;
ModelCummPercOfDefaulters = sum(ModelCummPercOfDefaulters,ModelPercOfDefaulters);
RandomCummPercOfDefaulters = sum(RandomCummPercOfDefaulters,RandomPercOfDefaulters);
KS = ModelCummPercOfDefaulters-RandomCummPercOfDefaulters;
run;


proc sql;
  insert into Gains_v2
     set  CountOfCustomers=0,  CountOfDefaulters = 0,  CustomerGroup=0,
     		 KS=0,  MaxPredProb=0, ModelCummPercOfDefaulters=0, ModelPercOfDefaulters=0,
     		  RandomCummPercOfDefaulters=0, RandomPercOfDefaulters=0;
quit; 

proc sql;
create table Gains_v3 as
select a.*, b.ModelCummPercOfDefaulters  as TestModelCummPercOfDefaulters
from Gains_v1 a, Gains_v2 b
where a.CustomerGroup= b.CustomerGroup;
quit;



PROC sgplot DATA=Gains_v3;
   series x=CustomerGroup y=ModelCummPercOfDefaulters;
   series x=CustomerGroup y=TestModelCummPercOfDefaulters;
   series x=CustomerGroup y=RandomCummPercOfDefaulters;
run;

%mend ;



/* chossig the model with the variables on version 14 
the macro keep those variables as we see before has most quantity of acertivities  */

%runmodel(0.80 ,123,14); /*7.29 */


/*time to tested with same variables differents percentile*/

/*
%macro runModel  (Trainperc,seed,version); you chosse the name of the version */

		%runmodel(0.70 ,123,34,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3; /*70 */

		%runmodel(0.75 ,123,24,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3; /*75 */


		%runmodel(0.80 ,123,44,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3; /*80 */

		%runmodel(0.85 ,123,54,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3; /*85 */

		%runmodel(0.90 ,123,64,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3; /*90 */

		%runmodel(0.95 ,123,74,CreditScore Age  EstimatedSalary
    			  Gender_Acc_dummy_xy_1  Geography_dummy_f_1 Geography_dummy_s_2
     			  IsActiveMember_dummy_2 Balance_dummy_3; /*95 */


/* 11. Lift Chart on training data 
*Generating Gains Curve and Calculating Gini Coeff & KS on Training records;*/

/* %macro runModel3  (version,obstrain,obstest);*/

		%runmodel3(44,8063,1937); /*80 */
		
		%runmodel3(34,7069,2931); /*70 */

		%runmodel3(24,7587,2413); /*75 */
		
		%runmodel3(54,8564,1436); /*85 */
		
		

/* getting table*/

proc sql;
create table Gains_v3 as
select a.*, b.ModelCummPercOfDefaulters  as TestModelCummPercOfDefaulters
from Gains_v1 a, Gains_v2 b
where a.CustomerGroup= b.CustomerGroup;
quit;



/*performance*/
%runmodel2(34); 






