library(here)
library(tidyverse)

cat("=== CREATING REFERENCE DATA FOR 50-CELL VALIDATION ===\n\n")

# Load sampled cells
sampled_cells = read_csv(here("data", "processed", "sampled_grid_cells_50.csv"), 
                         show_col_types = FALSE)
cat("Sampled cells:", nrow(sampled_cells), "\n\n")

# Create reference directory
ref_dir = here("data", "final_reference_50cells")
if (!dir.exists(ref_dir)) {
  dir.create(ref_dir)
  cat("Created:", ref_dir, "\n\n")
}

# Files with Lon, Lat, PID that we can validate
files_to_extract = c(
  "maps_regression_B_patches_2015_2040.csv",
  "maps_regression_B_patches_2075_2100.csv"
)

for (file_name in files_to_extract) {
  
  cat("Processing:", file_name, "\n")
  
  # Read full data
  full_data = read_csv(here("data", "final", file_name), show_col_types = FALSE)
  
  # Filter to 50 cells
  subset_ref = full_data %>%
    semi_join(sampled_cells, by = c("Lon", "Lat")) %>%
    arrange(Lon, Lat, PID)  # Sort for consistent comparison
  
  # Save as reference
  ref_path = file.path(ref_dir, file_name)
  write_csv(subset_ref, ref_path)
  
  cat("  Full data rows:  ", nrow(full_data), "\n")
  cat("  50-cell rows:    ", nrow(subset_ref), "\n")
  cat("  Saved to:        ", ref_path, "\n\n")
}

cat("✓ Reference data extracted and saved\n\n")

cat("NEXT STEPS:\n")
cat("1. These files are the EXPECTED outputs for the 50-cell subset\n")
cat("2. When you run maps_regression_final.R with the subset database,\n")
cat("   it should produce EXACTLY these values for these (Lon, Lat, PID) combinations\n")
cat("3. However, maps_regression_final.R requires climate covariates\n")
cat("   which we cannot generate without raw climate data\n\n")

cat("WORKAROUND: Check processed files that feed into maps_regression\n")
classified_2015 = here("data", "processed", "classified_trajectories_processed__2015_2040.csv")
classified_2075 = here("data", "processed", "classified_trajectories_processed__2075_2100.csv")

if (file.exists(classified_2015)) {
  cat("\n✓ Found:", classified_2015, "\n")
  df = read_csv(classified_2015, show_col_types = FALSE)
  cat("  Rows:", nrow(df), "\n")
  cat("  Columns:", paste(names(df), collapse = ", "), "\n")
  
  # Check if this has the same (Lon, Lat, PID) as our reference
  df_subset = df %>% semi_join(sampled_cells, by = c("Lon", "Lat"))
  cat("  Rows matching 50 cells:", nrow(df_subset), "\n")
  cat("  Unique (Lon, Lat, PID):", 
      df_subset %>% distinct(Lon, Lat, PID) %>% nrow(), "\n")
}

cat("\n=== CONCLUSION ===\n")
cat("We have created reference data for the 50-cell subset from data/final/.\n")
cat("To fully validate, we would need to:\n")
cat("  1. Generate climate covariates for the 50 cells (blocked - no raw data)\n")
cat("  2. Run maps_regression_final.R with subset\n")
cat("  3. Compare output to reference files in", ref_dir, "\n")
