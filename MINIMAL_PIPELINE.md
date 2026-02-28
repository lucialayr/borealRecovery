# Minimal Pipeline for Figures 2-4 (Validation, Trajectories, Maps/Regression)

## Summary

**Target Figures:**
- Figure 2/3: Validation 
- Figure 4: Trajectories + Niche
- Figure 5: Maps/Regression

## Required Database Tables

**Only cmass tables needed** (3 of 12 tables):
- ✅ picontrol_d150_npp_cmass
- ✅ ssp126_d150_cmass  
- ✅ ssp585_d150_cmass

**NOT needed:**
- ❌ All *_anpp tables (used only for Random Forest)
- ❌ All *_exp_est tables (used only for Random Forest)
- ❌ All *_fpc tables (not used in main analysis)

## Complete Pipeline

### Figure 2/3: Validation
```
00_validation.R
  ↓
data/final/validation_B.csv
  ↓
validation_plots.R
  ↓
Figure 2/3
```
**Database needed:** NONE (uses external ABOVE data)

---

### Figure 4: Trajectories + Niche
```
patches2.duckdb (cmass tables only)
  ↓
02a_trajectories_database_processed.R
  - Needs: *_cmass tables
  - Skips: anpp processing (line 61-63)
  ↓
data/processed/trajectories_*_timeseries_rf.csv
  ↓
02b_agc_trajectories_processed.R
  - Needs: *_cmass tables
  ↓
data/processed/agc_recovery_*.csv
  ↓
02c_classified_trajectories_processed.R
  ↓
data/processed/classified_trajectories_processed__*.csv
  ↓
trajectories_niche_processed_final.R
  - Reads: trajectories_*_timeseries_rf.csv
  - Reads: agc_recovery_*.csv
  - Reads: classified_trajectories_processed__*.csv
  - Also needs: data/single_pft/*.out files (external)
  ↓
data/final/trajectories_mean_A_mean_*.csv
data/final/trajectories_mean_A_sample_*.csv
data/final/trajectories_mean_A_agc_*.csv
data/final/trajectories_mean_A_agc_classes_*.csv
  ↓
trajectories_niche_final_plot.R
  ↓
Figure 4
```

---

### Figure 5: Maps/Regression
```
patches2.duckdb (cmass tables only)
  ↓
02a, 02b, 02c (same as above)
  ↓
02d_climate_covariates.R
  - Needs: external climate data
  ↓
data/processed/covariates_*_growingseason.csv
  ↓
maps_regression_final.R
  - Reads: classified_trajectories_processed__*.csv
  - Reads: covariates_*_growingseason.csv
  ↓
data/final/maps_regression_B_patches_*.csv
data/final/maps_regression_B_model_*.csv
  ↓
maps_regression_plot.R
  ↓
Figure 5
```

---

## Key Scripts to Run (in order)

### Stage 1: Database Processing (02*.R)
1. **02a_trajectories_database_processed.R**
   - Uses: cmass tables only
   - Problem: Line 61-63 tries to load anpp (needs to be skipped)
   - Output: trajectories_*_timeseries_rf.csv

2. **02b_agc_trajectories_processed.R**
   - Uses: cmass tables only
   - Output: agc_recovery_*.csv

3. **02c_classified_trajectories_processed.R**
   - Uses: previous outputs
   - Output: classified_trajectories_processed__*.csv

4. **02d_climate_covariates.R**
   - Uses: external climate data (not database)
   - Output: covariates_*_growingseason.csv

### Stage 2: Final Data (*_final.R)
5. **trajectories_niche_processed_final.R**
   - Reads: all processed data from 02a, 02b, 02c
   - Also needs: data/single_pft/*.out (external)
   - Output: trajectories_mean_A_*.csv

6. **maps_regression_final.R**
   - Reads: classified_trajectories_processed__*.csv + covariates
   - Output: maps_regression_B_*.csv

### Stage 3: Plots (*_plot.R)
7. **validation_plots.R** → Figure 2/3
8. **trajectories_niche_final_plot.R** → Figure 4
9. **maps_regression_plot.R** → Figure 5

---

## Subset Strategy

**Recommended: 50-cell subset with cmass-only**
- Database size: ~375 MB (vs ~750 MB with all tables)
- Tables: 3 tables (cmass only)
- Sufficient for statistical validity
- Fits easily in 75GB free space

**Alternative: Modify 02a to skip anpp**
- Comment out lines 61-63 (anpp loading)
- Comment out anpp references in joins
- Allows using 6-table subset (cmass + exp_est)
- More complex but saves space
