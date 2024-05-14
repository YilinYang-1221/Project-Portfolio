
*************************************************************
locate data and macros
--all primary data are in the path of "Project" holder
  all useful output data are in the path of "output" holder
*************************************************************; 

libname project "C:\Users\win10\Desktop\My Project\data";
libname output "C:\Users\win10\Desktop\My Project\data";
%include "C:\Users\win10\Desktop\My Project\macro\group10.sas";
%include "C:\Users\win10\Desktop\My Project\macro\group5.sas";
%include "C:\Users\win10\Desktop\My Project\macro\winsorize.sas";
%include "C:\Users\win10\Desktop\My Project\macro\csmar_monret_singlesorts.sas";
%include "C:\Users\win10\Desktop\My Project\macro\csmar_monret_capm_ff3_reg.sas";



/*********************************************************************************************************************************************************************/
/* STEP-1:                    DATA Preparing Process: Four Parts
            Part 1: Define different filters; 
            Part 2: Mark special treatment and particular transfer(ST&PT) stocks in sample;
            Part 3: Apply different filters and other restrictions in stock_return_month, balance_sheet, and income_statement data
            Part 4: Adjust the report value to the current quarterly value in balance sheet and income statement
*/
/*********************************************************************************************************************************************************************/

*****************************************************************
Part 1: define different filters in order to prepare data
*****************************************************************; 

*** various parameters to extrct subset of data ***;
%let begdate=2008; /*beginning date of data */
%let enddate=2021; /*ending date of data   */
%let date_filter  =&begdate<=year<=&enddate; 
/*restrict a sub-sample within begin date to end date;trdmnt */
%let markettype_filter = MARKETTYPE in (1, 4, 16) ; /*1:Shanghai A; 4:ShenzhenA; 16:Growth Enterprises Market*/           
%let ret_filter = nmiss(mretwd, msmvosd)=0 ; /*Non-missing return with cash dividend reinvested, and market value of tradable shares */ 
%let advertising_expense_filter = nmiss(B001209000)=0;/*Non-missing value in selling expenses(advertising expenses)*/
%let industry_filter =  Nnindcd ^in ("J66" "J67" "J68" "J69"); /*Nnindcd:CSRC industry classification code 2012 edition, "J66":Monetary financial service, "J67":capital market services, "J68":insurance, "J69":other finance*/  
%let financial_state_filter = TYPREP in ("A");    /*A:Consolidated Financial Statements*/
%let stock_ret_vars= stkcd trdmnt year month yearr mretwd msmvosd msmvttl mclsprc markettype nnindcd status_decision mv mvlag tmv tmvlag date;  /*Cn_monthly_stock_returns file variables*/
%let balance_vars = stkcd accper year month typrep A001000000/*total assets*/;/*Cn_balance_sheet file variables*/
%let income_vars = stkcd accper year month  typrep B001209000/*Selling Expenses*/; /*Cn_income_statement file variables*/


******************************************************************************
Part 2: Mark special treatment and particular transfer(ST&PT) stocks in sample
******************************************************************************;
/*define different class of stocks, we have to delete the sp_pt stock when we construct portfolios*/

data work.st_pt_movement;
set project.Cn_st_pt_movement;
date = input(Annoudt, yymmdd10.); /*convert character date to numeric date*/
format date yymmddn8.;
year=year(date); month=month(date);
if Chgtype in ("AB" "AD" "AX" "BC" "BD" "BX" "CB" "CX" "DB" "DX") then status="out"; /*out(status) means stocks with special treatment and particular transfer*/
  else if Chgtype in ("BA" "DA" "CA") then status="in"; /*in(status) means stocks transfer back to normal state or it is normal originally*/
