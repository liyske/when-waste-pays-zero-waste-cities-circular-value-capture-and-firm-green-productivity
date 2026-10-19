*==============================================================================
* replication.do
* Replication code for "When Waste Pays: Zero-Waste Cities, Circular Value
* Capture, and Firm Green Productivity" (submission to Energy Economics)
*
* Data: replication_data.dta, firm-year panel of Chinese A-share listed firms,
*       2010-2023, 36,010 observations (English variable names and labels)
* Software: Stata 19.5. User-written commands:
*   ssc install ftools
*   ssc install reghdfe
*   ssc install estout
*   ssc install outreg2
*   ssc install logout
*   ssc install coefplot
*   ssc install didplacebo, all replace
*   ssc install twowayfeweights
*   ssc install did_imputation
*   ssc install event_plot
*   ssc install psmatch2
*   ssc install bdiffv
*   ssc install ddml
*   ssc install pystacked      (needs Python with scikit-learn: help python)
*   net install ddtiming, from(https://raw.githubusercontent.com/tgoldring/ddtiming/master)
* Tables, figures and other output files are written to the folder set by cd.
* Comments are in Chinese with English translations. Output files with Chinese names (meaning, result):
*   描述性统计二 descriptive statistics (Table 1); 基准回归 baseline regressions (Table 2)
*   机器学习, 梯度提升, 机器学习4, 堆叠dml, 交互式模型: machine learning (random forest), gradient boosting,
*     machine learning 4 (elastic net), stacked DML, interactive model (Table 6, columns 1-5)
*   排除宏观因素 excluding macro-level factors (Table 3); 匹配前后比较表, 匹配前后比较表2 before/after matching (Table 4)
*   绿色专利 green patents (Table 9); 绿色创新分固废 green innovation by solid-waste type (Table 10)
*   固废投资分行业 solid-waste investment by industry (Table 11); 循环经济 circular economy (Table 12)
*   进一步分析 further analysis (Table 7, columns 1-2); 异质性分组2 heterogeneity groups 2 (Table 7, columns 5-6)
* outreg2 addtext() labels: 控制变量一次项 controls (linear terms), 控制变量二次项 controls (squared terms),
*   时间固定效应 year fixed effects, 个体固定效应 firm fixed effects
*==============================================================================

clear all
set more off
global data "E:/review/EE_submission/data_and_do/replication_data.dta"
cd "E:/review/EE_submission/data_and_do"


* 清理数据并设置面板结构 / Clean the data and set the panel structure
use "$data",clear
xtset id year

//储存全局变量 / Store variable lists as globals
global all gp did size assetgrowth der pb top10 quick roa cl capex itr tmtpay economic finance gov

global var4 size assetgrowth der pb top10 quick roa cl capex itr tmtpay economic finance gov


*描述性统计 / Descriptive statistics
tabstat $all, stat(N mean sd  min p50 max) f(%6.2f) c(s)
logout, save(描述性统计二) word replace: tabstat $all, stat(N mean sd min p50 max) f(%6.2f) c(s)


// 1. 仅按年份(year)分组，计算全国所有企业每年 gp 的平均值
// 1. Group by year only and compute the mean of gp over all firms nationwide in each year
collapse (mean) mean_gml = gp, by(year)

// 2. 将数据设定为时间序列格式（因为现在只有年份，没有个体id了）
// 2. Declare the data a time series (only years remain; there is no firm id any more)
tsset year

// 3. 计算全国每年的绝对增加量（当年均值 - 去年均值）
// 3. Absolute annual change of the national mean (this year's mean - last year's mean)
gen inc_gml = D.mean_gml

// 4. 计算全国每年的增加百分比（(绝对增加量 / 去年均值) * 100）
// 4. Annual percentage change of the national mean ((absolute change / last year's mean) * 100)
gen pct_inc_gml = (inc_gml / L.mean_gml) * 100

// 5. 设置数据格式与标签 / 5. Set display formats and labels
format mean_gml inc_gml pct_inc_gml %9.4f
label var mean_gml "National mean of GP"
label var inc_gml "Change from previous year"
label var pct_inc_gml "Growth from previous year (%)"

// 6. 打印全国历年具体的增长明细 / 6. List the national year-by-year changes
disp ""
disp ">>> 全国企业历年 GML指数 增长明细 / Year-by-year change in the GML index, all firms <<<"
list year mean_gml inc_gml pct_inc_gml, noobs

* ----------------------------------------------------------------------
* 7. 计算"无废城市"政策启动后的全国平均表现
* 7. National average after the launch of the "zero-waste city" policy
* 注意：这里以 2019 年作为政策启动年份为例，请根据你的具体设定修改！
* Note: 2019 is taken here as the year the policy was launched; change it if your setting differs.
* ----------------------------------------------------------------------
disp ""
disp ">>> '无废城市'政策启动后 (假定为2019年及以后) 全国平均增加量与增长率 / National average annual change and growth rate after the zero-waste-city launch (2019 onward) <<<"
tabstat inc_gml pct_inc_gml if year >= 2019, stat(mean) format(%9.4f)
* ======================================================================
* 分组计算处理组(treat=1)和对照组(treat=0) gp 的年均增加量和增长率
* Average annual change and growth rate of gp, separately for the treatment group (treat=1) and the control group (treat=0)
* ======================================================================
use "$data",clear

// 1. 按处理组(treat)和年份(year)分组，计算每年 gp 的平均值
// 1. Group by treatment status (treat) and year and compute the annual mean of gp
collapse (mean) mean_gml = gp, by(treat year)

// 2. 将数据设定为面板格式（以 treat 为个体，year 为时间）
// 2. Declare the data a panel (treat as the panel unit, year as time)
xtset treat year

// 3. 计算每年的绝对增加量（当年均值 - 去年均值）
// 3. Absolute annual change (this year's mean - last year's mean)
// 使用 D. 算子表示一阶差分 / The D. operator takes the first difference
gen inc_gml = D.mean_gml

// 4. 计算每年的增加百分比（(绝对增加量 / 去年均值) * 100）
// 4. Annual percentage change ((absolute change / last year's mean) * 100)
// 使用 L. 算子表示滞后一期 / The L. operator takes the one-period lag
gen pct_inc_gml = (inc_gml / L.mean_gml) * 100

// 5. 设置数据格式，保留4位小数，并添加标签以便阅读
// 5. Display four decimals and add labels for readability
format mean_gml inc_gml pct_inc_gml %9.4f
label var mean_gml "Mean of GP"
label var inc_gml "Change from previous year"
label var pct_inc_gml "Growth from previous year (%)"

// 6. 在结果窗口打印每组、每年的具体变化情况
// 6. List the changes by group and year in the Results window
disp ""
disp ">>> 每年处理组与对照组的具体增长情况 / Annual change, treatment vs control group <<<"
list treat year mean_gml inc_gml pct_inc_gml, sepby(treat) noobs

// 7. 计算处理组和对照组在整个样本期内的"总体平均"每年增加量和增长率
// 7. Overall average annual change and growth rate of each group over the whole sample period
disp ""
disp ">>> 处理组与对照组：总体平均每年增加量与平均增长率 / Treatment vs control: average annual change and average growth rate <<<"
tabstat inc_gml pct_inc_gml, by(treat) stat(mean) format(%9.4f)



use "$data",clear
xtset id year
*基础回归 / Baseline regressions
reg gp did  ,vce(cluster citycode)
est store m1 // 将上述结果储存与m1 / store the results above as m1
reghdfe gp did  $var4 ,vce(cluster citycode)
est store m2
reghdfe gp did  $var4 ,a(id year) vce(cluster citycode)
est store m3
// a(id year)表示控制个体和时间固定效应；vce(cluster id)聚类到个体层面的稳健标准误
// a(id year) absorbs firm and year fixed effects; vce(cluster id) clusters robust standard errors by firm [the regressions above use vce(cluster citycode), i.e. clustering by city]
esttab m1 m2 m3, scalar(N r2) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" "GTFP" "GTFP") ///
    addnotes("Notes: Year and id fixed effects are included.")

* Save to RTF file
esttab m1 m2 m3 using 基准回归.rtf, replace ///
    scalar(N r2 F) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" "GTFP" "GTFP") ///
    addnotes("Notes: Year and id fixed effects are included.")
//将上述m1和m2结果，以word的形式导出；b(%6.4f) se(%6.4f)，系数和标准误保留4位小数
// Export the m1 and m2 results above in Word format; b(%6.4f) se(%6.4f) report coefficients and standard errors to four decimals [the esttab call above exports m1-m3 to RTF]


gen pd=year-first_treat
tab pd
replace pd=-6 if pd<-6
//平行趋势 / Parallel trends
forvalues i = 6(-1)1{
	gen pre_`i'=(pd==-`i'& treat==1)
}
gen current =(pd==0&treat==1)
forvalues j = 1(1)4{
	gen las_`j'=(pd==`j'& treat==1)
}

drop pre_1
gen pre_1=0

//平行趋势检验回归 / Event-study regression for the parallel-trends test
reghdfe gp  pre_6 pre_5 pre_4 pre_3 pre_2 current las_1 las_2 las_3 las_4 pre_1 $var4 ,a(id year) vce(cluster citycode)

//平行趋势检验图 / Parallel-trends plot: Figure 1, Dynamic Effects (all text in Times New Roman)
local f "Times New Roman"
coefplot, baselevels omitted keep(pre* current las*) vertical order(pre_6 pre_5 pre_4 pre_3 pre_2 pre_1 current las_1 las_2 las_3 las_4) ///
    msymbol(O) mcolor(black) msize(medium) ciopts(recast(rcap) lcolor(black) lpattern(dash) lwidth(medium)) yline(0, lpattern(solid) lcolor(black)) xline(6, lpattern(solid) lcolor(black)) ///
    xlabel(1 `"{fontface "`f'":-6}"' 2 `"{fontface "`f'":-5}"' 3 `"{fontface "`f'":-4}"' 4 `"{fontface "`f'":-3}"' 5 `"{fontface "`f'":-2}"' 6 `"{fontface "`f'":-1}"' 7 `"{fontface "`f'":0}"' 8 `"{fontface "`f'":1}"' 9 `"{fontface "`f'":2}"' 10 `"{fontface "`f'":3}"' 11 `"{fontface "`f'":4}"', labsize(4.4)) ///
    ylabel(-0.005 `"{fontface "`f'":-0.005}"' 0 `"{fontface "`f'":0}"' 0.005 `"{fontface "`f'":0.005}"' 0.01 `"{fontface "`f'":0.01}"', angle(0) labsize(4.4) grid glcolor(gs13) glpattern(dash)) ///
    xtitle(`"{fontface "`f'":Years relative to policy implementation}"', size(large)) ytitle(`"{fontface "`f'":Policy effect}"', size(large)) xscale(titlegap(1)) yscale(titlegap(-1.5)) ///
    graphregion(color(white) margin(l=1.5 r=2 t=1 b=1)) plotregion(color(white)) scheme(stcolor) name(Figure_1, replace)
graph save Figure_1 "Figure_1.gph", replace
graph export "Figure_1.png", name(Figure_1) width(7500) replace



//稳健性检验 / Robustness checks
//双重机器学习 / Double/debiased machine learning (DML)
* ddml/pystacked call Python with scikit-learn. With Stata/MP on Windows use a Python whose NumPy is not MKL-based
* (e.g. a python.org Python with pip packages), set via: set python_exec "path\to\python.exe". Anaconda's MKL build aborts with "OMP: Error #15".
use "$data",clear
xtset id year
**// 定义你的变量列表 / Define the variable list
local varlist size assetgrowth der pb top10 quick roa cl capex itr tmtpay economic finance gov
// 使用foreach循环生成二次项 / Generate squared terms in a foreach loop
foreach var of local varlist {
    gen `var'2 = `var'^2
}
**
global Y gp
global X size assetgrowth der pb top10 quick roa cl capex itr tmtpay size2 assetgrowth2 der2 pb2 top102 quick2 roa2 cl2 capex2 itr2 tmtpay2 economic2 finance2 gov2  i.id i.year
global D did

set seed 42   //随机种子数 / random seed
ddml init partial, kfolds(5)    //部分线性模型 k=5 1:4 / partially linear model, k = 5 folds (1:4 split)
ddml E[D|X]: pystacked $D $X, type(reg) method(rf)  //随机森林 / random forest
ddml E[Y|X]: pystacked $Y $X, type(reg) method(rf)
ddml crossfit
ddml estimate, robust cluster(citycode)
est store A1
outreg2 [ A1  ] using 机器学习.xlsx , replace bdec(4) rdec(4)  addtext(控制变量一次项,YES,控制变量二次项,YES,时间固定效应, YES,个体固定效应,YES)
esttab A1 , scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")

ddml E[D|X]: pystacked $D $X, type(reg) method(gradboost)  //梯度提升 / gradient boosting
ddml E[Y|X]: pystacked $Y $X, type(reg) method(gradboost)
ddml crossfit
ddml estimate, robust cluster(citycode)
est store A2
outreg2 [ A2  ] using 梯度提升.xlsx , replace bdec(4) rdec(4)  addtext(控制变量一次项,YES,控制变量二次项,YES,时间固定效应, YES,个体固定效应,YES)
esttab A2 , scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")

ddml E[D|X]: pystacked $D $X, type(reg) method(elasticcv)  //弹性网络 / elastic net
ddml E[Y|X]: pystacked $Y $X, type(reg) method(elasticcv)
ddml crossfit
ddml estimate, robust cluster(citycode)
est store A4
outreg2 [ A4  ] using 机器学习4.xlsx , replace bdec(4) rdec(4)  addtext(控制变量一次项,YES,控制变量二次项,YES,时间固定效应, YES,个体固定效应,YES)

esttab A4, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP") ///
    addnotes("Notes: Year and id fixed effects are included.")

***堆叠dml  stacking / Stacked DML
ddml init partial, kfolds(5)
ddml E[Y|X]: pystacked $Y $X , type(reg) methods(gradboost)
ddml E[Y|X]: pystacked $Y $X , type(reg) methods(rf)
ddml E[Y|X]: pystacked $Y $X , type(reg) methods(lassocv)
ddml E[D|X]: pystacked $D $X , type(reg) methods(gradboost)
ddml E[D|X]: pystacked $D $X , type(reg) methods(rf)
ddml E[D|X]: pystacked $D $X , type(reg) methods(lassocv)
ddml crossfit
ddml estimate, robust allcombos
est store A5
outreg2 [ A5  ] using 堆叠dml.xlsx , replace bdec(4) rdec(4)  addtext(控制变量一次项,YES,控制变量二次项,YES,时间固定效应, YES,个体固定效应,YES)
esttab A5, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP") ///
    addnotes("Notes: Year and id fixed effects are included.")

//交互式模型 宽泛 / Interactive model (broad specification)
clear
use "$data",clear
* size is already ln(total assets); roa and tmtpay are the roa1 and tmtpay2 of the earlier run
local varlist size assetgrowth der pb top10 quick roa cl capex itr tmtpay
foreach var of local varlist {
    gen `var'2 = `var'^2
}
global Y gp
global X size assetgrowth der pb top10 quick roa cl capex itr tmtpay size2 assetgrowth2 der2 pb2 top102 quick2 roa2 cl2 capex2 itr2 tmtpay2  i.id i.year
global D did
set seed 42

ddml init interactive, kfolds(5)
ddml E[Y|X,D]: pystacked $Y $X, type(reg) method(gradboost)
ddml E[D|X]: pystacked $D $X, type(reg) method(gradboost)
ddml crossfit
ddml estimate, robust cluster(citycode)
est store A6
outreg2 [ A6  ] using 交互式模型.xlsx , replace bdec(4) rdec(4)  addtext(控制变量一次项,YES,控制变量二次项,YES,时间固定效应, YES,个体固定效应,YES)
esttab A6, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP") ///
    addnotes("Notes: Year and id fixed effects are included.")


use "$data",clear
xtset id year
reghdfe gp did $var4 ,a(id year) vce(cluster citycode)
estimates store did_bbb  // 将上述回归结果存储为did_bbb / store the regression above as did_bbb
local b = _b[did]
local blab = strtrim(string(`b', "%6.4f"))
**空间安慰剂检验 / Spatial placebo test
didplacebo did_bbb, treatvar(did) pbounit rep(1000) seed(6) frame(pbo_unit) nofigure // rep(1000)表示重复1000次，选择项seed(1)指定随机种子为 1(使用相同随机种子可保证结果可复现)
// rep(1000) runs 1,000 replications; seed(1) would set the random seed to 1 (the same seed makes the results reproducible) [this call uses seed(6)]
**混合安慰剂检验 / Mixed placebo test
didplacebo did_bbb, treatvar(did) pbomix(3) rep(1000) seed(3) frame(pbo_mix) nofigure // pbomix()中，2表示无约束混合安慰剂检验；3表示有约束混合安慰剂检验；1表示标准DID的混合安慰剂检验
// In pbomix(), 2 = unconstrained mixed placebo test, 3 = constrained mixed placebo test, 1 = mixed placebo test for a standard DID

* Figure 2: Spatial Placebo Test (titles and legend in Times New Roman, tick labels in Microsoft YaHei)
* The last x tick sits at the baseline estimate (solid line) and is labelled 0.0037
local f "Times New Roman"
local n "Microsoft YaHei"
frame pbo_unit {
    summarize CoefOfPboUnit, meanonly
    local xmax = max(abs(r(min)), abs(r(max)), abs(`b'))
    twoway (kdensity CoefOfPboUnit, lcolor(black) lwidth(medthick)) (histogram CoefOfPboUnit, fcolor(gs14) lcolor(black) lwidth(thin) lalign(center) below), ///
        xline(0, lpattern(dash) lcolor(black)) xline(`b', lpattern(solid) lcolor(black)) xscale(range(-`xmax' `xmax') titlegap(1.5)) yscale(titlegap(0)) ///
        xlabel(-0.004 `"{fontface "`n'":-0.004}"' -0.002 `"{fontface "`n'":-0.002}"' 0 `"{fontface "`n'":0}"' 0.002 `"{fontface "`n'":0.002}"' `b' `"{fontface "`n'":`blab'}"', labsize(4.2) grid glcolor(gs13) glpattern(dash)) ///
        ylabel(0 `"{fontface "`n'":0}"' 200 `"{fontface "`n'":200}"' 400 `"{fontface "`n'":400}"' 600 `"{fontface "`n'":600}"', labsize(4.2) angle(0) grid glcolor(gs13) glpattern(dash)) ///
        xtitle(`"{fontface "`f'":Distribution of placebo estimates}"', size(4.4)) ytitle(`"{fontface "`f'":Density}"', size(4.4)) ///
        legend(order(1 `"{fontface "`f'":Kernel density estimate}"' 2 `"{fontface "`f'":Histogram}"') position(6) rows(1) size(4.2) symxsize(10) keygap(3) colgap(10)) ///
        graphregion(color(white) margin(l=0.3 r=7 t=2.4 b=2)) plotregion(color(white) margin(l=0 r=0)) scheme(stcolor) name(Figure_2, replace)
}
graph save Figure_2 "Figure_2.gph", replace
graph export "Figure_2.png", name(Figure_2) width(7500) replace

* Figure 3: Mixed Placebo Test (all text in Times New Roman)
local f "Times New Roman"
frame pbo_mix {
    summarize CoefOfPboMix3, meanonly
    local xmax = max(abs(r(min)), abs(r(max)), abs(`b'))
    twoway (kdensity CoefOfPboMix3, lcolor(black) lwidth(medthick)) (histogram CoefOfPboMix3, fcolor(gs14) lcolor(black) lwidth(thin) lalign(center) below), ///
        xline(0, lpattern(dash) lcolor(black)) xline(`b', lpattern(solid) lcolor(black)) xscale(range(-`xmax' `xmax') titlegap(1.5)) yscale(titlegap(0)) ///
        xlabel(-0.003 `"{fontface "`f'":-0.003}"' -0.002 `"{fontface "`f'":-0.002}"' -0.001 `"{fontface "`f'":-0.001}"' 0 `"{fontface "`f'":0}"' 0.001 `"{fontface "`f'":0.001}"' 0.002 `"{fontface "`f'":0.002}"' `b' `"{fontface "`f'":`blab'}"', labsize(4.2) grid glcolor(gs13) glpattern(dash)) ///
        ylabel(0 `"{fontface "`f'":0}"' 200 `"{fontface "`f'":200}"' 400 `"{fontface "`f'":400}"' 600 `"{fontface "`f'":600}"' 800 `"{fontface "`f'":800}"', labsize(4.2) angle(0) grid glcolor(gs13) glpattern(dash)) ///
        xtitle(`"{fontface "`f'":Distribution of placebo estimates}"', size(4.4)) ytitle(`"{fontface "`f'":Density}"', size(4.4)) ///
        legend(order(1 `"{fontface "`f'":Kernel density estimate}"' 2 `"{fontface "`f'":Histogram}"') position(6) rows(1) size(4.2) symxsize(10) keygap(3) colgap(10)) ///
        graphregion(color(white) margin(l=1.2 r=6 t=2.4 b=2)) plotregion(color(white) margin(r=0)) scheme(stcolor) name(Figure_3, replace)
}
graph save Figure_3 "Figure_3.gph", replace
graph export "Figure_3.png", name(Figure_3) width(7500) replace




//增加固定效应 / Additional fixed effects
reghdfe gp did  $var4 ,a(id Ind#year year) vce(cluster citycode)
est store C1
reghdfe gp did  $var4 ,a(id citycode#Ind year) vce(cluster citycode)
est store C2
reghdfe gp did  $var4 ,a(id year Ind#year citycode#Ind) vce(cluster citycode)
est store C3
reghdfe gp did envtax_did $var4 ,a(id year) vce(cluster citycode)
est store C4
reghdfe gp did climate_city_pilot $var4 ,a(id year) vce(cluster citycode)
est store C5
reghdfe gp did low_carbon $var4 ,a(id year) vce(cluster citycode)
est store C6
reghdfe gp did envtax_did   climate_city_pilot  low_carbon  $var4 ,a(id year) vce(cluster citycode)
est store C7

esttab C1 C2 C3 C4 C5 C6 C7, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" "GTFP" "GTFP" "GTFP" "GTFP" "GTFP") ///
    addnotes("Notes: Year and id fixed effects are included.")


* Save to RTF file
esttab C1 C2 C3 C4 C5 C6 C7 using 排除宏观因素.rtf, replace ///
    scalar(N r2_a F) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" "GTFP" "GTFP" "GTFP" "GTFP" "GTFP") ///
    addnotes("Notes: Year and id fixed effects are included.")



*常见的异质性处理效应检验 / Common tests for heterogeneous treatment effects
**Goodman-Bacon分解检验 / Goodman-Bacon decomposition
use "$data",clear
xtset id year
ddtiming gp did,i(id) t(year) xlabel(,nogrid) ylabel(,nogrid) legend(position(6))

**de Chaisemartin & D'Haultfoeuille 分解 / de Chaisemartin & D'Haultfoeuille decomposition
twowayfeweights gp id year did,type(feTR) controls($var4)


**Borusyak检验及绘图(这里如果做不出来，需要更新一下stata版本和reghdfe这个口令，ssc install reghdfe,replace)
** Borusyak et al. imputation estimator and plot (if this step fails, update Stata and reghdfe: ssc install reghdfe, replace)
did_imputation gp id year first_treat,allhorizons pre(6) autosample controls($var4) fe(id year) cluster(citycode) tol(1) maxit(100)
* Figure 4: Dynamic Effects Using Borusyak et al. (2024) (all text in Arial); leads and lags in one series with 95% confidence intervals
local f "Arial"
event_plot, plottype(scatter) ciplottype(rcap) together lag_opt(msymbol(O) mcolor(black) msize(small)) lag_ci_opt(lcolor(gs8) lpattern(dash)) ///
    graph_opt(legend(off) xline(-1, lcolor(black) lpattern(solid)) yline(0, lcolor(black) lpattern(solid)) ///
    xlabel(-6 `"{fontface "`f'":-6}"' -5 `"{fontface "`f'":-5}"' -4 `"{fontface "`f'":-4}"' -3 `"{fontface "`f'":-3}"' -2 `"{fontface "`f'":-2}"' -1 `"{fontface "`f'":-1}"' 0 `"{fontface "`f'":0}"' 1 `"{fontface "`f'":1}"' 2 `"{fontface "`f'":2}"' 3 `"{fontface "`f'":3}"' 4 `"{fontface "`f'":4}"', nogrid) ///
    ylabel(-0.005 `"{fontface "`f'":-0.005}"' 0 `"{fontface "`f'":0}"' 0.005 `"{fontface "`f'":0.005}"' 0.01 `"{fontface "`f'":0.01}"', angle(horizontal)) xscale(lpattern(dash) titlegap(2.3)) ///
    xtitle(`"{fontface "`f'":Years relative to policy implementation}"', size(medlarge)) ytitle(`"{fontface "`f'":Policy effect}"', size(medlarge)) ///
    graphregion(color(white)) bgcolor(white) scheme(stcolor) name(Figure_4, replace))
graph save Figure_4 "Figure_4.gph", replace
graph export "Figure_4.png", name(Figure_4) width(7500) replace
did_imputation gp id year first_treat,autosample controls($var4) fe(id year) cluster(citycode) tol(1) maxit(100) // 总估计量值 / overall estimate




*PSM-DID检验 / PSM-DID
use "$data",clear
xtset id year
//设置种子词 / Set the random seed
set seed 10101
gen ranorder=runiform()
sort ranorder
psmatch2 treat $var4 ,outcome(gp) n(3) ate ties logit common
//匹配后回归 / Regression on the matched sample
reghdfe gp did  $var4 if _weight!=.,a(id year) vce(cluster citycode)
est store O2
esttab  O2 , scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")

* Save to RTF file
esttab  O2 using 匹配前后比较表.rtf, replace ///
    scalar(N r2_a F) star(* 0.10 ** 0.05 *** 0.01) b(%6.3f) se(%6.3f) ///
    label nogap ///
    mtitles("GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")




*核匹配 / Kernel matching
use "$data",clear
psmatch2 treat $var4 ,outcome(gp) kernel ate ties logit common
reghdfe gp did $var4 if _weight!=.,a(id year) vce(cluster citycode)
est store Y2
esttab Y2 , scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")

**逐期匹配 / Period-by-period matching
use "$data",clear
xtset id year
forvalue i=2010/2023{
	preserve
	capture{
		keep if year==`i'
		set seed 10101
		gen norvar_2=rnormal()
		sort norvar_2
		psmatch2 treat $var4 ,outcome(gp) n(3) ate ties logit common
		save `i'.dta,replace
	}
	restore
}
clear all
use 2010.dta,clear
forvalue k=2011/2023{
	capture{
		append using `k'.dta
	}
}
reghdfe gp did $var4 if _weight!=.,a(id year) vce(cluster citycode)
est store Y2
esttab Y2 , scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")

* Save to RTF file
esttab Y2 using 匹配前后比较表2.rtf, replace ///
    scalar(N r2_a F) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")



*机制分析 / Mechanism analysis
use "$data",clear
xtset id year
//绿色专利 / Green patents
reghdfe gi did  $var4 ,a(id year) vce(cluster citycode)
est store i1
reghdfe origin did $var4 ,a(id year) vce(cluster citycode)
est store i2
reghdfe terminal did $var4 ,a(id year) vce(cluster citycode)
est store i3
reghdfe  solid   did    $var4 , a(id year) vce(cluster citycode)
est store i4

esttab i1 i2 i3 i4 , scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GP"  "origin"  "terminal" "Soild") ///
    addnotes("Notes: Year and id fixed effects are included.")

esttab i1 i2 i3 i4  using 绿色专利.rtf, replace ///
    scalar(N r2_a F) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GP"  "origin"  "terminal" "Soild") ///
    addnotes("Notes: Year and id fixed effects are included.")



* mc, house and agri are stored in the dataset; the lines below rebuild them from the industry lists (Appendix C), giving identical values
* ====================== 工业建筑固废治理行业 ======================
* ====================== Industrial and construction solid-waste management industries ======================
replace mc = 0

* ---- (1) 采矿业：金属及非金属矿采选（尾矿、废石） ----
* ---- (1) Mining: metal and non-metal ore mining and dressing (tailings, waste rock) ----
replace mc = 1 if inlist(industry1, "B08", "B09", "B10")

* ---- (2) 重化工及冶金制造业（工业废渣、冶炼渣、化工废料） ----
* ---- (2) Heavy chemical and metallurgical manufacturing (industrial residue, smelting slag, chemical waste) ----
replace mc = 1 if inlist(industry1, "C25", "C26", "C27", "C28", "C29", "C30", "C31", "C32", "C33")

* ---- (3) 轻工制造业（纺织印染污泥、造纸废渣、印刷废料） ----
* ---- (3) Light manufacturing (textile printing and dyeing sludge, papermaking residue, printing waste) ----
replace mc = 1 if inlist(industry1, "C17", "C22", "C23")

* ---- (4) 装备与高技术制造业（环保设备、电子废弃物、精密制造废料） ----
* ---- (4) Equipment and high-tech manufacturing (environmental equipment, electronic waste, precision-manufacturing scrap) ----
replace mc = 1 if inlist(industry1, "C34", "C35", "C36", "C39", "C40")

* ---- (5) 废弃资源综合利用 ----
* ---- (5) Comprehensive utilization of waste resources ----
replace mc = 1 if inlist(industry1, "C42")

* ---- (6) 电力热力与水（粉煤灰、脱硫石膏、污水污泥） ----
* ---- (6) Electricity, heat and water (fly ash, desulfurization gypsum, sewage sludge) ----
replace mc = 1 if inlist(industry1, "D44", "D46")

* ---- (7) 建筑业（建筑垃圾、拆除废料、装修废弃物） ----
* ---- (7) Construction (construction waste, demolition waste, renovation waste) ----
replace mc = 1 if inlist(industry1, "E47", "E48", "E49", "E50")

* ---- (8) 生态保护和环境治理业（固废处置、填埋、焚烧） ----
* ---- (8) Ecological protection and environmental management (solid-waste disposal, landfill, incineration) ----
replace mc = 1 if inlist(industry1, "N77")

* ---- (9) 技术服务端（环评检测、固废技术研发与推广） ----
* ---- (9) Technical services (environmental impact assessment and testing, R&D and diffusion of solid-waste technology) ----
replace mc = 1 if inlist(industry1, "M73", "M74", "M75")

* ---- (10) 产业链关联端（废旧物资批发、环保信息化、房地产开发建筑垃圾） ----
* ---- (10) Linked industries along the chain (wholesale of scrap materials, environmental IT, construction waste from real-estate development) ----
replace mc = 1 if inlist(industry1, "F51", "I65", "K70")



* ====================== 2. 生活垃圾治理行业  ======================
* ====================== 2. Household waste management industries  ======================
replace house = 0
*生活垃圾产生端 / Industries generating household waste
replace house = 1 if inlist(industry1, "C38","C13","C14","C15","C16","C17","C18","C19","C21")
replace house = 1 if inlist(industry1, "C20", "C22","C23","C24","C29","C38","C39")
replace house = 1 if inlist(industry1, "E50","F51", "F52","H61","H62","L71")
* 环保服务端 / Environmental services
replace house = 1 if inlist(industry1, "N77", "D46", "N78","C42")
* 设备与运输端 / Equipment and transport
replace house = 1 if inlist(industry1, "G54")
* 工程建设端 / Engineering and construction
replace house = 1 if inlist(industry1, "E48")
* 关联产业端 / Related industries
replace house = 1 if inlist(industry1, "D44", "C30")
* 技术服务重叠端 / Technical services (overlapping categories)
replace house = 1 if inlist(industry1, "M74", "I65")



* ====================== 3. 农业垃圾治理行业   ======================
* ====================== 3. Agricultural waste management industries   ======================
replace agri = 0
* 农业生产端 / Agricultural production
replace agri = 1 if inlist(industry1, "C13", "A03", "A01","A02","A04","A05")
* 化工与能源端 / Chemicals and energy
replace agri = 1 if inlist(industry1, "G54")
* 工程与设备端 / Engineering and equipment
replace agri = 1 if inlist(industry1, "C35")
* 公共服务重叠端 / Public services (overlapping categories)
replace agri = 1 if inlist(industry1, "N77", "D46", "N78", "M73", "M74","M75", "I65")



* 进行回归 / Regressions
reghdfe solid_mc  did   $var4 , a(id year) vce(cluster citycode)
est store k2

reghdfe solid_h did     $var4  , a(id year) vce(cluster citycode)
est store k3

reghdfe solid_a did     $var4 , a(id year) vce(cluster citycode)
est store k4

reghdfe solid_mc did   i.mc##i.did   $var4 , a(id year) vce(cluster citycode)
est store k5

reghdfe solid_h  did  i.house##i.did   $var4  , a(id year) vce(cluster citycode)
est store k6

reghdfe solid_a did   i.agri##i.did  $var4 , a(id year) vce(cluster citycode)
est store k7



esttab k2 k3 k4 k5 k6 k7  , scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("2" "3"  "4" "5" "6" "7" ) ///
    addnotes("Notes: Year and id fixed effects are included.")
* Save to RTF file
esttab k2 k3 k4 k5 k6 k7  using 绿色创新分固废.rtf, replace ///
    scalar(N r2_a F) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("2" "3"  "4" "5" "6" "7" ) ///
    addnotes("Notes: Year and id fixed effects are included.")


//绿色投资 / Green investment (GFA3, SWA3 and GInvest_M3/H3/A3 are stored in the dataset; the lines below rebuild them with identical values)
replace GFA3 = green_fixed_assets/total_revenue

replace SWA3 = solidwaste_digital_assets/total_revenue

replace GInvest_M3 = inv_mc_waste/total_revenue

replace GInvest_H3 = inv_household_waste/total_revenue

replace GInvest_A3 = inv_agri_waste/total_revenue


reghdfe   GFA3      did   $var4  ,a(id year) vce(cluster citycode)
est store k1
reghdfe   SWA3      did   $var4  ,a(id year) vce(cluster citycode)
est store k2



esttab k1 k2, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("9" "10") ///
    addnotes("Notes: Year and id fixed effects are included.")

//固废投资分行业 / Solid-waste investment by industry
reghdfe GInvest_M3  did    $var4  ,a(id year) vce(cluster citycode)
est store k2


reghdfe GInvest_H3  did    $var4  ,a(id year) vce(cluster citycode)
est store k3

reghdfe GInvest_A3  did    $var4  ,a(id year) vce(cluster citycode)
est store k4


reghdfe GInvest_M3  did  i.mc##i.did   $var4  ,a(id year) vce(cluster citycode)
est store k5


reghdfe GInvest_H3  did   i.house##i.did  $var4  ,a(id year) vce(cluster citycode)
est store k6

reghdfe GInvest_A3  did   i.agri##i.did  $var4  ,a(id year) vce(cluster citycode)
est store k7


esttab k2 k3 k4 k5 k6 k7, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles( "2" "3" "4" "5" "6" "7") ///
    addnotes("Notes: Year and id fixed effects are included.")
* Save to RTF file
esttab k2 k3 k4 k5 k6 k7 using 固废投资分行业.rtf, replace ///
    scalar(N r2_a F) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles( "2" "3" "4" "5" "6" "7") ///
    addnotes("Notes: Year and id fixed effects are included.")


* greenbuy (GPA), pa (PA), ceb (CEB) and opm (OPM) are used as stored in the dataset (final versions)

//循环经济 / Circular economy
reghdfe pn did $var4 ,a(id year) vce(cluster citycode)
est store i1
reghdfe pa did $var4 ,a(id year) vce(cluster citycode)
est store i2
reghdfe greenbuy did    $var4 ,a(id year) vce(cluster citycode)
est store i3
reghdfe ceb  did   $var4 ,a(id year) vce(cluster citycode)
est store i4
reghdfe CE did    $var4   ,a(id year) vce(cluster citycode)
est store i5
reghdfe opm did   $var4  ,a(id year) vce(cluster citycode)
est store i6
esttab i1 i2 i3 i4 i5 i6 , scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("1" "2" "3" "4" "5" "6") ///
    addnotes("Notes: Year and id fixed effects are included.")

esttab i1 i2 i3 i4 i5 i6 using 循环经济.rtf, replace ///
    scalar(N r2_a F) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("1" "2" "3" "4" "5" "6") ///
    addnotes("Notes: Year and id fixed effects are included.")



*异质性分组 / Heterogeneity by subgroup
use "$data",clear
xtset id year

//地方政府竞争 / Local government competition
drop x_wgdpg
xtile x_wgdpg = wgdpg, nq(2)
reghdfe gp did $var4 if x_wgdpg==1,a(id year) vce(cluster citycode)
est store v1
reghdfe gp did $var4 if x_wgdpg==2,a(id year) vce(cluster citycode)
est store v3
esttab v1  v3, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" "GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")

* Save to RTF file
esttab v1 v3 using 异质性分组2.rtf, replace ///
    scalar(N r2_a F) star(* 0.10 ** 0.05 *** 0.01) b(%6.3f) se(%6.3f) ///
    label nogap ///
    mtitles("GTFP" "GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")


//地方政府竞争 / Local government competition
gen wgdpg2 = (x_wgdpg == 2) if inlist(x_wgdpg,1,2)
bdiffv,model(reghdfe gp did $var4 ,a(id year) vce(cluster citycode))  group(wgdpg2) seed(3) xlabel(0 " " 1 "did" 2 "lnSize" 3 "AssetGrowth" 4 "DER" 5 "PB" 6 "Top10" 7 "Quick" 8 "ROA" 9 "CL" 10 "Capex" 11 "ITR" 12 "TMTPay" 13 " ", noticks angle(-45)) reps(500)


//绿色创新网络结构嵌入 / Structural embeddedness in green innovation networks
* 标记：2019年前且 非缺失 且 不等于0
* Flag: before 2019, non-missing and not equal to 0
* 聚合到 id 层面：是否曾出现过"非缺失且非零"
* Aggregate to the firm (id) level: whether the firm ever had a "non-missing and non-zero" value
* group_pre2019 is used as stored in the dataset (recomputing it from degree_centrality on the final sample would move 16 firm-years)
reghdfe gp did  $var4 if  group_pre2019==0 ,a(id year) vce(cluster citycode)
est store o1
reghdfe gp did  $var4 if  group_pre2019!=0 ,a(id year) vce(cluster citycode)
est store o2
esttab o1 o2, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" "GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")

* Save to RTF file
esttab o1 o2 using 进一步分析.rtf, replace ///
    scalar(N r2_a F) star(* 0.10 ** 0.05 *** 0.01) b(%6.3f) t(%6.3f) ///
    label nogap ///
    mtitles("GTFP" "GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")
bdiffv,model(reghdfe gp did $var4 ,a(id year) vce(cluster citycode))  group(group_pre2019) seed(26) xlabel(0 " " 1 "did" 2 "lnSize" 3 "AssetGrowth" 4 "DER" 5 "PB" 6 "Top10" 7 "Quick" 8 "ROA" 9 "CL" 10 "Capex" 11 "ITR" 12 "TMTPay" 13 " ", noticks angle(-45)) reps(500)




//市场调节程度 / Degree of market-based regulation
drop Mr Mr2
xtile Mr = market_sentence_share, nq(2)
gen Mr2 = (Mr == 2) if inlist(Mr,1,2)
reghdfe gp did $var4 if Mr2==1,a(id year) vce(cluster citycode)
est store v1
reghdfe gp did $var4 if Mr2==0,a(id year) vce(cluster citycode)
est store v2
esttab v1  v2, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("GTFP" "GTFP" ) ///
    addnotes("Notes: Year and id fixed effects are included.")

bdiffv,model(reghdfe gp did $var4 ,a(id year) vce(cluster citycode))  group(Mr2) seed(3) xlabel(0 " " 1 "did" 2 "lnSize" 3 "AssetGrowth" 4 "DER" 5 "PB" 6 "Top10" 7 "Quick" 8 "ROA" 9 "CL" 10 "Capex" 11 "ITR" 12 "TMTPay" 13 " ", noticks angle(-45)) reps(500)



//全局技术进步和全局效率 / Global technical change and global efficiency change
reghdfe gecglobalefficiencychange did $var4 ,a(id year) vce(cluster citycode)
est store v1
reghdfe gtcglobaltechnicalchange  did  $var4 ,a(id year) vce(cluster citycode)
est store v2
esttab v1  v2, scalar(N r2_a) star(* 0.10 ** 0.05 *** 0.01) b(%6.4f) se(%6.4f) ///
    label nogap ///
    mtitles("Gec" "Gtc" ) ///
    addnotes("Notes: Year and id fixed effects are included.")
//平行趋势 / Parallel trends
gen pd=year-first_treat
replace pd=-6 if pd<-6
forvalues i = 6(-1)1{
	gen pre_`i'=(pd==-`i'& treat==1)
}
gen current =(pd==0&treat==1)
forvalues j = 1(1)4{
	gen las_`j'=(pd==`j'& treat==1)
}

drop pre_1
gen pre_1=0

//平行趋势检验回归 / Event-study regression for the parallel-trends test
reghdfe gtcglobaltechnicalchange  pre_6 pre_5 pre_4 pre_3 pre_2 current las_1 las_2 las_3 las_4 pre_1 $var4 ,a(id year) vce(cluster citycode)

//平行趋势检验图 / Parallel-trends plot: Figure 5b, Dynamic Effects on Global Technical Change (all text in Microsoft YaHei)
local f "Microsoft YaHei"
coefplot, baselevels omitted keep(pre* current las*) vertical order(pre_6 pre_5 pre_4 pre_3 pre_2 pre_1 current las_1 las_2 las_3 las_4) ///
    msymbol(O) mcolor(black) msize(medsmall) ciopts(recast(rcap) lcolor(black) lpattern(dash) lwidth(medium)) yline(0, lpattern(solid) lcolor(black)) xline(6, lpattern(solid) lcolor(black)) ///
    xlabel(1 `"{fontface "`f'":-6}"' 2 `"{fontface "`f'":-5}"' 3 `"{fontface "`f'":-4}"' 4 `"{fontface "`f'":-3}"' 5 `"{fontface "`f'":-2}"' 6 `"{fontface "`f'":-1}"' 7 `"{fontface "`f'":0}"' 8 `"{fontface "`f'":1}"' 9 `"{fontface "`f'":2}"' 10 `"{fontface "`f'":3}"' 11 `"{fontface "`f'":4}"', labsize(medsmall)) ///
    ylabel(-0.005 `"{fontface "`f'":-0.005}"' 0 `"{fontface "`f'":0}"' 0.005 `"{fontface "`f'":0.005}"' 0.01 `"{fontface "`f'":0.01}"', angle(0) labsize(medsmall) nogrid) ///
    xtitle(`"{fontface "`f'":Years relative to policy implementation}"', size(medlarge)) ytitle(`"{fontface "`f'":Policy effect}"', size(medlarge)) xscale(titlegap(2.5)) yscale(titlegap(-1.5)) ///
    graphregion(color(white) margin(l=3.2 r=5.1 t=2.9 b=2)) plotregion(color(white)) scheme(stcolor) name(Figure_5b, replace)
graph save Figure_5b "Figure_5b.gph", replace
graph export "Figure_5b.png", name(Figure_5b) width(7500) replace


//平行趋势检验回归 / Event-study regression for the parallel-trends test
reghdfe gecglobalefficiencychange  pre_6 pre_5 pre_4 pre_3 pre_2 current las_1 las_2 las_3 las_4 pre_1 $var4 ,a(id year) vce(cluster citycode)


//平行趋势检验图 / Parallel-trends plot: Figure 5a, Dynamic Effects on Global Efficiency Change (all text in Microsoft YaHei)
local f "Microsoft YaHei"
coefplot, baselevels omitted keep(pre* current las*) vertical order(pre_6 pre_5 pre_4 pre_3 pre_2 pre_1 current las_1 las_2 las_3 las_4) ///
    msymbol(O) mcolor(black) msize(medsmall) ciopts(recast(rcap) lcolor(black) lpattern(dash) lwidth(medium)) yline(0, lpattern(solid) lcolor(black)) xline(6, lpattern(solid) lcolor(black)) ///
    xlabel(1 `"{fontface "`f'":-6}"' 2 `"{fontface "`f'":-5}"' 3 `"{fontface "`f'":-4}"' 4 `"{fontface "`f'":-3}"' 5 `"{fontface "`f'":-2}"' 6 `"{fontface "`f'":-1}"' 7 `"{fontface "`f'":0}"' 8 `"{fontface "`f'":1}"' 9 `"{fontface "`f'":2}"' 10 `"{fontface "`f'":3}"' 11 `"{fontface "`f'":4}"', labsize(medsmall)) ///
    ylabel(-0.004 `"{fontface "`f'":-0.004}"' -0.002 `"{fontface "`f'":-0.002}"' 0 `"{fontface "`f'":0}"' 0.002 `"{fontface "`f'":0.002}"' 0.004 `"{fontface "`f'":0.004}"', angle(0) labsize(medsmall) nogrid) ///
    xtitle(`"{fontface "`f'":Years relative to policy implementation}"', size(medlarge)) ytitle(`"{fontface "`f'":Policy effect}"', size(medlarge)) xscale(titlegap(2.5)) yscale(titlegap(-1.5)) ///
    graphregion(color(white) margin(l=3.2 r=5.1 t=2.9 b=2)) plotregion(color(white)) scheme(stcolor) name(Figure_5a, replace)
graph save Figure_5a "Figure_5a.gph", replace
graph export "Figure_5a.png", name(Figure_5a) width(7500) replace
