// ============================================================================
//
// Pypi -- 1.6.0
//
// ============================================================================
cd ~/Dropbox/Papers/10_WorkInProgress/SoftwareUpdates/Data/Pypi/

// PREPARE REPO IDs
use repositories_Pypi.dta, clear
	keep repoid projectname description
save repoid_projectname_description.dta, replace

// PREPARE NETWORK VARIABLES
insheet using Master/degrees_repo_dependencies_Pypi-cuts.csv, delimiter(";") names clear
save Master/degrees_repo_dependencies_Pypi-cuts.dta, replace

// CREATE COVARIATE DATASET
insheet using Master/master_Pypi-cuts-lcc.csv, clear delimiter(";") names
merge 1:1 repoid using repoid_projectname_description.dta
	keep if _merge == 3
	drop _merge

merge 1:1 repoid using Master/degrees_repo_dependencies_Pypi-cuts.dta
	keep if _merge == 3
	drop _merge

	keep repoid num_versions size numstars numwatchers numcontributors maturity description projectname successors predecessors
	
	rename numstars num_stars 
	rename numwatchers num_watchers
	rename numcontributors num_contributors
	rename successors out_deg 
	rename predecessors in_deg

	sort repoid
	order repoid projectname description
save covariates_Pypi-cuts-lcc.dta, replace 

// ANALYZE COVARIATES 
use covariates_Pypi-cuts-lcc.dta, clear
	gsort - num_versions
	order num_versions projectname out_deg in_deg

	keep num_versions projectname out_deg in_deg
	keep in 1/10
	esttab using "tab_Pypi_top10_versions.tex", cells("b") varlabels(_all) nomtitle nonumber noobs label

	
//
// CREATE PANEL
//
// FIRST, TIME DATA
insheet using versions_Pypi.csv, delimiter(";") names clear
	gen year = substr(publishedtimestamp, 1,4)
	gen month = substr(publishedtimestamp, 6,2)
	gen year_month = year + "-" + month
	sort projectid year_month
	egen id_year_month = group(year_month)
	
	keep year_month id_year 
	duplicates drop
save id_year_year_month.dta, replace

// NEXT, CREATE VERSIONS AS BALANCED PANEL
insheet using versions_Pypi.csv, delimiter(";") names clear
	gen year = substr(publishedtimestamp, 1,4)
	gen month = substr(publishedtimestamp, 6,2)
	gen year_month = year + "-" + month
	sort projectid year_month

merge m:1 projectid using projectid_repoid-cuts.dta   // automatically imposes cuts applied before
	keep if _merge == 3
	drop _merge 
	
	keep repoid projectname versionnumber year_month

merge m:1 year_month using id_year_year_month.dta 
	keep if _merge == 3
	drop _merge 
	
	order repoid id_year_month projectname versionnumber year_month  

	bysort repoid id_year_month : gen num_versions = _N
	keep repoid id_year_month num_versions
	duplicates drop
	
	xtset repoid id_year_month
	tsfill, full
	
	// complete balanced panel
	replace num_versions = 0 if num_versions == .
merge m:1 id_year_month using id_year_year_month.dta
	keep if _merge == 3
	drop _merge 

	order repoid id_year_month year_month  
	sort repoid id_year_month
save versions_balanced_Pypi-cuts-lcc.dta, replace
	
// THEN, PREPARE DEPENDENCIES AS PANEL -- CAREFUL, CAN GET LARGE
use repo_dependencies_Pypi-cuts-lcc.dta, clear
	expand 181
	bysort from_repo to_repo: gen id_year_month = _n
save repo_dependencies_Pypi-cuts-lcc+date.dta, replace

// FINALLY, ACTUAL PANEL CONSTRUCTION
// (BASED ON DEPENDENCIES PANEL MERGED WITH VERSIONS PANEL)
use repo_dependencies_Pypi-cuts-lcc+date.dta, clear
	rename to_repo repoid
