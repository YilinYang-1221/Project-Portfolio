libname project "C:\Users\win10\Desktop\Thesis_data";
libname output "C:\Users\win10\Desktop\output";
/***********************************************************/
/*Define different filters*/
%let begdate=2015; /*beginning date of data */
%let enddate=2021; /*ending date of data   */
%let date_filter = &begdate<=year<=&enddate; 
%let ETF_filter=isETF in (1);/*select ETF from all funds to investigate expense ratio*/
%let background_filter=background in (2);/*only preserve funds established after 1998 for expense ratio*/
%let index_value_filter = nmiss(tgtindex)=0;/*index value cannot be missing*/
%let category_filter=category in (1,2);/*only use ETF in the mainland*/
%let reporttype_filter = reporttypeID in (1,2,3,4);/*only use quaterly report*/
%let top10_filter = code in (511990,511880,510050,510300,510500,510330,510180,159919,510880,159915);/*top10 ETF with abundant data from 2015 to 2021*/
%let daily_information_filter = Fundcd Trddt Nshrtrd Dretwd;/*daily return variables*/
%let main_information_filter = FundID MasterFundCode ManagementFee CustodianFee Inceptiondate categoryid isETF background;/*main information variables*/
%let target_index_filter = symbol tgtindex exchangecode category cashdiffer date year month;/*target index variables*/
%let results_etf_nav_filter = code date year month nav_return etf_return_lag;
%let index_ret_vars = symbol tgtindex category cashdiffer year month idxrtn;/*index return variables*/
%let fund_shareschange_vars = symbol symbol1 reporttypeID totalbeginningfundshare totalpurchasefundshare totalredemptionfundshare enddateshares startdate1 enddate1;
%let top10_etf_nav_vars = code exchange name NAV202104;/*select top10 etf*/
/************************************************/
/*change the format of date*/
data work.daily_return; /*this is ETF return*/
set project.daily_information;
date = input(trddt,yymmdd10.);
format date yymmddn8.;
drop trddt;
run;

data work.nav_return;
set project.target_index;
date = input(tradingdate,yymmdd10.);
nav_date = input(navenddate,yymmdd10.);
format date yymmddn8.;
format nav_date yymmddn8.;
drop tradingdate navenddate;
run;

data work.funds_index_return;
set project.index_information;
format year month BEST12.;
year=substr(Trdmnt,1,4);
month=substr(Trdmnt,6,2);
drop Trdmnt;
run;

data work.target_index_list;
set project.target_index;
date=input(tradingdate,yymmdd10.);
format date yymmddn8.;
year=year(date);
month=month(date); 
run;

data work.fund_dividend;
set project.fund_dividend;
date=input(primarypaydate_dividend,yymmdd10.);
format date yymmddn8.;
year = year(date);
month=month(date);
drop Announcementdate Secondarypaydate_dividend;
run;

data work.fund_shareschange;
set project.fund_sharechange;
startdate1=input(startdate,yymmdd10.);
enddate1=input(enddate,yymmdd10.);
format startdate1 yymmddn8.;
format enddate1 yymmddn8.;
drop startdate enddate;
run;

/*********************************************************/
/*merge ETF return and NAV*/
proc sql;
create table work.return_etf_nav
as select a.fundcd, a.date, a.dretwd, b.symbol, b.date, b.nav_date, b.nav
from work.daily_return a left join work.nav_return b
on a.fundcd=b.symbol and a.date=b.date;
quit;
/*calculate daily NAV return:NAV return=ln((NAVt)/(NAVt-1))*/
data work.return_etf_nav;
set work.return_etf_nav;
by fundcd date;
drop symbol;
if nav=. then delete;
code = fundcd*1;
nav_lag = lag(nav);
nav_return=log(nav/nav_lag);
drop fundcd;
run;

