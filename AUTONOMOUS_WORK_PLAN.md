# Autonomous Work Plan - Figure Reproduction Testing

**Date Created:** February 27, 2026  
**Objective:** Test complete analysis pipeline and all figure reproductions

---

## Phase 1: Pipeline Processing (Start with Full Database)

### Step 1.1: Climate Covariates (02d)
- **Script:** `code/02d_climate_covariates.R`
- **Database:** `patches2.duckdb` (TRY FIRST)
- **Inputs:** 16 files in `data/raw/climate_data/` (✅ verified present)
- **Outputs:** `data/processed/covariates_*_growingseason.csv` (6 files expected)
- **If RAM crash:** Switch to `patches2_50cells_complete.duckdb`, retry

### Step 1.2: Maps Regression (02e → maps_regression_final)
- **Script:** `code/maps_regression_final.R`
- **Database:** Same as 1.1
- **Inputs:** 
  - Classified trajectories from `data/processed/` (already exists)
  - Covariates from Step 1.1
- **Outputs:** 
  - `data/processed/all_binary_data_*.csv` (2 files)
  - `data/final/maps_regression_B_patches_*.csv` (2 files) - DO NOT OVERWRITE REFERENCE
  - `data/final/maps_regression_B_model_*.csv` (2 files) - DO NOT OVERWRITE REFERENCE
- **Action:** Save new outputs with suffix like `_50cell` or `_test` to avoid overwriting reference
- **If RAM crash:** Switch to 50-cell database, retry

### Step 1.3: Long-term Recovery
- **Script:** `code/long_term_recovery_final.R`
- **Database:** Same as 1.1/1.2
- **Fix first:** Change line 27 from `data/results/` to `data/processed/`
- **Inputs:** `data/processed/all_binary_data_*.csv` (from Step 1.2)
- **Outputs:** 
  - `data/final/long_term_recovery_A_final.csv` - DO NOT OVERWRITE IF EXISTS
  - `data/final/long_term_recovery_B_final.csv` - DO NOT OVERWRITE IF EXISTS
- **Action:** Save with suffix if reference exists
- **If RAM crash:** Switch to 50-cell database, retry

---

## Phase 2: Test All Figure Plotting Scripts

### Figure 1: Study Area
- **Script:** `code/Figure_01.R`
- **Database:** patches2.duckdb (or 50-cell if used in Phase 1)
- **Expected output:** `figures/figure1_cmass_BNE.png`
- **Test:** Run script, check if plot generates
- **Status:** Document ✅/❌ + any errors

### Figure 2 & 3: Validation
- **Script:** `code/validation_plots.R`
- **Inputs:** `data/final/validation_B.csv`, `data/final/shp/validation_A.shp`
- **Expected output:** `plots/recovery_validation.png`
- **Status:** Already tested, should work - verify again

### Figure 4: Trajectories & Niche
- **Script:** `code/trajectories_niche_final_plot.R`
- **Inputs:** 
  - `data/final/trajectories_mean_A_*.csv` (6 files - regenerated from 50-cell)
  - `data/final/shp/trajectories_niche_B.shp` (reference exists)
- **Expected outputs:** `plots/trajectories_niche_2015_2040.png`, `plots/trajectories_niche_2075_2100.png`
- **Test:** Run both time periods
- **Status:** Document ✅/❌

### Figure 5: Maps & Regression
- **Script:** `code/maps_regression_plot.R`
- **Inputs:** 
  - `data/final/maps_regression_B_patches_*.csv` (reference)
  - `data/final/maps_regression_B_model_*.csv` (reference)
  - `data/final/shp/maps_regression_A_final_*.shp` (reference)
- **Expected outputs:** `plots/maps_regression_2015_2040.png`, `plots/maps_regression_2075_2100.png`
- **Test:** Run both time periods with REFERENCE data
- **Status:** Document ✅/❌