merge m:1 repoid id_year_month using versions_balanced_Pypi-cuts-lcc.dta
	keep if _merge == 3
	drop _merge
	
	rename repoid to_repo
	bysort from_repo id_year_month: egen num_dep_updates = sum(num_versions)
	bysort from_repo id_year_month: gen num_deps = _N

	drop to_repo year_month num_versions
	duplicates drop
	rename from_repo repoid

	// compute indicator for lagged updates
	bysort repoid: gen has_3m_dep_update = min(1, num_dep_updates + num_dep_updates[_n-1] + num_dep_updates[_n-2])
	bysort repoid: gen has_6m_dep_update = min(1, num_dep_updates + num_dep_updates[_n-1] + num_dep_updates[_n-2] + num_dep_updates[_n-3] + num_dep_updates[_n-4] + num_dep_updates[_n-5])
	// and number of lagged updates
	bysort repoid: gen num_3m_dep_updates = min(1, num_dep_updates + num_dep_updates[_n-1] + num_dep_updates[_n-2])
	bysort repoid: gen num_6m_dep_updates = min(1, num_dep_updates + num_dep_updates[_n-1] + num_dep_updates[_n-2] + num_dep_updates[_n-3] + num_dep_updates[_n-4] + num_dep_updates[_n-5])
	
	su num_dep_updates, d
	scalar p95_num_dep_updates = r(p95)
// 	drop if num_dep_updates >= p95_num_dep_updates

save num_dep_updates.dta, replace

// MERGE DEPENDENCY UPDATES PER REPOID
use versions_balanced_Pypi-cuts-lcc.dta, clear
	gen has_update = 0
	replace has_update = 1 if num_versions > 0
merge 1:1 repoid id_year_month using num_dep_updates.dta
	keep if _merge == 3
	drop _merge
	drop year_month
	
	egen id_repo = group(repoid)
	
	order id_repo id_year_month num_versions num_dep_updates num_3m_dep_updates num_deps repoid
	sort id_repo id_year_month
	
	xtset id_repo id_year_month  // FINAL PANEL DATASET

	label variable num_versions "\# updates"
	label variable has_update "has update"
	label variable num_dep_updates "\# dep. updates"
	label variable num_3m_dep_updates "\# dep. updates (3m)"
	label variable num_6m_dep_updates "\# dep. updates (6m)"
	label variable has_3m_dep_update "has dep. updates (3m)"
	label variable has_6m_dep_update "has dep. updates (6m)"
	label variable num_deps "\# dependencies"
	
save balanced_panel_Pypi-cuts-lcc.dta, replace


//
// ANALYZE BALANCED PANEL
//

//
// INTENSIVE MARGIN
//
{
// MAIN: Lag = 1
use	balanced_panel_Pypi-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	
	//
	// INTENSIVE MARGIN FIRST
	//
	qui reghdfe num_versions L.num_dep_updates
	eststo model1
	
	qui reghdfe num_versions num_deps
	eststo model2 
	
	qui reghdfe num_versions L.num_dep_updates num_deps
	eststo model3

	qui reghdfe num_versions L.num_dep_updates num_deps, absorb(id_year_month)
	eststo model4

	qui reghdfe num_versions L.num_dep_updates, absorb(id_repo id_year_month)
	eststo model5	

esttab model1 model2 model3 model4 model5, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})		
esttab model1 model2 model3 model4 model5 using i_num_versions_Pypi-cuts2-lcc-1.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})
}

// ROBUSTNESS: Lag = 0
{
use	balanced_panel_Pypi-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	
	//
	// INTENSIVE MARGIN FIRST
	//
	qui reghdfe num_versions num_dep_updates
	eststo model1
	
	qui reghdfe num_versions num_deps
	eststo model2 
	
	qui reghdfe num_versions num_dep_updates num_deps
	eststo model3

	qui reghdfe num_versions num_dep_updates num_deps, absorb(id_year_month)
	eststo model4

	qui reghdfe num_versions num_dep_updates, absorb(id_repo id_year_month)
	eststo model5
		
esttab model1 model2 model3 model4 model5 using i_num_versions_Pypi-cuts2-lcc-0.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
    stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})
