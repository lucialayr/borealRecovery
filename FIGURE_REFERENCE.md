# Figure Reproduction Reference

## Main Figures

| Figure | Script | Status | Data Files Needed | Data Status |
|--------|--------|--------|-------------------|-------------|
| Fig 1 | `Figure_01.R` | ⚠️ NOT TESTED | `patches2.duckdb` | ✅ EXISTS |
| Fig 2 & 3 | `validation_plots.R` | ✅ WORKING | `validation_B.csv`, `shp/validation_A.shp` | ✅ EXISTS |
| Fig 4 | `trajectories_niche_final_plot.R` | ⚠️ NOT TESTED | `trajectories_mean_A_*.csv` (6 files), `shp/trajectories_niche_B.shp` | ✅ REGENERATED, ✅ EXISTS |
| Fig 5 | `maps_regression_plot.R` | ❌ BLOCKED | `maps_regression_B_patches_*.csv` (2 files), `maps_regression_B_model_*.csv` (2 files) | ⚠️ EXISTS (can't regenerate) |
| Fig 6 | `random_forest_plot.R` | ⚠️ NOT TESTED | `random_forest_*.csv` (4 files) | ✅ EXISTS |

## Appendix Figures

| Figure | Script | Status | Data Files Needed | Data Status |
|--------|--------|--------|-------------------|-------------|
| X1: Climate | `X1_climate_data.R` | ❌ BLOCKED | 15 climate NetCDF files in `data/raw/climate_data/` | ❌ MISSING |
| X2: Histograms | `X2_results.R` | ⚠️ NOT TESTED | `maps_regression_B_patches_*.csv` (2 files) | ⚠️ EXISTS (can't regenerate) |
| Long-term Recovery | `long_term_recovery_plot.R` | ❌ BLOCKED | `long_term_recovery_A_final.csv`, needs `all_binary_data_*.csv` | ❌ MISSING |

---

**Legend:**
- ✅ WORKING = Tested and works | ⚠️ NOT TESTED = Can test now | ❌ BLOCKED = Missing required data
- ✅ EXISTS = File present | ✅ REGENERATED = Created from subset | ❌ MISSING = File absent

---

## Critical Missing Data

### Figure 5 Regeneration - Climate Files (16 files in `data/raw/climate_data/`):ily_inverted_1850_2300_boreal_yearlymax_growingseason.nc
mri-esm2-0_r1i1p1f1_picontrol_tas_daily_inverted_1850_2300_boreal_yearlymin_growingseason.nc
mri-esm2-0_r1i1p1f1_picontrol_tas_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc
mri-esm2-0_r1i1p1f1_picontrol_pr_daily_inverted_1850_2300_boreal_yearlysum.nc
mri-esm2-0_r1i1p1f1_picontrol_rsds_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc

mri-esm2-0_r1i1p1f1_ssp126_tas_daily_inverted_1850_2300_boreal_yearlymax_growingseason.nc
mri-esm2-0_r1i1p1f1_ssp126_tas_daily_inverted_1850_2300_boreal_yearlymin_growingseason.nc
mri-esm2-0_r1i1p1f1_ssp126_tas_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc
mri-esm2-0_r1i1p1f1_ssp126_pr_daily_inverted_1850_2300_boreal_yearlysum.nc
mri-esm2-0_r1i1p1f1_ssp126_rsds_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc

mri-esm2-0_r1i1p1f1_ssp585_tas_daily_inverted_1850_2300_boreal_yearlymax_growingseason.nc
mri-esm2-0_r1i1p1f1_ssp585_tas_daily_inverted_1850_2300_boreal_yearlymin_growingseason.nc
mri-esm2-0_r1i1p1f1_ssp585_tas_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc
mri-esm2-0_r1i1p1f1_ssp585_pr_daily_inverted_1850_2300_boreal_yearlysum.nc
mri-esm2-0_r1i1p1f1_ssp585_rsds_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc

hwsd_lpj_0.5.dat
```

**Blocks regeneration of:**
- Figure 5 data files
- Appendix X1
- Appendix X2 (uses existing reference, can't regenerate)

---

### To Regenerate Figure 4 Shapefiles (trajectories_niche_B.shp):

**Location:** `data/single_pft/`
```
cmass_picontrol_ibs.out
cmass_picontrol_bne.out
cmass_picontrol_tebs.out
cmass_picontrol_tundra.out
cmass_picontrol_otherc.out
```

### Figure 4 Shapefiles - Single PFT Data (8 files):
---

### To Generate Long-term Recovery Figure:

**Location:** Unknown (possibly `data/results/` or `data/random_forest/`)
```
all_binary_data_2015_2040.csv
all_binary_data_2075_2100.csv
```

**Blocks:**
- Long-term recovery appendix figure (cannot generate data file)

---

## Immediate Actions Available

### Can Test Now (3 figures):
1. ✅ Figure 1 - Test with 50-cell subset
2. ✅ Figure 6 - Test plotting with existing RF data
3. ✅ Appendix X2 - Test plotting with existing regression data

### Long-term Recovery - Binary Classification Data (location unknown):
```
all_binary_data_2015_2040.csv
all_binary_data_2075_2100.csv