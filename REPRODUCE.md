# Reproducing the Analysis

This document provides step-by-step instructions for reproducing the analysis in this repository.

## Prerequisites

### Software Requirements
- R version 4.4.1 or higher
- Python 3.x (for random forest models)
- Required R packages (see [Installation](#installation))

### Hardware Requirements
- **With Full Database (25GB):** 32+ GB RAM recommended
- **With Subset Database (0.7GB):** 8+ GB RAM sufficient

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/lucialayr/borealRecovery.git
cd borealRecovery
```

### 2. Install R Packages
```R
# Install required packages
packages = c("here", "tidyverse", "duckdb", "DBI", "terra", "sf", 
             "cowplot", "scico", "ggnewscale", "rnaturalearth", 
             "rnaturalearthdata", "MASS", "zoo", "splines")

install.packages(packages)
```

### 3. Obtain Data

#### Option A: Generate Plots Only (Simplest)
The repository includes `data/final/` with all processed data needed for plotting.

**No additional data download required!**

Skip to [Generating Plots](#generating-plots).

#### Option B: Reproduce Full Analysis with Subset (Recommended for Local)
Download the subset database (recommended for local reproduction):

1. Download `patches2_subset.duckdb` (~0.7 GB) from Zenodo: [Link TBD]
2. Place in repository root directory

#### Option C: Reproduce Full Analysis with Complete Database
Download complete database from Zenodo (https://doi.org/10.5281/zenodo.13731857):

1. Download `patches2.duckdb` (25 GB)
2. Download raw data files to `data/raw/`
3. Requires high-performance computing environment

---

## Quick Start: Generate Plots

If you just want to reproduce the figures using existing processed data:

```R
library(here)

# Generate all main figures
source(here("code", "validation_plots.R"))           # Figure 3
source(here("code", "trajectories_niche_final_plot.R"))  # Figure 4  
source(here("code", "maps_regression_plot.R"))       # Figure 5
source(here("code", "random_forest_plot.R"))         # Figure 6

# Plots will be saved to plots/
```

---

## Reproducing the Full Analysis

### Understanding the Data Pipeline

The analysis follows a three-stage pipeline:

```
Stage 1: Database → Processed Data
  patches2.duckdb → data/processed/*.csv

Stage 2: Processed Data → Final Data
  data/processed/*.csv → data/final/*.csv

Stage 3: Final Data → Plots
  data/final/*.csv → plots/*.pdf
```

### Stage 1: Process Database

**Note:** This stage requires either the full database (25GB) or subset database (0.7GB).

```R
library(here)

# Process patch-level data
source(here("code", "02a_trajectories_database_processed.R"))
source(here("code", "02b_agc_trajectories_processed.R"))
source(here("code", "02c_classified_trajectories_processed.R"))

# Process climate covariates (requires data/raw/climate_data/)
source(here("code", "02d_climate_covariates.R"))

# Prepare random forest input
source(here("code", "02e_final_input_rf.R"))
```

**Output:** Files in `data/processed/`

### Stage 2: Create Final Data

```R
# Validation data
source(here("code", "validation_final.R"))

# Trajectory analysis
source(here("code", "trajectories_niche_processed_final.R"))

# Regression analysis
source(here("code", "maps_regression_final.R"))

# Long-term recovery
source(here("code", "long_term_recovery_final.R"))

# Random forest results (requires running Python models first)
source(here("code", "random_forest_final.R"))
```

**Output:** Files in `data/final/`

### Stage 3: Generate Plots

```R
# All plotting scripts
source(here("code", "validation_plots.R"))
source(here("code", "trajectories_niche_final_plot.R"))
source(here("code", "maps_regression_plot.R"))
source(here("code", "random_forest_plot.R"))
source(here("code", "long_term_recovery_plot.R"))
```

**Output:** Plots in `plots/`

---

## Random Forest Models

The random forest models require Python and were run on a computing cluster.

### Running the Models

```bash
cd code/python

# Prepare data (creates zarr files)
jupyter notebook 01_Prepare_data.ipynb

# Run models (uses SLURM job scheduler)
# Edit template_start_rf.sbatch as needed for your system
sbatch template_start_rf.sbatch
```

The models generate results in `data/random_forest/results/` which are then processed by `random_forest_final.R`.

---

## Working with the Subset Database

The subset database contains 150 randomly sampled grid cells (3% of full data), providing:
- ~3,750 patches across the study region
- ~15-20 disturbed patches per time period
- Sufficient data for statistical analyses

### Subset Specifications
- **Sampling method:** Random spatial sampling, stratified by scenario
- **Grid cells:** 150 out of 5,156 total
- **Database size:** ~0.7 GB (vs 25 GB full)
- **Seed:** 42 (for reproducibility)
- **Sampled cells list:** `data/processed/sampled_grid_cells.csv`

### Validating Subset Results

Since the subset is a true subset of the full data, you can validate results by comparing to `data/final/`:

```R
library(here)
library(tidyverse)

# Example: Compare validation results
full_data = read_csv(here("data", "final", "validation_B.csv"))
subset_data = read_csv(here("data", "final", "validation_B.csv"))  # After running with subset

# Filter full data to subset grid cells
sampled_cells = read_csv(here("data", "processed", "sampled_grid_cells.csv"))
# ... perform comparison
```

---

## File Structure

```
borealRecovery/
├── code/               # All R and Python scripts
├── data/
│   ├── final/         # Processed data for plotting (in repo)
│   ├── processed/     # Intermediate processed data (created by scripts)
│   ├── external/      # External data files (in repo)
│   ├── raw/           # Raw LPJ-GUESS output (from Zenodo)
│   └── random_forest/ # RF model input/output (from Zenodo)
├── plots/             # Generated figures
├── patches2.duckdb    # Full database (from Zenodo)
└── patches2_subset.duckdb  # Subset database (from Zenodo)
```

---

## Troubleshooting

### Memory Issues
If you encounter memory errors:
- Use the subset database instead of full database
- Close other applications
- Process one time period at a time
- Consider using a computing cluster for full database

### Missing Data
If scripts fail with "file not found":
- Ensure you've downloaded necessary data from Zenodo
- Check that files are in correct directories
- Verify `here::here()` is pointing to repository root

### Database Connection Errors
```R
# Verify database exists and can be opened
library(duckdb); library(DBI); library(here)
con = dbConnect(duckdb(), here("patches2_subset.duckdb"), read_only = TRUE)
dbListTables(con)
dbDisconnect(con, shutdown = TRUE)
```

---

## Citation

If you use this code or data, please cite:

Layritz et al. (2024). Post-disturbance recovery drives 21st-century vegetation shifts in the boreal forest in a dynamic vegetation model. *Biogeosciences* (submitted).

Data: https://doi.org/10.5281/zenodo.13731857

---

## Contact

For questions or issues:
- Open an issue on GitHub
- Contact: [Author contact information]

---

## License

[License information]