esttab model1 model2 model3 model4 model5, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
    stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})
}

// ROBUSTNESS: 3m + 6m dep updates
{
use	balanced_panel_Pypi-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	
	// 3m
	qui reghdfe num_versions num_3m_dep_updates
	eststo model1
	
	qui reghdfe num_versions num_deps
	eststo model2 
	
	qui reghdfe num_versions num_3m_dep_updates num_deps
	eststo model3

	qui reghdfe num_versions num_3m_dep_updates num_deps, absorb(id_year_month)
	eststo model4

	qui reghdfe num_versions num_3m_dep_updates, absorb(id_repo id_year_month)
	eststo model5
		
esttab model1 model2 model3 model4 model5 using i_num_versions_Pypi-cuts2-lcc-3m.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
    stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})
esttab model1 model2 model3 model4 model5, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
    stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})

	// 6m
	eststo clear
	drop if num_6m_dep_updates == .
	qui reghdfe num_versions num_6m_dep_updates
	eststo model1
	
	qui reghdfe num_versions num_deps
	eststo model2 
	
	qui reghdfe num_versions num_6m_dep_updates num_deps
	eststo model3

	qui reghdfe num_versions num_6m_dep_updates num_deps, absorb(id_year_month)
	eststo model4

	qui reghdfe num_versions num_6m_dep_updates, absorb(id_repo id_year_month)
	eststo model5
		
esttab model1 model2 model3 model4 model5 using i_num_versions_Pypi-cuts2-lcc-6m.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
    stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})
esttab model1 model2 model3 model4 model5, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
    stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})
}

	
//
// THEN EXTENSIVE MARGIN
//
{
use	balanced_panel_Pypi-cuts-lcc.dta, clear
	gen is_updated = 0
	replace is_updated = 1 if num_versions > 0
	gen dep_is_updated = 0
	replace dep_is_updated = 1 if num_dep_updates > 0
	
	qui probit is_updated L.dep_is_updated 
	eststo model1

	qui probit is_updated num_deps
	eststo model2

	qui probit is_updated L.dep_is_updated num_deps 
	eststo model3
	
	qui probit is_updated i.id_year_month L.dep_is_updated num_deps 
	eststo model4

// 	probit is_updated i.id_year_month i.id_repo dep_is_updated num_deps // careful, runs long
// 	eststo model5
	
esttab model1 model2 model3 model4, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1}) ///
    drop(*year_month*)
esttab model1 model2 model3 model4 using e_num_versions_Pypi-cuts2-lcc-1.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1}) ///
    drop(*year_month*)
}
	

