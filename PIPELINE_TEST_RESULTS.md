# Pipeline Test Results - 50-Cell Subset

**Date:** January 26, 2026  
**Database:** patches2_50cells_complete.duckdb (1.7GB, 50 grid cells)  
**Status:** ✓ PARTIAL SUCCESS

---

## Summary

Successfully reproduced **Stage 1 (database processing)** and **Stage 2 (trajectory final data)** of the analysis pipeline using a 50-cell subset database. Generated trajectory aggregated means and verified plotting functionality.

---

## What Was Completed

### ✓ Stage 1: Database Processing

1. **02a - Trajectories** (Already completed in previous session)
   - Generated: `trajectories_{scenario}_{timespan}_{type}_rf.csv` (12 files)
   - Output: ~3.8M rows total across scenarios

2. **02b - AGC Trajectories** (Already completed)
   - Generated: `agc_recovery_{scenario}_{timespan}_.csv` (6 files)

3. **02c - Classified Trajectories** ✓ NEW
   - Generated: `classified_trajectories_processed__{timespan}.csv` (2 files)
   - Successfully classified recovery trajectory types

4. **02d - Climate Covariates** ✗ SKIPPED
   - Requires: `data/raw/climate_data/*.nc` files (not available)
   - Note: data/external has some climate data but not the format needed

5. **02e - Random Forest Input** ✗ NOT RUN
   - Would require 02d outputs

### ✓ Stage 2: Final Data Creation

1. **trajectories_niche_processed_final.R** ✓ PARTIAL
   - Generated trajectory CSV files:
     - `trajectories_mean_A_mean_{timespan}.csv` (2 files) ✓
     - `trajectories_mean_A_agc_{timespan}.csv` (2 files) ✓
     - `trajectories_mean_A_agc_classes_{timespan}.csv` (2 files) ✓
   - Skipped: Shapefile creation (needs raw single_pft data)
   - **Total: 6 CSV files generated**

2. **maps_regression_final.R** ✗ SKIPPED
   - Requires: Climate covariates from 02d
   - Reference files already exist in data/final/

3. **validation_final.R** ✗ NOT RUN
   - Would need external data checks

4. **random_forest_final.R** ✗ SKIPPED
   - Python models not run (per user request)

### ✓ Stage 3: Plotting

1. **validation_plots.R** ✓ TESTED
   - Successfully generated: `plots/recovery_validation.png`
   - Uses existing reference data from data/final/

---

## Validation Results

### Subset vs Full Data Comparison

Compared aggregated means from 50-cell subset against original full-data results:

| File | Correlation (r) | RMSE | Status |
|------|-----------------|------|--------|
| trajectories_mean_A_mean_2015_2040 | 0.44 | 0.20 | ⚠ Moderate |
| trajectories_mean_A_mean_2075_2100 | 0.44 | 0.19 | ⚠ Moderate |
| trajectories_mean_A_agc_2015_2040 | 0.01 | 0.40 | ⚠ Low |
| trajectories_mean_A_agc_2075_2100 | 0.00 | 0.41 | ⚠ Low |
| trajectories_mean_A_agc_classes_2015_2040 | 0.04 | 0.36 | ⚠ Low |
| trajectories_mean_A_agc_classes_2075_2100 | 0.03 | 0.36 | ⚠ Low |

**Interpretation:**
- Moderate correlations (r ~ 0.4) are expected given 50/5156 cells = 0.97% sampling
- Low correlations for AGC metrics suggest these may be more spatially variable
- RMSE values indicate substantial absolute differences
- For full reproducibility, more cells or different sampling strategy may be needed

---

## Files Generated

### data/processed/ (26 files total)
```
✓ trajectories_{scenario}_{timespan}_timeseries_rf.csv (12 files)
✓ trajectories_{scenario}_{timespan}_pointvalues_rf.csv (12 files)  
✓ agc_recovery_{scenario}_{timespan}_.csv (6 files)
✓ classified_trajectories_processed__{timespan}.csv (2 files)
✓ sampled_grid_cells_50.csv (1 file)
✗ covariates_* (missing - needs raw climate data)
```

### data/final/ (6 NEW files)
```
✓ trajectories_mean_A_mean_2015_2040.csv
✓ trajectories_mean_A_mean_2075_2100.csv
✓ trajectories_mean_A_agc_2015_2040.csv
✓ trajectories_mean_A_agc_2075_2100.csv
✓ trajectories_mean_A_agc_classes_2015_2040.csv
✓ trajectories_mean_A_agc_classes_2075_2100.csv
```

### plots/
```
✓ recovery_validation.png (generated successfully)
```

---

## Known Limitations

### Cannot Reproduce Without Additional Data:

1. **Climate covariate processing (02d)**
   - Needs: `data/raw/climate_data/` with processed NetCDF files
   - Blocks: maps_regression_final.R

2. **Shapefile generation**
   - Needs: `data/single_pft/` and `data/raw/multi_pft/` directories
   - Impact: Cannot regenerate spatial visualizations

3. **Random forest models**
   - Python models not run (per user request)
   - Impact: Cannot validate RF predictions

### Subset Limitations:

1. **Small sample size** (50 cells / 0.97%)
   - Low correlations for some metrics
   - May not capture full spatial variability
   - Consider increasing to 100-200 cells for better representativeness

2. **Spatial clustering?**
   - Current sample is random - may miss regional patterns
   - Consider stratified sampling by ecoregion/latitude

---

## Scripts Created/Modified

### New Helper Scripts (root directory):
- `run_02c_complete.R` - Run 02c with subset database
- `run_stage2_traj.R` - Generate trajectory final CSVs
- `compare_subset_vs_full.R` - Validation comparisons
- `validate_trajectories.R` - Trajectory-specific validation

### Fixed Issues:
- ✓ Removed install.packages() calls from trajectories_niche_processed_final.R
- ✓ Fixed syntax error in validation_plots.R (missing closing parentheses)

---

## Next Steps

### Option A: Continue with Current Subset
- Test remaining plotting scripts
- Document which analyses work with subset
- Accept validation caveats

### Option B: Improve Subset
- Increase to 100-200 cells for better statistical power
- Use stratified sampling by ecoregion
- Re-run validation to check improved correlations

### Option C: Focus on Documentation
- Document reproducible parts (plotting from data/final/)
- Note data requirements for full reproduction
- Create user guide for partial reproduction

---

## Recommendations

1. **For publication reproducibility:**
   - Current setup allows reproduction of plots from data/final/ ✓
   - Subset database allows testing/understanding pipeline
   - Full reproduction requires 25GB database

2. **For validation:**
   - Low correlations suggest subset may not fully represent full data
   - Consider this a "pipeline test" rather than "exact reproduction"
   - For exact validation, would need larger subset or full database

3. **For documentation:**
   - Update REPRODUCE.md with current findings
   - Note three reproduction levels: plots only, subset pipeline, full pipeline
   - Document data requirements clearly

---

## Files for Review

- `compare_subset_vs_full.R` - See validation metrics
- `data/final_from_full/` - Backup of original full-data files
- `plots/recovery_validation.png` - Example generated plot
- Helper scripts in root directory
