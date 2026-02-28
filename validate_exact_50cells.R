library(here)
library(tidyverse)

cat("=== EXACT VALUE VALIDATION FOR 50-CELL SUBSET ===\n\n")

# Load sampled cells
sampled_cells = read_csv(here("data", "processed", "sampled_grid_cells_50.csv"), 
                         show_col_types = FALSE)
cat("Sampled cells:", nrow(sampled_cells), "\n\n")

tolerance = 1e-10  # Very strict tolerance

# Validate maps_regression_B_patches files (have Lon, Lat, PID)
files_to_validate = c(
  "maps_regression_B_patches_2015_2040.csv",
  "maps_regression_B_patches_2075_2100.csv"
)

cat("FILES TO VALIDATE (with Lon, Lat, PID):\n")
for (f in files_to_validate) cat("  -", f, "\n")
cat("\n")

results = list()

for (file_name in files_to_validate) {
  
  cat("===", file_name, "===\n")
  
  full_path = here("data", "final", file_name)
  
  if (!file.exists(full_path)) {
    cat("  ✗ File not found\n\n")
    results[[file_name]] = "MISSING"
    next
  }
  
  # Read the full data file (this is from original full database)
  full_data = read_csv(full_path, show_col_types = FALSE)
  
  cat("  Full data rows:     ", nrow(full_data), "\n")
  
  # Filter to only the 50 sampled cells
  subset_data = full_data %>%
    semi_join(sampled_cells, by = c("Lon", "Lat"))
  
  cat("  50-cell subset rows:", nrow(subset_data), "\n")
  
  if (nrow(subset_data) == 0) {
    cat("  ⚠ No matching cells found - are the 50 cells in this dataset?\n\n")
    results[[file_name]] = "NO_MATCH"
    next
  }
  
  # Show sample of the data
  cat("\n  Sample rows from 50-cell subset:\n")
  print(head(subset_data %>% select(Lon, Lat, PID, s, class, tas_smoothed), 3))
  
  cat("\n  Unique cells in subset:", 
      subset_data %>% distinct(Lon, Lat) %>% nrow(), "\n")
  cat("  Unique patches (PID) in subset:", 
      subset_data %>% distinct(Lon, Lat, PID) %>% nrow(), "\n")
  
  # Summary statistics
  cat("\n  Summary statistics for numeric columns:\n")
  numeric_cols = names(subset_data)[sapply(subset_data, is.numeric)]
  for (col in numeric_cols) {
    vals = subset_data[[col]]
    cat(sprintf("    %-20s: mean=%.6f, sd=%.6f, range=[%.6f, %.6f]\n",
                col, mean(vals, na.rm=TRUE), sd(vals, na.rm=TRUE),
                min(vals, na.rm=TRUE), max(vals, na.rm=TRUE)))
  }
  
  results[[file_name]] = "EXTRACTED"
  cat("\n")
}

cat("\n=== INTERPRETATION ===\n")
cat("These files contain patch-level data with (Lon, Lat, PID) identifiers.\n")
cat("The values shown above are the REFERENCE values from the full database.\n")
cat("\n")
cat("To validate subset reproduction:\n")
cat("1. We need to re-run maps_regression_final.R with subset database\n")
cat("2. This requires climate covariates (which need raw data we don't have)\n")
cat("3. Once generated, we would compare these exact rows/values\n")
cat("\n")
cat("ALTERNATIVE: Check if any existing subset-generated files match these:\n")

# Check if we have any matching files in processed or elsewhere
cat("\nSearching for maps_regression files in data/processed/...\n")
proc_files = list.files(here("data", "processed"), 
                        pattern = ".*regression.*", 
                        full.names = TRUE)
if (length(proc_files) > 0) {
  cat("Found:\n")
  for (f in proc_files) cat("  -", basename(f), "\n")
} else {
  cat("  None found.\n")
}

cat("\n✓ Successfully extracted 50-cell subset from reference data\n")
cat("  Next step: Generate same files from subset database for comparison\n")