run;
data work.Cn_monthly_stock_returns;
set project.Cn_monthly_stock_returns;
format year month BEST12.;
year=substr(Trdmnt,1,4);
month=substr(Trdmnt,6,2);
run;
/*define year and month in stock return data and merge with company profile in order to use industry filters*/
proc sql;
create table  work.cn_stock_ret_month
as select a.*, b.Nnindcd /*industry classification code in China*/
from work.Cn_monthly_stock_returns a, project.Cn_company_profile b  
where a.STKCD=b.STKCD;
quit;
/*use stock return month data left join with st_pt data in order to define the status for every stock in every month*/
proc sql;
create table   work.cn_stock_month_stpt
as select a.stkcd,a.trdmnt,a.year,a.month, b.status
from work.cn_stock_ret_month a left join work.st_pt_movement b
on a.STKCD=b.STKCD and  a.year=b.year and a.month=b.month; 
quit;

*********** fill missing values for status;
data  work.cn_stock_month_stpt ;
   set   work.cn_stock_month_stpt  ;
		    by STKCD  TRDMNT;
    retain status1;
    if first.STKCD then
      do;
        status="in"; status1=status; 
      end;
    else
      do;
       if missing(status) then status = status1;
      else status1 = status;
      end;
status_decision=lag(status); if first.stkcd=1 then status_decision="in"; /*we create status_decision which use lag of status 
because we delete(add) the st_pt stock at the month after the month which reports st_pt state change*/
drop status1;
run;
/*delete the repeating observations*/
proc sort data=work.cn_stock_month_stpt nodupkey;
by stkcd trdmnt;
run;
/*merge the st_pt stock information with stock return month, the end of part 1*/
proc sql;
create table   work.cn_stock_ret_month
as select a.*, b.status_decision
from work.cn_stock_ret_month a, work.cn_stock_month_stpt b
where a.STKCD=b.STKCD and  a.year=b.year and a.month=b.month; 
quit;

*******************************************************************************************
Part 3: apply different filters in stock_return_month, balance_sheet, and income_statement
*******************************************************************************************;
/*1st: stock return month*/
data   work.cn_stock_ret_month ; * Trading data file ;
set  work.cn_stock_ret_month;
by 	 stkcd trdmnt; 
mv = msmvosd; * market value of tradable shares;
mvlag=lag(mv); if first.stkcd then mvlag=.; *lagged mrk value, if first...otherwise, lagged firm's last mv ;
tmv= msmvttl; * market value of tradable shares;
tmvlag=lag(tmv); if first.stkcd then tmvlag=.;*lagged total mrk value, if first...otherwise, lagged firm's last total mv ;
day=28; format date YYMMDDN8.;
date=mdy(month,day,year); /*create date variable in convenient to merge the data in the following steps*/
if month>= 5 then yearr=year; else if month<= 4 then yearr=year-1 ; *date for annual rebalance ;
where  &date_filter and &markettype_filter and &ret_filter and &industry_filter ; * date, markettype, return , and  industry conditions; 
keep &stock_ret_vars; 
run;
/*2nd: balance_sheet*/
data   work.cn_balance_sheet ; * Trading data file ;
set  project.cn_balance_sheet; 
by stkcd accper;
year=year(accper); month=month(accper);
at=a001000000;/*at:total asset*/
lag_at=lag(at); if first.stkcd then lag_at=.;
if  &date_filter and &financial_state_filter; * date, markettype, return , and  industry conditions; 
if month=1 then delete;  /*when month=1 the report has to be adjusted, so it is useless*/
keep &balance_vars at lag_at ; 
run;
/*3nd: income_statement*/
data work.cn_income_statement;
set project.cn_income_statement;
if &financial_state_filter;
keep Stkcd Accper Typrep B001209000;
run;
/*Create a table to summarize data needed*/
proc sql;
create table work.cn_ranking_expenses
as select a.Stkcd,B001209000,b.*
from work.Cn_income_statement a, project.Cn_market_cap b
where a.Stkcd=b.Stkcd and a.Accper=b.Accper;
quit;
/*4th: change the format of date and apply filters to it*/
data   work.cn_ranking_expenses ; * Trading data file ;
set  work.cn_ranking_expenses; 
format year month BEST12.;
year=substr(Accper,1,4);
month=substr(Accper,6,2);
se=B001209000;market_cap=F100801A;/*se:selling expenses*/
if  &date_filter and &advertising_expense_filter and &industry_filter; * date, markettype, return , and  industry conditions; 
if month=1 then delete; /*when month=1 the report has to be adjusted, so it is useless*/
if se<=10000000 then delete;
keep Stkcd se Accper Indcd market_cap year month advertising_ratio; 
run;
data work.cn_ranking_expenses;
set work.cn_ranking_expenses;
advertising_ratio=se/market_cap; /*use percentage to eliminate scale effect*/
if month=12;/*accumulated selling(advertising) expenses*/
lag_1=lag(advertising_ratio);if first.stkcd then lag_1=.;
lag_2=lag(lag_1);if first.stkcd then lag_2=.;
keep Stkcd se Accper Indcd market_cap year advertising_ratio lag_1 lag_2;
run;
/*calculate gAD*/
data work.cn_gAD;
set work.cn_ranking_expenses;
if lag_1=. then delete;
if lag_2=. then delete;
gAD=(lag_1-lag_2)/lag_1;
keep Stkcd Indcd year gAD;
run;


