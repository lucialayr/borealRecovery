# Script Dependencies and Data Flow

This document maps the dependencies between scripts and data files in the borealRecovery repository.

## Data Processing Pipeline

### Level 1: Database → Processed Data

Scripts that read from `patches2.duckdb` and write to `data/processed/`:

#### `02a_trajectories_database_processed.R`
- **Input:** patches2.duckdb (scenarios: ssp585, picontrol, ssp126; years: 2015-2040, 2075-2100)
- **Output:**
  - `data/processed/trajectories_{scenario}_{start}_{end}_timeseries_rf.csv`
  - `data/processed/trajectories_{scenario}_{start}_{end}_pointvalues_rf.csv`
  - `data/processed/trajectories_{scenario}_{start}_{end}_{variable}_{length}.csv` (validation data)

#### `02b_agc_trajectories_processed.R`
- **Input:** patches2.duckdb
- **Output:**
  - `data/processed/agc_recovery_{scenario}_{start}_{end}_.csv`

#### `02c_classified_trajectories_processed.R`
- **Input:** patches2.duckdb
- **Output:**
  - `data/processed/classified_trajectories_processed__{start}_{end}.csv`

#### `02d_climate_covariates.R`
- **Input:** 
  - `data/raw/climate_data/mri-esm2-0_*.nc` (climate data files)
  - `data/raw/climate_data/hwsd_lpj_0.5.dat` (soil properties)
- **Output:**
  - `data/processed/covariates_{scenario}_{start}_{end}_growingseason.csv`

#### `02e_final_input_rf.R`
- **Input:**
  - `data/processed/trajectories_{scenario}_{start}_{end}_timeseries_rf.csv`
  - `data/processed/trajectories_{scenario}_{start}_{end}_pointvalues_rf.csv`
  - `data/processed/covariates_{scenario}_{start}_{end}_growingseason.csv`
- **Output:**
  - `data/random_forest/data_{scenario}_{start}_{end}.csv`

---

### Level 2: Processed Data → Final Data

Scripts that read from `data/processed/` and write to `data/final/`:

#### `validation_final.R`
- **Input:**
  - `data/external/NA_CEC_Eco_Level2.shp` (ecoregions)
  - `data/raw/multi_pft/picontrol_d150/cmass.out` (LPJ-GUESS grid data)
  - `data/processed/trajectories_picontrol_2015_2040_fpc_200.csv`
  - `data/external/ecoreg_lctraj2.csv` (observations)
- **Output:**
  - `data/final/shp/validation_A.shp`
  - `data/final/validation_B.csv`
  - `data/processed/above_ecoregion_lpjguess_grid.csv` (intermediate)

#### `trajectories_niche_processed_final.R`
- **Input:**
  - `data/raw/multi_pft/{scenario}_d150/cmass.out`
  - `data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp`
  - `data/processed/trajectories_{scenario}_{start}_{end}_timeseries_rf.csv`
  - `data/processed/agc_recovery_{scenario}_{start}_{end}_.csv`
  - `data/processed/classified_trajectories_processed__{start}_{end}.csv`
- **Output:**
  - `data/final/shp/trajectories_niche_B.shp`
  - `data/final/trajectories_mean_A_mean_{start}_{end}.csv`
  - `data/final/trajectories_mean_A_sample_{start}_{end}.csv` (not currently in repo)
  - `data/final/trajectories_mean_A_agc_{start}_{end}.csv`
  - `data/final/trajectories_mean_A_agc_classes_{start}_{end}.csv`

#### `maps_regression_final.R`
- **Input:**
  - `data/processed/classified_trajectories_processed__{start}_{end}.csv`
  - `data/processed/covariates_{scenario}_{start}_{end}_growingseason.csv`
- **Output:**
  - `data/final/shp/maps_regression_A_final_{start}_{end}.shp`
  - `data/final/maps_regression_AIC_{start}_{end}.csv`
  - `data/final/maps_regression_B_patches_{start}_{end}.csv`
  - `data/final/maps_regression_B_model_{start}_{end}.csv`
  - `data/processed/all_binary_data_{start}_{end}.csv` (intermediate)

#### `random_forest_final.R`
- **Input:**
  - `data/random_forest/results/{scenario}_{timespan}_seed_{i}_mode_{mode}_k_{k}_m{m}_predictions.csv`
  - `data/random_forest/results/{scenario}_{timespan}_seed_{i}_mode_{mode}_k_{k}_m{m}_sfs_results.csv`
- **Output:**
  - `data/final/random_forest_A_{timespan}.csv`
  - `data/final/random_forest_B_{timespan}.csv`

