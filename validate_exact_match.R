library(here)
library(tidyverse)

cat("=== VALIDATING PROCESSED DATA FOR 50 SAMPLED CELLS ===\n\n")

# Load sampled cells
sampled_cells = read_csv(here("data", "processed", "sampled_grid_cells_50.csv"), 
                         show_col_types = FALSE)
cat("Sampled cells:", nrow(sampled_cells), "\n")
cat("First few cells:\n")
print(head(sampled_cells, 5))
cat("\n")

# We'll validate the PROCESSED trajectory files which have Lon, Lat, PID
# Compare: full database outputs vs subset database outputs

tolerance = 1e-8

# Check if we have reference processed data from full database
ref_dir = here("data", "processed_from_full")
if (!dir.exists(ref_dir)) {
  cat("ERROR: Need reference processed data from FULL database\n")
  cat("The current data/processed/ was generated from the 50-cell subset.\n")
  cat("To validate, we need to:\n")
  cat("  1. Generate processed data from the FULL database (patches2.duckdb)\n")
  cat("  2. Save it to data/processed_from_full/\n")
  cat("  3. Then compare filtered full data vs subset data\n\n")
  cat("RECOMMENDATION: Since trajectories_*_timeseries_rf.csv files have Lon,Lat,PID,\n")
  cat("we can filter the FULL database outputs to the 50 cells and compare.\n")
  quit()
}

# Files to validate (these have Lon, Lat, PID)
files_to_check = list.files(here("data", "processed"), 
                             pattern = "trajectories_.*_timeseries_rf.csv",
                             full.names = FALSE)

cat("Files to validate:", length(files_to_check), "\n\n")

results = list()

for (file_name in files_to_check) {
  
  cat("Validating:", file_name, "\n")
  
  # Read reference (from full database)
  ref_path = file.path(ref_dir, file_name)
  if (!file.exists(ref_path)) {
    cat("  ✗ Reference file not found:", ref_path, "\n\n")
    results[[file_name]] = "MISSING_REF"
    next
  }
  
  ref_data = read_csv(ref_path, show_col_types = FALSE)
  
  # Filter reference to only sampled cells
  ref_filtered = ref_data %>%
    semi_join(sampled_cells, by = c("Lon", "Lat"))
  
  # Read subset-generated data
  subset_path = here("data", "processed", file_name)
  subset_data = read_csv(subset_path, show_col_types = FALSE)
  
  cat("  Reference (all):      ", nrow(ref_data), "rows\n")
  cat("  Reference (50 cells): ", nrow(ref_filtered), "rows\n")
  cat("  Subset (50 cells):    ", nrow(subset_data), "rows\n")
  
  # Check row counts
  if (nrow(ref_filtered) != nrow(subset_data)) {
    cat("  ✗ ROW COUNT MISMATCH!\n\n")
    results[[file_name]] = "FAIL_ROWCOUNT"
    next
  }
  
  # Join and compare
  comparison = ref_filtered %>%
    inner_join(subset_data, by = c("Lon", "Lat", "PID", "age"), 
               suffix = c("_ref", "_subset"))
  
  if (nrow(comparison) != nrow(ref_filtered)) {
    cat("  ✗ JOIN MISMATCH - not all rows matched by keys!\n")
    cat("    Matched:", nrow(comparison), "of", nrow(ref_filtered), "\n\n")
    results[[file_name]] = "FAIL_JOIN"
    next
  }
  
  # Compare numeric columns
  numeric_cols = c("relative", "cmass", "anpp", "Year", "year_disturbance")
  numeric_cols = intersect(numeric_cols, names(subset_data))
  
  all_match = TRUE
  max_diff = 0
  
  for (col in numeric_cols) {
    ref_col = paste0(col, "_ref")
    subset_col = paste0(col, "_subset")
    
    if (ref_col %in% names(comparison) && subset_col %in% names(comparison)) {
      diffs = abs(comparison[[ref_col]] - comparison[[subset_col]])
      max_col_diff = max(diffs, na.rm = TRUE)
      max_diff = max(max_diff, max_col_diff)
      
      if (max_col_diff > tolerance) {
        all_match = FALSE
        cat("  ✗", col, "- max diff:", format(max_col_diff, scientific = TRUE), "\n")
      }
    }
  }
  
  if (all_match) {
    cat("  ✓ ALL VALUES MATCH (tolerance:", tolerance, ")\n")
    cat("    Max difference:", format(max_diff, scientific = TRUE), "\n")
    results[[file_name]] = "PASS"
  } else {
    cat("  ✗ VALUES DIFFER\n")
    results[[file_name]] = "FAIL_VALUES"
  }
  
  cat("\n")
}

# Summary
cat("\n=== SUMMARY ===\n")
pass_count = sum(results == "PASS")
fail_count = sum(results %in% c("FAIL_ROWCOUNT", "FAIL_JOIN", "FAIL_VALUES"))
missing_count = sum(results == "MISSING_REF")

cat("PASS:    ", pass_count, "\n")
cat("FAIL:    ", fail_count, "\n")
cat("MISSING: ", missing_count, "\n")

if (missing_count > 0) {
  cat("\n⚠ Need to generate reference data from full database first!\n")
} else if (fail_count > 0) {
  cat("\n✗ VALIDATION FAILED\n")
} else {
  cat("\n✓ VALIDATION SUCCESSFUL - Subset exactly reproduces full data for sampled cells\n")
}