/*Only keep ETFs that have intact data from 2015 to 2021*/
data project.etf_nav;
set project.etf_nav;
if NAV201501=. then delete;
run;
proc sort data=project.etf_nav;
by code;
run;

/*only choose ETF data among all funds*/
proc sql;
create table work.true_etf
as select a.*, b.code
from work.return_etf_nav a, project.etf_nav b
where a.code = b.code;
run;

/*calculate tracking error between ETF return and NAV return*/
data work.true_etf;
   retain code date dretwd nav_date nav_return_percent nav_lag nav_return;
   set work.true_etf;
   nav_return_percent = nav_return*100;
   etf_return = dretwd/100;
   etf_return_lag = lag(etf_return);
   tracking_error_etf_nav = etf_return_lag-nav_return;
run;
proc sort data=work.true_etf;
by date;
run;

/*merge ETF and NAV return*/
data work.results_etf_nav;
set work.true_etf;
year=year(date);month=month(date);
by date;
keep &results_etf_nav_filter;
run;

/*Get average monthly return, merge different ETFs together according to year and month*/
proc sql;
create table work.monthly_results_etf_nav as select year,month,
mean(nav_return) as monthly_nav_return,
mean(etf_return_lag) as monthly_etf_return
from work.results_etf_nav group by year, month;
quit;

/*exclude missing terms*/
data work.nonmissing_target_index_list;
set work.target_index_list;
if &index_value_filter and &category_filter;
keep &target_index_filter;
run;
proc sort data=work.nonmissing_target_index_list;
by tgtindex date;
run;

/*Only keep indexes which are target indexes for ETFs*/
proc sql;
create table work.index_return
as select a.*, b.indexcd,idxrtn
from work.nonmissing_target_index_list a, work.funds_index_return b
where a.tgtindex = b.indexcd and a.year=b.year and a.month=b.month;
run;

/*Calculate target index return*/
proc sort data=work.index_return;
by year month symbol;
run;
data work.index_return;
set work.index_return;
by year month symbol;
drop exchangecode date indexcd;
run;

/*Merge different index returns according to year and month*/
proc sql;
create table work.monthly_results_index as select year,month,
sum(cashdiffer) as monthly_cashdiffer,
mean(idxrtn) as monthly_index_return
from work.index_return group by year, month;
quit;
data work.monthly_results_index;
set work.monthly_results_index;
by year month;
where &date_filter;/*only preserve data from 2015 to 2021*/
retain year month monthly_index_return monthly_cashdiffer;
run;

/*Get an ETF-NAV-Index return table for calculating tracking errors and making regressions*/
proc sql;
create table work.etf_nav_index_monthly
as select a.*, b.monthly_index_return,monthly_cashdiffer
from work.monthly_results_etf_nav a, work.monthly_results_index b
where a.year=b.year and a.month=b.month;
run;
data work.etf_nav_index_monthly_adjusted;
set work.etf_nav_index_monthly;
monthly_index_return_adjusted=monthly_index_return/30;/*adjust index return so that fits etf and nav return*/
drop monthly_index_return;
run;
/***********************************************************************/
/*Calculate liquidity value*/
proc sort data=project.liquidity_value;
by year month;
run;
proc sql;
create table work.etf_liquidity
as select a.*, b.code
from project.liquidity_value a, project.etf_nav b
where a.fundcd = b.code;
run;
data work.etf_liquidity;
set work.etf_liquidity;
liquidity_value=ABS(c);
drop c code;
run;
proc sql;
create table work.average_etf_liquidity as select year,month,
mean(liquidity_value)/10000 as average_liquidity
from work.etf_liquidity group by year,month;
quit;

/*Return difference*/
data work.return_difference;
set work.etf_nav_index_monthly_adjusted;
ETF_NAV=ABS(monthly_etf_return-monthly_nav_return);
NAV_Index=ABS(monthly_nav_return-monthly_index_return_adjusted);
drop monthly_cashdiffer monthly_nav_return monthly_etf_return monthly_index_return_adjusted;
run;