### Figure 6: Random Forest
- **Script:** `code/random_forest_plot.R`
- **Inputs:** `data/final/random_forest_*.csv` (4 files - reference)
- **Expected outputs:** `plots/results_rf_2015_2040.png`, `plots/results_rf_2075_2100.png`
- **Test:** Run both time periods
- **Status:** Document ✅/❌

### Appendix X1: Climate Data
- **Script:** `code/X1_climate_data.R`
- **Inputs:** Climate NetCDF files in `data/raw/climate_data/`
- **Expected output:** `plots/growing_season_temperature.pdf`
- **Test:** Run script
- **Status:** Document ✅/❌

### Appendix X2: Results Histograms
- **Script:** `code/X2_results.R`
- **Inputs:** `data/final/maps_regression_B_patches_*.csv` (reference)
- **Expected outputs:** `plots/histogram_transient_length.png`, `plots/regression_unscaled.png`
- **Test:** Run script
- **Status:** Document ✅/❌

### Appendix: Long-term Recovery
- **Script:** `code/long_term_recovery_plot.R`
- **Inputs:** 
  - `data/final/long_term_recovery_A_final.csv` (from Phase 1 or reference)
  - `data/final/long_term_recovery_B_final.csv` (from Phase 1 or reference)
- **Expected output:** `plots/long_term_recovery.png`
- **Test:** Run script
- **Status:** Document ✅/❌

---

## Phase 3: Validation (If 50-cell database was used)

### Compare Regenerated vs Reference Data
- **Files to compare:**
  - `covariates_*_growingseason.csv` (cannot compare - no reference)
  - `maps_regression_B_patches_*.csv` (if regenerated)
  - `maps_regression_B_model_*.csv` (if regenerated)
  - `long_term_recovery_A_final.csv` (if regenerated)

- **Validation approach:**
  - Check correlation between subset and full reference
  - Document RMSE, correlation coefficients
  - Note: Low correlation expected due to 50/5156 cell sampling

---

## Critical Rules

### DO NOT:
1. ❌ Overwrite or modify files in `data/final/` that have `.csv` extension without suffix
2. ❌ Delete reference data
3. ❌ Continue if a workflow blocker is found (missing script/data/function)

### DO:
1. ✅ Use full database first, switch to 50-cell only if RAM crash
2. ✅ Save new outputs with `_test` or `_50cell` suffix
3. ✅ Document every workflow blocker (missing data, broken code, logic errors)
4. ✅ Note which database was used for each step
5. ✅ Test plots even if they use reference data

---

## Output Document: FIGURE_TEST_RESULTS.md

### Structure:
```
# Figure Test Results

## Pipeline Processing Results
- 02d Climate Covariates: ✅/❌ (database used, errors if any)
- Maps Regression: ✅/❌ (database used, errors if any)
- Long-term Recovery: ✅/❌ (database used, errors if any)

## Figure Testing Results
- Figure 1: ✅/❌ (error details)
- Figure 2/3: ✅/❌
- Figure 4: ✅/❌
- Figure 5: ✅/❌
- Figure 6: ✅/❌
- Appendix X1: ✅/❌
- Appendix X2: ✅/❌
- Long-term Recovery: ✅/❌

## Workflow Blockers Found
- List any missing data, broken scripts, logic errors

## Validation Results (if 50-cell used)
- Comparison statistics

## Database Used
- Full: patches2.duckdb for steps X, Y, Z
- 50-cell: patches2_50cells_complete.duckdb for steps A, B, C

## RAM Issues Encountered
- Which steps crashed on full database
```

---

## Notes
- Total figures to test: 8 (F1, F2/3, F4, F5, F6, X1, X2, Long-term)
- Total pipeline scripts to run: 3 (02d, maps_regression_final, long_term_recovery_final)
- Reference data location: `data/final/` - PROTECTED
- New outputs location: `data/processed/` + `data/final/*_test.csv` or `*_50cell.csv`