//
// ROBUSTNESS: UNBALANCED PANEL
//
{
insheet using versions_Pypi.csv, delimiter(";") names clear
	gen year = substr(publishedtimestamp, 1,4)
	gen month = substr(publishedtimestamp, 6,2)
	gen year_month = year + "-" + month
	sort projectid year_month

merge m:1 projectid using projectid_repoid-cuts.dta   // automatically imposes cuts applied before
	keep if _merge == 3
	drop _merge 
	
	keep repoid projectname versionnumber year_month

merge m:1 year_month using id_year_year_month.dta 
	keep if _merge == 3
	drop _merge 
	
	order repoid id_year_month projectname versionnumber year_month  

	bysort repoid id_year_month : gen num_versions = _N
	keep repoid id_year_month num_versions
	duplicates drop
	
	xtset repoid id_year_month

	
	order repoid id_year_month
	sort repoid id_year_month
save versions_unbalanced_Pypi-cuts-lcc.dta, replace
	
// THEN, ACTUAL PANEL CONSTRUCTION
// (BASED ON DEPENDENCIES PANEL MERGED WITH VERSIONS PANEL)
use repo_dependencies_Pypi-cuts-lcc+date.dta, clear
	rename to_repo repoid
merge m:1 repoid id_year_month using versions_unbalanced_Pypi-cuts-lcc.dta
	keep if _merge == 3
	drop _merge
	
	rename repoid to_repo
	bysort from_repo id_year_month: egen num_dep_updates = sum(num_versions)
	bysort from_repo id_year_month: gen num_deps = _N

	drop to_repo num_versions
	duplicates drop
	
	rename from_repo repoid
	
	su num_dep_updates, d
	scalar p95_num_dep_updates = r(p95)
	drop if num_dep_updates >= p95_num_dep_updates
	
save unbalanced_num_dep_updates.dta, replace

// MERGE DEPENDENCY UPDATES PER REPOID
use versions_balanced_Pypi-cuts-lcc.dta, clear
merge 1:1 repoid id_year_month using unbalanced_num_dep_updates.dta
	keep if _merge == 3
	drop _merge
	drop year_month
	
	egen id_repo = group(repoid)
	
	order id_repo id_year_month num_versions num_dep_updates num_deps repoid
	sort id_repo id_year_month
	
	xtset id_repo id_year_month  // FINAL PANEL DATASET

	label variable num_versions "\# updates"
	label variable num_dep_updates "\# dep. updates"
	
save unbalanced_panel_Pypi-cuts-lcc.dta, replace

// ROBUSTNESS: unbalanced panel, no lag
use	unbalanced_panel_Pypi-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	
	// INTENSIVE MARGIN FIRST
	reghdfe num_versions num_dep_updates
	eststo model1
	
	reghdfe num_versions num_deps
	eststo model2 
	
	reghdfe num_versions num_dep_updates num_deps
	eststo model3

	reghdfe num_versions num_dep_updates num_deps, absorb(id_year_month)
	eststo model4

	reghdfe num_versions num_dep_updates, absorb(id_repo id_year_month)
	eststo model5	

esttab model1 model2 model3 model4 model5, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})		
esttab model1 model2 model3 model4 model5 using i_num_versions_Pypi-cuts2-lcc-unbalanced.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})
}


// ============================================================================
//
// REVERSE NETWORK
//
// ============================================================================
use repo_dependencies_Pypi-cuts-lcc+date.dta, clear
	rename from_repo repoid
merge m:1 repoid id_year_month using versions_balanced_Pypi-cuts-lcc.dta
	keep if _merge == 3
	drop _merge
	
	rename repoid from_repo
	
	bysort to_repo id_year_month: egen num_dep_updates = sum(num_versions)  // number of dependent updates (as opposed to dependency updates)
	bysort to_repo id_year_month: gen num_deps = _N  // number of dependents

	drop from_repo year_month num_versions
	duplicates drop
	rename to_repo repoid

	bysort repoid: gen num_3m_dep_updates = num_dep_updates + num_dep_updates[_n+1] + num_dep_updates[_n+2]  // updates of dependencies in the coming months
	gen has_3m_dep_update = 0
	replace has_3m_dep_update = 1 if num_3m_dep_updates > 0
	
	su num_dep_updates, d
	scalar p95_num_dep_updates = r(p95)
	drop if num_dep_updates >= p95_num_dep_updates

save rev_num_dep_updates.dta, replace

// MERGE DEPENDENCY UPDATES PER REPOID
use versions_balanced_Pypi-cuts-lcc.dta, clear
	gen has_update = 0
	replace has_update = 1 if num_versions > 0
merge 1:1 repoid id_year_month using rev_num_dep_updates.dta
	keep if _merge == 3
	drop _merge
	drop year_month
	
	egen id_repo = group(repoid)
	
	order id_repo id_year_month num_versions num_dep_updates num_deps repoid
	sort id_repo id_year_month
	
	xtset id_repo id_year_month  // FINAL PANEL DATASET

	label variable num_versions "\# updates"
	label variable has_update "has update"
	label variable num_dep_updates "\# dep. updates"
	label variable num_3m_dep_updates "\# 3m dep. updates"
	label variable has_3m_dep_update "has 3m dep. update"
	label variable num_deps "\# dependencies"
	
save rev_balanced_panel_Pypi-cuts-lcc.dta, replace