/*Return difference and liquidity comparison*/
proc sql;
create table project.difference_liquidity
as select a.*, b.average_liquidity
from work.return_difference a left join work.average_etf_liquidity b
on a.year=b.year and a.month=b.month;
quit;

/*Yearly etf and nav return sorting by ETF code*/
proc sort data=work.results_etf_nav;
by year month code;
run;
proc sql;
create table work.sheet1_yearly_etf_nav as select code,year,
sum(nav_return) as yearly_nav_return,
sum(etf_return_lag) as yearly_etf_return
from work.results_etf_nav group by code,year;
quit;
data work.nonmissing_target_index_list;
set work.nonmissing_target_index_list;
symbol1=symbol*1;
drop symbol;
run;
proc sql;
create table work.sheet2_etf_index_list
as select a.symbol1,tgtindex,b.code
from work.nonmissing_target_index_list a,project.etf_nav b
where a.symbol1=b.code;
run;
proc sort data=work.sheet2_etf_index_list nodupkey;
by code tgtindex;
run;
proc sql;
create table work.sheet3_target_index_return
as select a.*, b.symbol1,tgtindex
from project.index_yearly a,work.sheet2_etf_index_list b
where a.indexcd=b.tgtindex;
run;
proc sort data=work.sheet3_target_index_return;
by symbol1 year;
run;
data work.sheet3_target_index_return;
set work.sheet3_target_index_return;
year1=year*1;
drop year;
run;
proc sql;
create table work.Yearly_etf_nav_index
as select a.*,b.symbol1,tgtindex,idxrtn
from sheet1_yearly_etf_nav a,sheet3_target_index_return b
where a.code=b.symbol1 and a.year=b.year1;
run;
data work.yearly_etf_nav_index;
set work.yearly_etf_nav_index;
drop symbol1;
run;
/*****************************************************/
/*Do regressions*/
proc reg data=work.yearly_etf_nav_index outest=work.regression_results1 noprint;
model yearly_etf_return = idxrtn;/*ETF-Index*/
by code;
run;
data work.regression_results1;
set work.regression_results1;
Coefficient_dif_etf_index=ABS(1-idxrtn);
run;
proc reg data=work.yearly_etf_nav_index outest=work.regression_results2 noprint;
model yearly_etf_return = yearly_nav_return;/*ETF-NAV*/
by code;
run;
data work.regression_results2;
set work.regression_results2;
Coefficient_dif_etf_nav=ABS(1-yearly_nav_return);
run;
proc reg data=work.yearly_etf_nav_index outest=work.regression_results3 noprint;
model yearly_nav_return = idxrtn;/*NAV-Index*/
by code;
run;
data work.regression_results3;
set work.regression_results3;
Coefficient_dif_nav_index=ABS(1-idxrtn);
run;
proc sql;
create table work.coefficient_results123
as select a.code,coefficient_dif_etf_index,b.coefficient_dif_etf_nav,c.coefficient_dif_nav_index
from work.regression_results1 a, work.regression_results2 b, work.regression_results3 c
where a.code=b.code=c.code;
run;
data work.sheet4_etf_nav_index_difference;
set work.yearly_etf_nav_index;
etf_nav_difference = yearly_etf_return-yearly_nav_return;
etf_index_difference=yearly_etf_return-idxrtn;
nav_index_difference=yearly_nav_return-idxrtn;
drop yearly_nav_return yearly_etf_return tgtindex idxrtn;
run;
proc summary data = work.sheet4_etf_nav_index_difference nway missing;
class code;
var etf_index_difference;
output out=work.std1 std=etf_index_std;
run;
proc summary data = work.sheet4_etf_nav_index_difference nway missing;
class code;
var etf_nav_difference;
output out=work.std2 std=etf_nav_std;
run;
proc summary data = work.sheet4_etf_nav_index_difference nway missing;
class code;
var nav_index_difference;
output out=work.std3 std=nav_index_std;
run;
proc sql;
create table work.Std
as select a.*, b.etf_nav_std, c.nav_index_std
from work.std1 a, work.std2 b, work.std3 c
where a.code=b.code=c.code;
run;
proc sql;
create table project.tracking_error_two_methods
as select a.*, b.code,etf_index_std,etf_nav_std,nav_index_std
from work.coefficient_results123 a, work.std b
where a.code=b.code;
run;
/****************************************************************/
/*calculate correlations between two methods*/
proc corr data=project.tracking_error_two_methods noprint
out=project.correlation;
var coefficient_dif_etf_index coefficient_dif_nav_index coefficient_dif_etf_nav etf_index_std nav_index_std etf_nav_std;
with coefficient_dif_etf_index coefficient_dif_nav_index coefficient_dif_etf_nav etf_index_std nav_index_std etf_nav_std;
run;