/*5th: generate risk-free data and three factor monthly data*/
data work.ff3_month;
set project.Cn_ff3_monthly_90_21;
year=year(date);
month=month(date);
run;

/*********************************************************************************************************************************************************************/
/* STEP-2:                  Single Sorts of different methods to use quarterly report data
   *****  Definition: gAD=(lag_1-lag_2)/lag_1************
  Method: Using the reporting date quarterly data and refresh the portfolios in the next month ;
          Singlesorts by using the adjusted quarterly report data;
*/

/*form stocks into 10 deciles*/
%Group10 (INSET= work.cn_gAD, OUTSET= work.cn_gAD, SORTVAR=year,  VARS= gAD) ;

/*rename the group dummy in convenient to use macro codes in the following steps*/
data  work.cn_gAD ;
set  work.cn_gAD ;
drop  gAD_g10 ;
rename group_dum= gAD_g10;
run;

/*merge monthly stock return data with group informations*/
proc sql; 
create table work.gAD_g10
as select a.stkcd, a.trdmnt,a.year,a.month,a.mretwd, a.mv, a.mvlag,a.date,a.yearr, b.gAD, b.gAD_g10
from  work.cn_stock_ret_month a, work.cn_gAD b
where a.stkcd=b.stkcd and a.year=b.year;
quit;

/*calculate different portfolio ew- and vw- returns in each month and the raw returns*/
%SingleSorts( in= work.gAD_g10 , 
              out= output.out_gAD_g10 /*_mon_ means every month we refresh our portfolios if there is any new quarterly report*/,
              outret=output.outret_gAD_g10, varsort=gAD_g10 ,   high_low_dum=1 ,begin_yyyymm =200801 ,end_yyyymm=202110 );

/*use single sorts results(portfolio returns) to calculate raw return and apply Capital Asset Pricing Model (CAPM) and Fama French Three Factor Model (FF3) regressions*/
/*equal weighted-adjusted with lag quarterly report informations*/
%ret_capm_ff3_total( input=output.outret_gAD_g10, output=output.gAD_ret_capm_ff3_ew,tvarsort=gAD_g10 , weight=e , begin_yyyymm_t =200801 ,end_yyyymm_t=202110 )
/*value weighted-adjusted with lag quarterly report informations*/
%ret_capm_ff3_total( input=output.outret_gAD_g10, output=output.gAD_ret_capm_ff3_vw,tvarsort=gAD_g10 , weight=v , begin_yyyymm_t =200801 ,end_yyyymm_t=202110 )