#### `long_term_recovery_final.R`
- **Input:**
  - patches2.duckdb
  - `data/results/all_binary_data_{start}_{end}.csv` (NOTE: typo - should be data/processed)
- **Output:**
  - `data/final/long_term_recovery_A_final.csv`
  - `data/final/long_term_recovery_B_final.csv`

---

### Level 3: Final Data → Plots

Scripts that read from `data/final/` and create plots in `plots/`:

#### `validation_plots.R`
- **Input:**
  - `data/final/shp/validation_A.shp`
  - `data/final/validation_B.csv`
  - `data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp`
- **Output:**
  - `plots/recovery_validation.pdf`
  - `plots/recovery_validation.png`

#### `trajectories_niche_final_plot.R`
- **Input:**
  - `data/final/shp/trajectories_niche_B.shp`
  - `data/final/trajectories_mean_A_mean_{start}_{end}.csv`
  - `data/final/trajectories_mean_A_sample_{start}_{end}.csv`
  - `data/final/trajectories_mean_A_agc_{start}_{end}.csv`
  - `data/final/trajectories_mean_A_agc_classes_{start}_{end}.csv`
- **Output:**
  - `plots/trajectories_niche_{start}_{end}.pdf`
  - `plots/trajectories_niche_{start}_{end}.png`

#### `maps_regression_plot.R`
- **Input:**
  - `data/final/shp/maps_regression_A_final_{start}_{end}.shp`
  - `data/final/maps_regression_AIC_{start}_{end}.csv`
  - `data/final/maps_regression_B_patches_{start}_{end}.csv`
  - `data/final/maps_regression_B_model_{start}_{end}.csv`
  - `data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp`
- **Output:**
  - `plots/maps_regression_{start}_{end}.pdf`
  - `plots/maps_regression_{start}_{end}.png`

#### `random_forest_plot.R`
- **Input:**
  - `data/final/random_forest_A_{timespan}.csv`
  - `data/final/random_forest_B_{timespan}.csv`
- **Output:**
  - `plots/results_rf_{timespan}.pdf`
  - `plots/results_rf_{timespan}.png`

#### `long_term_recovery_plot.R`
- **Input:**
  - `data/final/long_term_recovery_A_final.csv`
  - `data/final/long_term_recovery_B_final.csv`
- **Output:**
  - `plots/long_term_recovery.pdf`
  - `plots/long_term_recovery.png`

---

## Execution Order

To reproduce the analysis from scratch:

### Phase 1: Process Database
```R
# Run these in order:
source(here("code", "02a_trajectories_database_processed.R"))  # Creates trajectories data
source(here("code", "02b_agc_trajectories_processed.R"))       # Creates AGC data
source(here("code", "02c_classified_trajectories_processed.R")) # Classifies trajectories
source(here("code", "02d_climate_covariates.R"))                # Processes climate data
source(here("code", "02e_final_input_rf.R"))                    # Prepares RF input
```

### Phase 2: Create Final Data
```R
source(here("code", "validation_final.R"))
source(here("code", "trajectories_niche_processed_final.R"))
source(here("code", "maps_regression_final.R"))
source(here("code", "random_forest_final.R"))  # Requires Python RF models to have run
source(here("code", "long_term_recovery_final.R"))
```

### Phase 3: Generate Plots
```R
source(here("code", "validation_plots.R"))
source(here("code", "trajectories_niche_final_plot.R"))
source(here("code", "maps_regression_plot.R"))
source(here("code", "random_forest_plot.R"))
source(here("code", "long_term_recovery_plot.R"))
```

---

## Critical Dependencies

### External Data (must be present)
- `data/external/NA_CEC_Eco_Level2.shp` - Ecoregions
- `data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp` - Study region
- `data/external/ecoreg_lctraj2.csv` - Observations for validation
- `data/external/mri-esm2-0_*.nc` - Climate data for mapping
- `data/ABOVE_agb_lpjformat.txt` - Validation data
- `data/spinup_cmass_2005.out` - Spinup data

### Raw Data (from Zenodo, not in repo)
- `data/raw/multi_pft/{scenario}_d150/cmass.out` - Grid-level LPJ-GUESS output
- `data/raw/climate_data/*.nc` - Daily climate data
- `data/raw/climate_data/hwsd_lpj_0.5.dat` - Soil properties

### Database
- `patches2.duckdb` (25GB, 451M rows per table)

---

## Known Issues

1. **Path typo in long_term_recovery_final.R**: Reads from `data/results/` instead of `data/processed/`
2. **Missing sample file**: `trajectories_mean_A_sample_{start}_{end}.csv` is generated but not in repo
3. **Single PFT data**: `trajectories_niche_processed_final.R` reads from `data/single_pft/` which doesn't exist in repo structure
