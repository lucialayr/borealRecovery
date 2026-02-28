# Variable Usage Mapping

## Database Tables and Their Usage

### Tables in patches2.duckdb:
1. **picontrol_d150_npp_cmass** - Carbon mass
2. **picontrol_d150_npp_anpp** - ANPP (not used in main analysis)
3. **picontrol_d150_npp_exp_est** - Establishment (recruitment)
4. **picontrol_d150_npp_fpc** - FPC (not used in main analysis)
5. **ssp126_d150_cmass** - Carbon mass
6. **ssp126_d150_anpp** - ANPP (not used in main analysis)
7. **ssp126_d150_exp_est** - Establishment
8. **ssp126_d150_fpc** - FPC (not used in main analysis)
9. **ssp585_d150_cmass** - Carbon mass
10. **ssp585_d150_anpp** - ANPP (not used in main analysis)
11. **ssp585_d150_exp_est** - Establishment
12. **ssp585_d150_fpc** - FPC (not used in main analysis)

## Main Figures and Required Data

### Figure 3 (Validation)
- **Script:** `validation_plots.R`
- **Data:** `data/final/validation_B.csv`
- **Source:** `00_validation.R` (uses external data, not database)
- **Tables needed:** NONE

### Figure 4 (Trajectories + Niche)
- **Script:** `trajectories_niche_final_plot.R`
- **Data:** 
  - `trajectories_mean_A_mean_*.csv` (cmass)
  - `trajectories_mean_A_agc_*.csv` (cmass)
  - `trajectories_mean_A_agc_classes_*.csv` (cmass)
  - `trajectories_niche_B.shp` (spatial data)
- **Source:** `trajectories_niche_processed_final.R` ← `02a_trajectories_database_processed.R`
- **Tables needed:** 
  - ✅ **cmass** (all scenarios)
  - ✅ **exp_est** (all scenarios)
  - ❌ anpp (NOT USED)
  - ❌ fpc (NOT USED)

### Figure 5 (Maps/Regression)
- **Script:** `maps_regression_plot.R`
- **Data:** 
  - `maps_regression_B_patches_*.csv`
  - `maps_regression_B_model_*.csv`
- **Source:** `maps_regression_final.R` ← `02c_classified_trajectories_processed.R` ← `02a_trajectories_database_processed.R`
- **Tables needed:**
  - ✅ **cmass** (all scenarios)
  - ✅ **exp_est** (all scenarios)

### Figure 6 (Random Forest)
- **Script:** `random_forest_plot.R`
- **Data:**
  - `random_forest_A_*.csv`
  - `random_forest_B_*.csv`
- **Source:** `random_forest_final.R` ← Python models ← `02e_final_input_rf.R` ← multiple 02*.R scripts
- **Tables needed:**
  - ✅ **cmass** (all scenarios)
  - Possibly exp_est and climate data

## CRITICAL FINDING: Minimal Tables for Main Analysis

**Only 6 of 12 tables are needed:**
1. picontrol_d150_npp_cmass ✅
2. picontrol_d150_npp_exp_est ✅
3. ssp126_d150_cmass ✅
4. ssp126_d150_exp_est ✅
5. ssp585_d150_cmass ✅
6. ssp585_d150_exp_est ✅

**NOT needed for main analysis:**
- All *_anpp tables (6 tables)
- All *_fpc tables (0 tables in ssp, but picontrol has it)

## Processing Pipeline Summary

```
Database Tables (cmass + exp_est only)
  ↓
02a_trajectories_database_processed.R
  ↓
data/processed/trajectories_*.csv
  ↓
├─→ 02b_agc_trajectories_processed.R
├─→ 02c_classified_trajectories_processed.R  
├─→ 02d_climate_covariates.R
└─→ 02e_final_input_rf.R
  ↓
trajectories_niche_processed_final.R
maps_regression_final.R
random_forest_final.R (+ Python models)
  ↓
data/final/*.csv
  ↓
*_plot.R scripts
  ↓
Figures
```

## Recommendation

Create tiny subset with **ONLY 6 tables** (cmass + exp_est):
- Reduces subset from ~151 MB (all 12 tables) to ~75 MB (6 tables)
- 50% storage reduction
- 50% time reduction for subset creation
- All main figures still reproducible
