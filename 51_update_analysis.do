// ============================================================================
//
// Cargo -- 1.6.0
//
// ============================================================================
cd ~/Dropbox/Papers/10_WorkInProgress/SoftwareUpdates/Data/Cargo/

// PREPARE REPO IDs
use repositories_Cargo.dta, clear
	keep repoid projectname description
save repoid_projectname_description.dta, replace

// PREPARE NETWORK VARIABLES
insheet using Master/degrees_repo_dependencies_Cargo-cuts.csv, delimiter(";") names clear
save Master/degrees_repo_dependencies_Cargo-cuts.dta, replace

// CREATE COVARIATE DATASET
insheet using Master/master_Cargo-cuts-lcc.csv, clear delimiter(";") names
merge 1:1 repoid using repoid_projectname_description.dta
	keep if _merge == 3
	drop _merge

merge 1:1 repoid using Master/degrees_repo_dependencies_Cargo-cuts.dta
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
save covariates_Cargo-cuts-lcc.dta, replace 

// ANALYZE COVARIATES 
use covariates_Cargo-cuts-lcc.dta, clear
	gsort - num_versions
	order num_versions projectname out_deg in_deg

	keep num_versions projectname out_deg in_deg
	keep in 1/10
	esttab using "tab_Cargo_top10_versions.tex", cells("b") varlabels(_all) nomtitle nonumber noobs label

	
//
// CREATE PANEL
//
// FIRST, TIME DATA
insheet using versions_Cargo.csv, delimiter(";") names clear
	gen year = substr(publishedtimestamp, 1,4)
	gen month = substr(publishedtimestamp, 6,2)
	gen year_month = year + "-" + month
	sort projectid year_month
	egen id_year_month = group(year_month)
	
	keep year_month id_year 
	duplicates drop
save id_year_year_month.dta, replace

// NEXT, CREATE VERSIONS AS BALANCED PANEL
insheet using versions_Cargo.csv, delimiter(";") names clear
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
save versions_balanced_Cargo-cuts-lcc.dta, replace
	
// THEN, PREPARE DEPENDENCIES AS PANEL -- CAREFUL, CAN GET LARGE
use repo_dependencies_Cargo-cuts-lcc.dta, clear
	expand 64
	bysort from_repo to_repo: gen id_year_month = _n
save repo_dependencies_Cargo-cuts-lcc+date.dta, replace

// FINALLY, ACTUAL PANEL CONSTRUCTION
// (BASED ON DEPENDENCIES PANEL MERGED WITH VERSIONS PANEL)
use repo_dependencies_Cargo-cuts-lcc+date.dta, clear
	rename to_repo repoid
merge m:1 repoid id_year_month using versions_balanced_Cargo-cuts-lcc.dta
	keep if _merge == 3
	drop _merge
	
	rename repoid to_repo
	bysort from_repo id_year_month: egen num_dep_updates = sum(num_versions)
	bysort from_repo id_year_month: gen num_deps = _N

	drop to_repo year_month num_versions
	duplicates drop
	rename from_repo repoid

	bysort repoid: gen num_3m_dep_updates = num_dep_updates + num_dep_updates[_n-1] + num_dep_updates[_n-2]
	
	su num_dep_updates, d
	scalar p95_num_dep_updates = r(p95)
	drop if num_dep_updates >= p95_num_dep_updates
	
	gen foo = id_year_month
	drop id_year_month
	rename foo id_year_month
save num_dep_updates.dta, replace

// MERGE DEPENDENCY UPDATES PER REPOID
use versions_balanced_Cargo-cuts-lcc.dta, clear
merge 1:1 repoid id_year_month using num_dep_updates.dta
	keep if _merge == 3
	drop _merge
	drop year_month
	
	egen id_repo = group(repoid)
	
	order id_repo id_year_month num_versions num_dep_updates num_3m_dep_updates num_deps repoid
	sort id_repo id_year_month
	
	xtset id_repo id_year_month  // FINAL PANEL DATASET

	label variable num_versions "\# updates"
	label variable num_dep_updates "\# dep. updates"
	label variable num_3m_dep_updates "\# dep. updates (3m)"
	label variable num_deps "\# dependencies"
	
