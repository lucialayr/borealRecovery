library(here)
library(tidyverse)

cat("=== COMPARING SUBSET vs FULL DATA TRAJECTORIES ===\n\n")
cat("This compares aggregated means from subset (50 cells) vs full data.\n")
cat("Since these are MEANS, they should be similar but not identical.\n")
cat("We expect small statistical differences due to sampling.\n\n")

# Create a backup directory for comparison
backup_dir = here("data", "final_from_full")
if (!dir.exists(backup_dir)) {
  cat("Creating backup of original full-data files...\n")
  dir.create(backup_dir)
  
  # Copy original files
  files = list.files(here("data", "final"), pattern = "trajectories_mean_A.*\\.csv$", full.names = TRUE)
  for (f in files) {
    file.copy(f, file.path(backup_dir, basename(f)), overwrite = FALSE)
  }
  cat("✓ Backed up", length(files), "files to", backup_dir, "\n\n")
}

# Files to compare
files_to_compare = c(
  "trajectories_mean_A_mean_2015_2040.csv",
  "trajectories_mean_A_mean_2075_2100.csv",
  "trajectories_mean_A_agc_2015_2040.csv",
  "trajectories_mean_A_agc_2075_2100.csv",
  "trajectories_mean_A_agc_classes_2015_2040.csv",
  "trajectories_mean_A_agc_classes_2075_2100.csv"
)

for (file_name in files_to_compare) {
  
  cat("Comparing:", file_name, "\n")
  
  # Read full-data reference
  full_path = file.path(backup_dir, file_name)
  if (!file.exists(full_path)) {
    cat("  ⚠ Full-data file not found in backup - skipping\n\n")
    next
  }
  full_data = read_csv(full_path, show_col_types = FALSE)
  
  # Read subset-generated data
  subset_path = here("data", "final", file_name)
  subset_data = read_csv(subset_path, show_col_types = FALSE)
  
  # Check structure
  if (!identical(names(full_data), names(subset_data))) {
    cat("  ✗ Column names don't match!\n\n")
    next
  }
  
  cat("  Full data rows:  ", nrow(full_data), "\n")
  cat("  Subset data rows:", nrow(subset_data), "\n")
  
  # Identify numeric columns
  numeric_cols = names(subset_data)[sapply(subset_data, is.numeric)]
  key_cols = setdiff(names(subset_data), numeric_cols)
  
  # Join on key columns if they exist
  if (length(key_cols) > 0) {
    comparison = full_data %>%
      inner_join(subset_data, by = key_cols, suffix = c("_full", "_subset"))
    
    cat("  Matched rows:", nrow(comparison), "\n\n")
    
    # Compare numeric columns
    cat("  Comparison by column:\n")
    for (col in numeric_cols) {
      full_col = paste0(col, "_full")
      subset_col = paste0(col, "_subset")
      
      if (full_col %in% names(comparison) && subset_col %in% names(comparison)) {
        diffs = comparison[[full_col]] - comparison[[subset_col]]
        abs_diffs = abs(diffs)
        
        # Calculate statistics
        mean_diff = mean(diffs, na.rm = TRUE)
        max_diff = max(abs_diffs, na.rm = TRUE)
        rmse = sqrt(mean(diffs^2, na.rm = TRUE))
        
        # Correlation
        cor_val = cor(comparison[[full_col]], comparison[[subset_col]], use = "complete.obs")
        
        cat(sprintf("    %-20s: r=%.4f, RMSE=%.6f, max_diff=%.6f\n", 
                    col, cor_val, rmse, max_diff))
      }
    }
    
  } else {
    cat("  ⚠ No key columns - cannot join for comparison\n")
  }
  
  cat("\n")
}

cat("=== INTERPRETATION ===\n")
cat("For aggregated means:\n")
cat("  • Correlation (r) should be > 0.95 (strong agreement)\n")
cat("  • RMSE shows average difference magnitude\n")
cat("  • Small differences are EXPECTED due to sampling variance\n")
cat("  • Subset is 50/5156 cells (0.97%) so some variation is normal\n")
