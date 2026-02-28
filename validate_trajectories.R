library(here)
library(tidyverse)

cat("=== VALIDATING SUBSET-GENERATED TRAJECTORIES ===\n\n")
cat("Note: These are aggregated files without patch-level keys.\n")
cat("Validation: Comparing aggregated mean values between subset and full data.\n\n")

# Tolerance for floating point comparison
tolerance = 1e-6

# Files to validate
files_to_validate = c(
  "trajectories_mean_A_mean_2015_2040.csv",
  "trajectories_mean_A_mean_2075_2100.csv",
  "trajectories_mean_A_agc_2015_2040.csv",
  "trajectories_mean_A_agc_2075_2100.csv",
  "trajectories_mean_A_agc_classes_2015_2040.csv",
  "trajectories_mean_A_agc_classes_2075_2100.csv"
)

results = list()

for (file_name in files_to_validate) {
  
  cat("Validating:", file_name, "\n")
  
  # Read reference (original full data)
  ref_file = here("data", "final", paste0(file_name, ".ref"))
  if (!file.exists(ref_file)) {
    # If .ref doesn't exist, this IS the reference - skip
    cat("  → No .ref file found - this appears to be newly generated\n")
    cat("  → Backing up current file as .ref for future comparisons\n")
    file.copy(here("data", "final", file_name), ref_file)
    results[[file_name]] = "BASELINE"
    cat("\n")
    next
  }
  
  ref_data = read_csv(ref_file, show_col_types = FALSE)
  
  # Read newly generated subset data  
  subset_data = read_csv(here("data", "final", file_name), show_col_types = FALSE)
  
  # Check structure
  if (!identical(names(ref_data), names(subset_data))) {
    cat("  ✗ Column names don't match!\n")
    cat("  Reference:", paste(names(ref_data), collapse = ", "), "\n")
    cat("  Subset:   ", paste(names(subset_data), collapse = ", "), "\n\n")
    results[[file_name]] = "FAIL - Structure"
    next
  }
  
  # Check dimensions
  cat("  Reference rows:", nrow(ref_data), "\n")
  cat("  Subset rows:   ", nrow(subset_data), "\n")
  
  if (nrow(ref_data) != nrow(subset_data)) {
    cat("  ⚠ Row count differs (expected for subset data)\n")
    cat("  → Comparing overlapping rows only\n")
  }
  
  # Identify key columns (non-numeric) and value columns (numeric)
  numeric_cols = names(subset_data)[sapply(subset_data, is.numeric)]
  key_cols = setdiff(names(subset_data), numeric_cols)
  
  # Join on key columns
  if (length(key_cols) > 0) {
    comparison = ref_data %>%
      inner_join(subset_data, by = key_cols, suffix = c("_ref", "_subset"))
    
    cat("  Matched rows:", nrow(comparison), "\n")
    
    # Compare numeric columns
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
          cat("  ✗", col, "- max difference:", format(max_col_diff, scientific = TRUE), "\n")
        }
      }
    }
    
    if (all_match) {
      cat("  ✓ All values match within tolerance (", tolerance, ")\n")
      cat("    Max difference:", format(max_diff, scientific = TRUE), "\n")
      results[[file_name]] = "PASS"
    } else {
      cat("  ✗ Some values exceed tolerance\n")
      results[[file_name]] = "FAIL - Values"
    }
    
  } else {
    cat("  ⚠ No key columns to join on - comparing directly\n")
    # Direct comparison (should be identical)
    if (identical(ref_data, subset_data)) {
      cat("  ✓ Files are identical\n")
      results[[file_name]] = "PASS"
    } else {
      cat("  ✗ Files differ\n")
      results[[file_name]] = "FAIL"
    }
  }
  
  cat("\n")
}

# Summary
cat("=== VALIDATION SUMMARY ===\n")
for (file in names(results)) {
  cat(sprintf("%-50s %s\n", file, results[[file]]))
}
cat("\n")

# Count results
passes = sum(results == "PASS")
fails = sum(results %in% c("FAIL", "FAIL - Structure", "FAIL - Values"))
baselines = sum(results == "BASELINE")

cat("Results:\n")
cat("  PASS:    ", passes, "\n")
cat("  FAIL:    ", fails, "\n")
cat("  BASELINE:", baselines, "(new files, now saved as reference)\n")
cat("\n")

if (fails > 0) {
  cat("⚠ VALIDATION FAILED - Review differences above\n")
} else if (passes > 0) {
  cat("✓ VALIDATION SUCCESSFUL\n")
} else {
  cat("ℹ First run - baseline files created\n")
}