/******************************************************************/
/*Test other factors that could lead to tracking error*/
/**Factor1:dividend factor**/
data work.fund_dividend;
set work.fund_dividend;
symbol1 = symbol*1;
drop FundID code;
run;
proc sql;
create table work.etf_dividend
as select a.*, b.code
from work.fund_dividend a, project.etf_nav b
where a.symbol1 = b.code;
run;
data work.etf_dividend;
set work.etf_dividend;
drop  symbol symbol1 primarypaydate_dividend distributionplan;
if date=. then delete;/*only keep cash dividend*/
run;

/*Factor2:shares factor*/
data work.fund_shareschange;
set work.fund_shareschange;
symbol1 = symbol*1;
run;
data work.fund_shareschange;
set work.fund_shareschange;
if &reporttype_filter;
keep &fund_shareschange_vars;
run;
proc sql;
create table work.etf_shareschange
as select a.*, b.code
from work.fund_shareschange a, project.etf_nav b
where a.symbol1=b.code;
run;

/***********************************************************/
/*Total ETF data*/
data work.index_return;
set work.index_return;
code=symbol*1;
run;
proc sql;
create table work.monthly_cashdiffer as select code,year,month,
sum(cashdiffer) as monthly_cashdiffer
from work.index_return group by code,year,month;
quit;
proc sql;
create table work.Otherfactors_info
as select a.*,b.monthly_cashdiffer
from work.etf_liquidity a, work.monthly_cashdiffer b
where a.fundcd=b.code and a.year=b.year and a.month=b.month;
run;
proc sql;
create table work.ETF_dividend1
as select a.code,b.dividendpershare,b.year,b.month,b.code
from project.etf_nav a, work.etf_dividend b
where a.code=b.code;
run;