save balanced_panel_Cargo-cuts-lcc.dta, replace


//
// ANALYZE PANEL
//

//
// INTENSIVE MARGIN
//
// MAIN: Lag = 1
use	balanced_panel_Cargo-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	
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
esttab model1 model2 model3 model4 model5 using i_num_versions_Cargo-cuts2-lcc-1.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1})

// ROBUSTNESS: Lag = 0
{
use	balanced_panel_Cargo-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	
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
		
esttab model1 model2 model3 model4 model5 using i_num_versions_Cargo-cuts2-lcc-0.tex, ///
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

// ROBUSTNESS: 3m dep updates
{
use	balanced_panel_Cargo-cuts-lcc.dta, clear  // NOTE: Not actually balanced since the last cut removed observations with num_dep_updates > p95
	
	//
	// INTENSIVE MARGIN FIRST
	//
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
		
esttab model1 model2 model3 model4 model5 using i_num_versions_Cargo-cuts2-lcc-3m.tex, ///
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
use	balanced_panel_Cargo-cuts-lcc.dta, clear
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

	probit is_updated i.id_year_month i.id_repo dep_is_updated num_deps // careful, runs long
	eststo model5
	
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
esttab model1 model2 model3 model4 using e_num_versions_Cargo-cuts2-lcc-1.tex, ///
    replace ///
    label ///
    se ///
    b(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    varwidth(25) ///
	stats(N r2, fmt(%9.0fc %9.3f)) ///
    alignment(D{.}{.}{-1}) ///
    drop(*year_month*)

	


	
// ============================================================================
//
// NPM -- 1.6.0
//
// ============================================================================
cd ~/Dropbox/Papers/10_WorkInProgress/SoftwareUpdates/Data/NPM/

// PREPARE REPO IDs
use repositories_NPM.dta, clear
	keep repoid projectname description
save repoid_projectname_description.dta, replace

// PREPARE NETWORK VARIABLES
insheet using Master-1k/degrees_repo_dependencies_NPM-cuts.csv, delimiter(";") names clear
save Master-1k/degrees_repo_dependencies_NPM-cuts.dta, replace

// CREATE COVARIATE DATASET
insheet using Master-1k/master_NPM-cuts-lcc.csv, clear delimiter(";") names
merge 1:1 repoid using repoid_projectname_description.dta
	keep if _merge == 3
	drop _merge

merge 1:1 repoid using Master-1k/degrees_repo_dependencies_NPM-cuts.dta
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

save covariates_NPM-cuts-lcc.dta, replace 

// ANALYZE COVARIATES 
use covariates_NPM-cuts-lcc.dta, clear
	gsort - num_versions
	order num_versions projectname out_deg in_deg

	keep num_versions projectname out_deg in_deg
	keep in 1/10
	esttab using "tab_NPM_top10_versions.tex", cells("b") varlabels(_all) nomtitle nonumber noobs label
	
	
	
	
// create panel and merge covariates
insheet using repo_dependencies_NPM-cuts-lcc.csv, delimiter(";") clear	
	rename v1 repoid
merge m:1 repoid using covariates_NPM-cuts-lcc.dta
	keep if _merge == 3
	drop _merge
	
	drop projectname description
	
	foreach var in num_versions num_stars num_watchers num_contributors size maturity {
		rename `var' `var'_from
	}	
	rename repoid id_repo_from

	rename v2 repoid
merge m:1 repoid using covariates_NPM-cuts-lcc.dta
	keep if _merge == 3
	drop _merge
	
	drop projectname description
	
	foreach var in num_versions num_stars num_watchers num_contributors size maturity {
		rename `var' `var'_to
	}	
	rename repoid id_repo_to
	
	sort id_repo_from id_repo_to
	
	reg num_versions_from num_versions_to maturity_from size_from size_to 
