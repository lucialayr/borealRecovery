# Figure Reproduction Status

**Last Updated:** February 27, 2026  
**Goal:** Reproduce all figures from paper and appendix using the 50-cell subset database

---

## Main Text Figures

### Figure 1: Study Area & Dominant PFT Over Time
**Script:** [code/Figure_01.R](code/Figure_01.R)  
**Status:** ⚠️ **NOT TESTED**

**Data Requirements:**
- ✅ Database: `patches2.duckdb` (full database needed for complete spatial coverage)
- ✅ External: Study region shapefile (`data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp`)

**Expected Outputs:**
- Study area map
- PFT dominance over time visualization

**Action Items:**
- [ ] Test with 50-cell subset database
- [ ] Determine if spatial coverage is adequate or if more cells needed
- [ ] May encounter RAM issues with full database

---

### Figure 2 & 3: Validation
**Script:** [code/validation_plots.R](code/validation_plots.R)  
**Status:** ✅ **WORKING** (tested Jan 26)

**Data Requirements:**
- ✅ Final data: `data/final/validation_B.csv` (exists)
- ✅ Shapefiles: `data/final/shp/validation_A.shp` (exists)
- ✅ External: Ecoregion and study region shapefiles (exist)

**Expected Outputs:**
- `plots/recovery_validation.png`
- Ecoregion map (validation_A_plot)
- Recovery comparison plot (validation_B_plot)

**Action Items:**
- ✅ Already tested and working
- Note: Uses external ABOVE data, no database needed

---

### Figure 4: Trajectories & Niche
**Script:** [code/trajectories_niche_final_plot.R](code/trajectories_niche_final_plot.R)  
**Status:** ⚠️ **PARTIALLY BLOCKED**

**Data Requirements:**
- ✅ Trajectories: `data/final/trajectories_mean_A_*.csv` (6 files - regenerated from subset)
- ⚠️ Shapefiles: `data/final/shp/trajectories_niche_B.shp` (exists but cannot regenerate)

**Missing for Full Reproduction:**
- ❌ `data/single_pft/cmass_picontrol_{pft}.out` (5 files)
- ❌ `data/raw/multi_pft/{scenario}_d150/cmass.out` (3 files)

**Expected Outputs:**
- Trajectory timeseries plots
- Niche space visualizations
- Maps with trajectory classifications

**Action Items:**
- [x] Trajectories data regenerated from subset (moderate correlation r~0.4 with full data)
- [ ] Test plotting with existing reference shapefiles
- [ ] Once single_pft/multi_pft data provided, regenerate shapefiles from subset

---

### Figure 5: Maps & Regression
**Script:** [code/maps_regression_plot.R](code/maps_regression_plot.R)  
**Status:** ❌ **BLOCKED - MISSING CLIMATE DATA**

**Data Requirements:**
- ⚠️ Regression: `data/final/maps_regression_B_patches_*.csv` (exists but cannot regenerate)
- ⚠️ Models: `data/final/maps_regression_B_model_*.csv` (exists but cannot regenerate)
- ⚠️ Shapefiles: `data/final/shp/maps_regression_A_final_*.shp` (exist)

**Missing for Full Reproduction:**
- ❌ **Climate NetCDF files (15 files):**
  - `mri-esm2-0_r1i1p1f1_{scenario}_tas_daily_*_boreal_yearly{max/min/avg}_growingseason.nc`
  - `mri-esm2-0_r1i1p1f1_{scenario}_pr_daily_*_boreal_yearlysum.nc`
  - `mri-esm2-0_r1i1p1f1_{scenario}_rsds_daily_*_boreal_yearlyavg_growingseason.nc`
  - For scenarios: picontrol, ssp126, ssp585
- ❌ **Soil data:** `hwsd_lpj_0.5.dat`

**Pipeline Blocked At:**
- `code/02d_climate_covariates.R` - Cannot process climate covariates
- `code/maps_regression_final.R` - Cannot generate regression data without covariates

**Expected Outputs:**
- Spatial maps of trajectory classes
- Regression model visualizations
- Climate-vegetation relationships

**Action Items:**
- [ ] **CRITICAL:** Obtain climate NetCDF files and soil data
- [ ] Run 02d_climate_covariates.R with subset database
- [ ] Run maps_regression_final.R to regenerate patch data
- [ ] Test plotting functions
- [ ] May encounter RAM issues - will address when encountered

---

### Figure 6: Random Forest
**Script:** [code/random_forest_plot.R](code/random_forest_plot.R)  
**Status:** ⚠️ **NOT TESTED** (Python models not run per user request)

**Data Requirements:**
- ✅ Final data: `data/final/random_forest_*.csv` (4 files exist from original analysis)

**Expected Outputs:**
- Random forest prediction visualizations
- Variable importance plots

**Action Items:**
- [ ] Test plotting with existing reference data
- Note: Not regenerating RF models per user decision

---

## Appendix Figures

### Appendix X1: Climate Data
**Script:** [code/X1_climate_data.R](code/X1_climate_data.R)  
**Status:** ❌ **BLOCKED - MISSING CLIMATE DATA**

**Data Requirements:**
- ❌ Raw climate NetCDF files (same as Figure 5)
- ❌ Additional climate variables from forcing data

**Missing for Full Reproduction:**
- Same climate NetCDF files as Figure 5

**Expected Outputs:**
- Climate forcing visualization
- Temperature, precipitation, radiation maps/timeseries

**Action Items:**
- [ ] Obtain climate NetCDF files
- [ ] Test with available data
- [ ] May encounter RAM issues

---

