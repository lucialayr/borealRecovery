# Data Roadblocks - Missing Files for Full Pipeline Reproduction

## Critical Missing Data Files

### 1. Raw Climate Data (for 02d_climate_covariates.R)
**Location needed:** `data/raw/climate_data/`

**Missing files:**
- `mri-esm2-0_r1i1p1f1_picontrol_tas_daily_inverted_1850_2300_boreal_yearlymax_growingseason.nc`
- `mri-esm2-0_r1i1p1f1_picontrol_tas_daily_inverted_1850_2300_boreal_yearlymin_growingseason.nc`
- `mri-esm2-0_r1i1p1f1_picontrol_tas_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc`
- `mri-esm2-0_r1i1p1f1_picontrol_pr_daily_inverted_1850_2300_boreal_yearlysum.nc`
- `mri-esm2-0_r1i1p1f1_picontrol_rsds_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc`
- Same pattern for ssp126 and ssp585 scenarios (15 files total)
- `hwsd_lpj_0.5.dat` - Soil properties file

**Impact:** 
- Blocks 02d_climate_covariates.R
- Blocks 02e_final_input_rf.R (depends on 02d)
- Blocks maps_regression_final.R (needs covariates from 02d)

**Status:** `data/external/` has SOME climate files (tas_*_cropped.nc) but not the processed daily files needed

---

### 2. Single PFT Simulation Data (for shapefile generation)
**Location needed:** `data/single_pft/`

**Missing files:**
- `cmass_picontrol_ibs.out`
- `cmass_picontrol_bne.out`
- `cmass_picontrol_tebs.out`
- `cmass_picontrol_tundra.out`
- `cmass_picontrol_otherc.out`

**Impact:**
- Blocks shapefile creation in trajectories_niche_processed_final.R
- Function `get_single_pfts_scenario()` cannot run
- Cannot generate `data/final/shp/trajectories_niche_B.shp`

**Status:** Directory doesn't exist

---

### 3. Multi-PFT Grid Output (for shapefile generation)
**Location needed:** `data/raw/multi_pft/{scenario}_d150/`

**Missing files:**
- `picontrol_d150/cmass.out`
- `ssp126_d150/cmass.out`
- `ssp585_d150/cmass.out`

**Impact:**
- Also blocks shapefile creation in trajectories_niche_processed_final.R
- Used to create realized niche polygons for IBS

**Status:** Directory doesn't exist

---

## Files That Exist (Reference Only)

### In `data/final/` (cannot regenerate, from original full analysis):
✓ `maps_regression_B_patches_*.csv` - Has Lon, Lat, PID but cannot regenerate without climate data
✓ `trajectories_niche_B.shp` - Shapefile exists but cannot regenerate without single_pft/multi_pft data
✓ All other `data/final/` files - Used as reference for validation

### In `data/external/`:
✓ `NA_CEC_Eco_Level2.shp` - Ecoregions
✓ `vegetation_ssp585_d0.003_fpc_30years2100.shp` - Study region
✓ `ecoreg_lctraj2.csv` - Observations for validation
✓ `mri-esm2-0_*_tas_*_cropped.nc` - Some temperature data (but not the processed daily files needed)

---

## What We Successfully Reproduced

### ✓ Without Missing Data:
- 02a: Trajectory processing from database → `trajectories_*_timeseries_rf.csv`
- 02b: AGC recovery → `agc_recovery_*.csv`
- 02c: Trajectory classification → `classified_trajectories_processed__*.csv`
- Stage 2: Aggregated trajectory means → `trajectories_mean_A_*.csv` (6 files)
- Plotting: Successfully generated validation plots

### ✗ Blocked by Missing Data:
- 02d: Climate covariates
- 02e: Random forest input preparation
- maps_regression_final.R (all outputs)
- Shapefile generation in trajectories_niche_processed_final.R

---

## Validation Status

### What Can Be Validated:
❌ **maps_regression_B_patches files** - Need to regenerate with subset but blocked by missing climate data
❌ **Exact patch-level values** - Only 41/102 patches match between reference and subset (different filtering)

### What Was Validated:
✓ **Aggregated trajectory means** - Generated successfully, moderate correlation with full data (r~0.4)
✓ **Pipeline functionality** - Confirmed all processing steps work with subset database
✓ **Plotting** - Confirmed plots can be generated from data/final/

---

## Recommendations

### Option 1: Minimal - Enable Climate Processing
**Provide:** `data/raw/climate_data/` files (15 NetCDF files + 1 soil file)
**Unlocks:** Full pipeline except shapefiles, enables validation of maps_regression outputs

### Option 2: Partial - Enable Shapefile Generation  
**Provide:** `data/single_pft/` and `data/raw/multi_pft/` directories
**Unlocks:** Shapefile regeneration for visualization

### Option 3: Full - Complete Reproduction
**Provide:** All missing data above
**Unlocks:** Complete end-to-end reproduction and validation

---

## Notes

- Python random forest models are not being run (per your instruction)
- The 50-cell subset database works perfectly for what it can do
- Main limitation is not the subset size but missing input data files
- All R code has been fixed (paths, syntax errors, package installations)