proc sql;
create table work.dum2
as select a.*,b.dividendpershare
from work.otherfactors_info a left join work.etf_dividend1 b
on a.fundcd=b.code and a.year=b.year and a.month=b.month;
quit;
data work.dum2;
set work.dum2;
if dividendpershare=. then dum2=0;
else dum2=1;
drop dividendpershare;
run;
data work.etf_bigdeal;
set work.etf_shareschange;
year=year(startdate1);
month=month(startdate1);
if totalpurchasefundshare=. then totalpurchasefundshare=0;
if totalredemptionfundshare=. then totalredemptionfundshare=0;
changeratio=ABS(totalpurchasefundshare-totalredemptionfundshare)/totalbeginningfundshare;
drop symbol totalbeginningfundshare totalpurchasefundshare totalredemptionfundshare enddateshares symbol1;
run;
data work.dum1;
set work.etf_bigdeal;
if changeratio>=0.1 then dum1=1;
else dum1=0;
drop reporttypeID startdate1 enddate1;
run;
proc sql;
create table work.ETF_shareschange1
as select a.*,b.dum1
from work.dum2 a left join work.dum1 b
on a.fundcd=b.code and a.year=b.year and a.month=b.month;
run;
data work.ETF_information;
set work.ETF_shareschange1;
by fundcd year month;
retain dum11;
if first.fundcd then
do;
dum11=dum1;
end;
else
do;
if missing(dum1) then dum1=dum11;
else dum11=dum1;
end;
drop dum11;
run;
proc sql;
create table work.monthly_etf_nav_return as select code,year,month,
sum(nav_return) as monthly_nav_return,
sum(etf_return_lag) as monthly_etf_return
from work.results_etf_nav group by code,year,month;
quit;
proc sql;
create table work.monthly_etf_nav_index_return
as select a.*,b.code,b.idxrtn
from work.monthly_etf_nav_return a,work.index_return b
where a.code=b.code and a.year=b.year and a.month=b.month;
run;
proc sort data=work.monthly_etf_nav_index_return nodupkey;
by code year month;
run;
data work.ETF_tracking_error;
set work.monthly_etf_nav_index_return;
etf_index=ABS(monthly_etf_return-idxrtn);
etf_nav=ABS(monthly_etf_return-monthly_nav_return);
nav_index=ABS(monthly_nav_return-idxrtn);
drop monthly_etf_return monthly_nav_return idxrtn;
run;
proc sql;
create table project.other_factor_regression_data
as select a.*,b.liquidity_value,b.monthly_cashdiffer,b.dum1,b.dum2
from work.ETF_tracking_error a, work.ETF_information b
where a.code=b.fundcd and a.year=b.year and a.month=b.month;
run;
proc sort data=project.other_factor_regression_data;
by year month code;
run;



/*data for Granger test*/
proc sql;
create table work.granger1 as select code,year,month,
sum(nav_return) as nav_monthly_return,
sum(etf_return_lag) as etf_monthly_return
from work.results_etf_nav group by code,year,month;
quit;
data work.index_return;
set work.index_return;
code=symbol*1;
drop symbol;
run;
proc sql;
create table work.granger2
as select a.*, b.idxrtn
from work.granger1 a, work.index_return b
where a.code=b.code and a.year=b.year and a.month=b.month;
run;
proc sort data=work.granger2 nodupkey;
by year month code;
run;
proc reg data=work.granger2 outest=work.granger_results1 noprint;
model etf_monthly_return = idxrtn;/*ETF-Index*/
by year month;
run;
data work.granger_results1;
set work.granger_results1;
Coefficient_dif_etf_index=ABS(1-idxrtn);
run;
proc reg data=work.granger2 outest=work.granger_results2 noprint;
model etf_monthly_return = nav_monthly_return;/*ETF-NAV*/
by year month;
run;
data work.granger_results2;
set work.granger_results2;
Coefficient_dif_etf_nav=ABS(1-nav_monthly_return);
run;
proc reg data=work.granger2 outest=work.granger_results3 noprint;
model nav_monthly_return = idxrtn;/*NAV-Index*/
by year month;
run;
data work.granger_results3;
set work.granger_results3;
Coefficient_dif_nav_index=ABS(1-idxrtn);
run;
proc sql;
create table work.granger_results123
as select a.year,a.month, a.coefficient_dif_etf_index,b.coefficient_dif_etf_nav,c.coefficient_dif_nav_index
from work.granger_results1 a, work.granger_results2 b, work.granger_results3 c
where a.year=b.year=c.year and a.month=b.month=c.month;
run;
proc sql;
create table work.granger3
as select a.*, b.average_liquidity
from work.granger_results123 a, work.average_etf_liquidity b
where a.year=b.year and a.month=b.month;
run;
data work.granger2;
set work.granger2;
etf_nav_difference=ABS(etf_monthly_return-nav_monthly_return);
etf_index_difference=ABS(etf_monthly_return-idxrtn);
nav_index_difference=ABS(nav_monthly_return-idxrtn);
drop nav_monthly_return etf_monthly_return idxrtn;
run;
