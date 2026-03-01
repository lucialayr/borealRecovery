# Full Pipeline Reproduction Plan

**Date**: February 28, 2026  
**Branch**: revision  
**Database**: patches2.duckdb (25GB)

---

## 🎯 REPRODUCTION GOAL

**Primary Objective**: Reproduce Figure 4 (trajectories_niche) and validate that we can generate `data/final/*.csv` files from `data/processed/` that exactly match the reference data from the server (`data/final/*.csv.ref`).

**Critical Understanding**:
- `data/final/*.csv.ref` = **Original correct data from server** (NEVER modify!)
- `data/processed/` = **Already validated and correct** (duplicate bug fixed)
- **Goal**: Regenerate `data/final/*.csv` and compare against `.ref` files
- **Success**: Exact match between generated and reference files
- **Skip**: long_term_recovery (RAM constraints)

---

## Current Status Summary

### ✅ Phase 1: Database Processing (COMPLETED)

1. **Syntax Fixes** (20+ errors across 8 scripts):
   - Fixed missing closing parentheses in function calls
   - Fixed path construction with `here()` → `paste0(here(), "/")`
   - Added missing library statements (sf, cowplot)
   - Fixed return statements and `.groups` arguments

2. **Theme Application Fix**:
   - Moved `source(here("code", "utils.R"))` to AFTER library loads in all 7 plotting scripts
   - Custom theme now applies correctly (verified with validation_plots.R)

3. **Database Duplicate Bug Fixes** ✅ **COMPLETED**:
   - **Problem**: Database has 2x duplicates per row, causing:
     - Relative values summing to 0.5 instead of 1.0
     - AGC Total values 2x too large
   - **Fixed scripts**:
     - `02a_trajectories_database_processed.R` line 54: Moved `unique()` before `group_by()`
     - `02b_agc_trajectories_processed.R` line 53: Added `unique()` before `group_by()`
   - **Generated & Validated**:
     - 14 files in `data/processed/`: trajectories, AGC, classifications, pointvalues, covariates
     - Files in `data/processed/` are identical to `data/processed_original/`
   - **Validation**: 100% match on all common rows with original data

---

### ⚠️ Phase 2: Final Data Generation (IN PROGRESS)

**Current Status**: Files generated but DO NOT match reference data

**Reference Files to Match** (6 total):
- `trajectories_mean_A_mean_2015_2040.csv.ref` (1516 lines)
- `trajectories_mean_A_mean_2075_2100.csv.ref` (1516 lines)
- `trajectories_mean_A_agc_2015_2040.csv.ref` (379 lines)
- `trajectories_mean_A_agc_2075_2100.csv.ref` (379 lines)
- `trajectories_mean_A_agc_classes_2015_2040.csv.ref` (757 lines)
- `trajectories_mean_A_agc_classes_2075_2100.csv.ref` (757 lines)

**Validation Results** (Feb 28, 2026):
- ❌ **trajectories_mean_A_mean**: Generated 1891 lines vs 1516 reference (25% more data)
  - Generated columns: `s, age, PFT, relative_mean`
  - Reference columns: `age, PFT_long, relative_mean, s`
  - Column order AND names differ
- ❌ **trajectories_mean_A_agc**: Same line count (379) but content differs
- ❌ **trajectories_mean_A_agc_classes**: Same line count (757) but content differs

**Root Cause**: Script `trajectories_niche_processed_final.R` generates different output format than reference

---

## Pipeline Architecture

```
DATABASE (patches2.duckdb)
    ↓
[STEP 1: Database → Processed] ✅ COMPLETED
    02a_trajectories_database_processed.R  → data/processed/trajectories_*_timeseries_rf.csv (6 files)
                                            → data/processed/trajectories_*_pointvalues_rf.csv (6 files)
    02b_agc_trajectories_processed.R       → data/processed/agc_recovery_*.csv (6 files)
    02c_classified_trajectories_processed.R → data/processed/classified_trajectories_processed_*.csv (2 files)
    02d_climate_covariates.R               → data/processed/covariates_*_growingseason.csv (6 files)
    ↓
[STEP 2: Processed → Final] ⚠️ IN PROGRESS
    trajectories_niche_processed_final.R   → data/final/trajectories_mean_A_mean_*.csv (2 files)
                                            → data/final/trajectories_mean_A_sample_*.csv (2 files)
                                            → data/final/trajectories_mean_A_agc_*.csv (2 files)
                                            → data/final/trajectories_mean_A_agc_classes_*.csv (2 files)
    ↓
[STEP 3: Plotting] 
    trajectories_niche_final_plot.R        → Figure 4 ✅ Generated (needs validation)
```

---

## 🔍 IMMEDIATE ACTION PLAN

### Investigation Needed:

1. **Check reference file structure**:
   - Why do reference files have different column order?
   - Column name `PFT` vs `PFT_long` - which is correct?
   - Are there two different versions of the script?

2. **Check for script versions**:
   - Is there an older version of `trajectories_niche_processed_final.R` that matches `.ref` format?
   - Check git history for changes to output format

3. **Line count discrepancy** (1891 vs 1516):
   - Generated has 375 more rows (25% increase)
   - Need to identify what extra data is being included
   - Compare unique values of age, scenario, PFT between generated and reference

4. **Floating point differences**:
   - Even with same line counts, AGC files differ
   - May be rounding or calculation order differences
   - Need detailed row-by-row comparison

### Questions for User:

1. **Should I regenerate the files?** The current files were generated today (Feb 28) from the fixed processed data. Should I:
   - Keep them as-is and investigate differences?
   - Delete and regenerate?
   - Try to find/fix the script to match reference format?

2. **Column order**: Reference has `age, PFT_long, relative_mean, s` but generated has `s, age, PFT, relative_mean`. Should I:
   - Reorder columns to match?
   - Check if there's a script parameter controlling this?

3. **PFT naming**: Reference uses `PFT_long`, generated uses `PFT`. Are these supposed to be identical after `long_names_pfts()` transformation?

4. **Validation tolerance**: For AGC files with same line counts, should we:
   - Expect exact byte-for-byte match?
   - Allow small floating point differences (< 1e-10)?
   - Check if it's just rounding/formatting differences?

---

## Next Steps (Pending User Confirmation)

**Option A**: Investigate and fix script
1. Compare script versions in git history
2. Check if `PFT` vs `PFT_long` column name changed
3. Debug why 375 extra rows are generated
4. Fix script to match reference format
5. Regenerate and validate

**Option B**: Detailed comparison first
1. Export detailed diff of generated vs reference files
2. Identify patterns in differences (specific ages, PFTs, scenarios)
3. Determine if differences are bugs or improvements
4. Decide whether to update reference or fix script