//
// INTENSIVE MARGIN
//
{
// MAIN: Lag = 1
use	rev_balanced_panel_Pypi-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	
	//
	// INTENSIVE MARGIN FIRST
	//
	qui reghdfe num_versions L.num_dep_updates
	eststo model1
	
	qui reghdfe num_versions num_deps
	eststo model2 
	
	qui reghdfe num_versions L.num_dep_updates num_deps
	eststo model3

	qui reghdfe num_versions L.num_dep_updates num_deps, absorb(id_year_month)
	eststo model4

	qui reghdfe num_versions L.num_dep_updates, absorb(id_repo id_year_month)
	eststo model5	

esttab model1 model2 model3 model4 model5, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})		
esttab model1 model2 model3 model4 model5 using rev_i_num_versions_Pypi-cuts2-lcc-1.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})
}

//
// EXTENSIVE MARGIN
//
{
use	rev_balanced_panel_Pypi-cuts-lcc.dta, clear
	gen is_updated = 0
	replace is_updated = 1 if num_versions > 0
	gen dep_is_updated = 0
	replace dep_is_updated = 1 if num_dep_updates > 0
	
	qui probit is_updated L.dep_is_updated 
	eststo model1

	qui probit is_updated num_deps
	eststo model2

	qui probit is_updated L.dep_is_updated num_deps 
	eststo model3
	
	qui probit is_updated i.id_year_month L.dep_is_updated num_deps 
	eststo model4

// 	probit is_updated i.id_year_month i.id_repo dep_is_updated num_deps // careful, runs long
// 	eststo model5
	
esttab model1 model2 model3 model4, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1}) ///
    drop(*year_month*)
esttab model1 model2 model3 model4 using rev_e_num_versions_Pypi-cuts2-lcc-1.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1}) ///
    drop(*year_month*)
}

	
// ============================================================================
//
// ESTIMATE DELTA
//
// ============================================================================

// 3m updates
use	balanced_panel_Pypi-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	gen rep_dep = 0
	gen rep_ndep = 0
	gen nrep_dep = 0
	gen nrep_ndep = 0
	
	replace rep_dep = 1 if has_update == 1 & has_3m_dep_update == 1
	replace rep_ndep = 1 if has_update == 1 & has_3m_dep_update == 0
	replace nrep_dep = 1 if has_update == 0 & has_3m_dep_update == 1
	replace nrep_ndep = 1 if has_update == 0 & has_3m_dep_update == 0
	keep rep_dep rep_ndep nrep_dep nrep_ndep
	
	foreach var of varlist rep_dep-nrep_ndep {
		egen t_`var' = total(`var')
	}
	keep t_* 
	duplicates drop

// 6m updates 
use	balanced_panel_Pypi-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	gen rep_dep = 0
	gen rep_ndep = 0
	gen nrep_dep = 0
	gen nrep_ndep = 0
	
	replace rep_dep = 1 if has_update == 1 & has_6m_dep_update == 1
	replace rep_ndep = 1 if has_update == 1 & has_6m_dep_update == 0
	replace nrep_dep = 1 if has_update == 0 & has_6m_dep_update == 1
	replace nrep_ndep = 1 if has_update == 0 & has_6m_dep_update == 0
	
	keep rep_dep rep_ndep nrep_dep nrep_ndep
	
	foreach var of varlist rep_dep-nrep_ndep {
		egen t_`var' = total(`var')
	}
	keep t_* 
	duplicates drop
		
// reverse 3m
use	rev_balanced_panel_Pypi-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	gen rep_dep = 0
	gen rep_ndep = 0
	gen nrep_dep = 0
	gen nrep_ndep = 0
	
	replace rep_dep = 1 if has_update == 1 & has_3m_dep_update == 1
	replace rep_ndep = 1 if has_update == 1 & has_3m_dep_update == 0
	replace nrep_dep = 1 if has_update == 0 & has_3m_dep_update == 1
	replace nrep_ndep = 1 if has_update == 0 & has_3m_dep_update == 0
	
	keep rep_dep rep_ndep nrep_dep nrep_ndep
	
	foreach var of varlist rep_dep-nrep_ndep {
		egen t_`var' = total(`var')
	}
	keep t_* 
	duplicates drop
	