### Appendix X2: Results Histograms
**Script:** [code/X2_results.R](code/X2_results.R)  
**Status:** ⚠️ **DEPENDS ON FIGURE 5 DATA**

**Data Requirements:**
- ⚠️ `data/final/maps_regression_B_patches_*.csv` (exists but cannot regenerate)

**Expected Outputs:**
- Histograms of transient length
- Distribution plots of trajectory characteristics

**Action Items:**
- [ ] Test plotting with existing reference data
- [ ] Once Figure 5 data regenerated, validate with subset

---

### Appendix: Long-term Recovery
**Script:** [code/long_term_recovery_plot.R](code/long_term_recovery_plot.R)  
**Status:** ⚠️ **NOT TESTED - MISSING DATA FILE**

**Data Requirements:**
- ❌ `data/final/long_term_recovery_A_final.csv` (does not exist)
- ❌ `data/final/long_term_recovery_B_final.csv` (does not exist)

**Generation Script:** [code/long_term_recovery_final.R](code/long_term_recovery_final.R)

**Missing for Full Reproduction:**
- Depends on: `data/results/all_binary_data_{start_year}_{end_year}.csv` (not found in repo)
- This file may be in random forest output or needs generation

**Expected Outputs:**
- Long-term recovery trajectories
- PFT composition over time

**Action Items:**
- [ ] Investigate source of `all_binary_data_*.csv` files
- [ ] Run long_term_recovery_final.R if dependencies available
- [ ] Test plotting functions

---

## Summary Statistics

### Current Status:
- ✅ **WORKING (1/7):** Validation plots (F2/F3)
- ⚠️ **PARTIALLY WORKING (1/7):** Trajectories (F4) - data regenerated, shapefiles cannot be regenerated
- ⚠️ **NOT TESTED (3/7):** Figure 1, Figure 6, Long-term recovery
- ❌ **BLOCKED (2/7):** Figure 5 (Maps/Regression), Appendix X1 (Climate)
- ⚠️ **DEPENDS ON BLOCKED (1/7):** Appendix X2 (depends on F5)

### By Blocker Type:

#### ✅ Can Test Now (Use Existing Reference Data):
1. Validation plots (F2/F3) - Already working
2. Random Forest plots (F6) - Reference data exists
3. Appendix X2 - Reference data exists

#### ⚠️ Can Test With Warnings (May Need More Data):
1. Figure 1 - Needs full or larger subset database for spatial coverage
2. Trajectories plots (F4) - Data regenerated but shapefiles need single_pft data

#### ❌ Cannot Test Until Data Provided:
1. **Figure 5 (Maps/Regression)** - Needs 15 climate NetCDF + 1 soil file
2. **Appendix X1 (Climate)** - Needs same climate files
3. **Long-term recovery** - Needs `all_binary_data_*.csv` files (source unknown)

---

## Critical Blocking Issues

### Priority 1: Climate Data (Blocks 2 figures)
**Files needed in `data/raw/climate_data/`:**
```
mri-esm2-0_r1i1p1f1_picontrol_tas_daily_inverted_1850_2300_boreal_yearlymax_growingseason.nc
mri-esm2-0_r1i1p1f1_picontrol_tas_daily_inverted_1850_2300_boreal_yearlymin_growingseason.nc
mri-esm2-0_r1i1p1f1_picontrol_tas_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc
mri-esm2-0_r1i1p1f1_picontrol_pr_daily_inverted_1850_2300_boreal_yearlysum.nc
mri-esm2-0_r1i1p1f1_picontrol_rsds_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc
(+ same for ssp126 and ssp585 scenarios = 15 files total)
hwsd_lpj_0.5.dat
```
**Unlocks:** Figure 5, Appendix X1, Appendix X2 (regeneration)

### Priority 2: Single PFT Data (Blocks shapefile generation)
**Files needed in `data/single_pft/`:**
```
cmass_picontrol_ibs.out
cmass_picontrol_bne.out
cmass_picontrol_tebs.out
cmass_picontrol_tundra.out
cmass_picontrol_otherc.out
```
**Plus in `data/raw/multi_pft/{scenario}_d150/`:**
```
picontrol_d150/cmass.out
ssp126_d150/cmass.out
ssp585_d150/cmass.out
```
**Unlocks:** Shapefile regeneration for Figure 4

### Priority 3: Binary Classification Data (Blocks 1 figure)
**Files needed (location unknown):**
```
data/results/all_binary_data_2015_2040.csv
data/results/all_binary_data_2075_2100.csv
```
**Unlocks:** Long-term recovery appendix figure

---

## Next Steps

### Immediate Testing (No New Data Needed):
1. Test Figure 1 with 50-cell subset - assess spatial coverage
2. Test Figure 4 plotting with regenerated data + existing shapefiles
3. Test Figure 6 plotting with existing RF reference data
4. Test Appendix X2 with existing reference data

### Once Climate Data Provided:
1. Run `code/02d_climate_covariates.R` with subset database
2. Run `code/maps_regression_final.R` to regenerate Figure 5 data
3. Test Figure 5 plotting
4. Test Appendix X1 plotting

### Once Single PFT Data Provided:
1. Regenerate shapefiles in `trajectories_niche_processed_final.R`
2. Re-test Figure 4 plotting with new shapefiles

### Once Binary Data Located/Provided:
1. Run `code/long_term_recovery_final.R`
2. Test long-term recovery plotting

---

## RAM Considerations

Per user instruction: "We'll find out about RAM issues when we encounter them"

Likely RAM-intensive operations:
- Figure 1 processing (full database spatial analysis)
- Climate data processing (large NetCDF files)
- If issues arise, will implement chunking or optimization strategies
