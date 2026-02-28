library(here)
library(ggplot2)

cat("==========================================================\n")
cat("  TESTING FULL PIPELINE WITH 50-CELL SUBSET\n")
cat("==========================================================\n\n")

# Function to run script with subset database
run_with_subset = function(script_name, description) {
  cat("\n--- ", description, " ---\n")
  script_path = here("code", script_name)
  script = readLines(script_path)
  
  # Replace database path
  script = gsub('here\\("patches2\\.duckdb"\\)', 
                'here("patches2_50cells_complete.duckdb")', 
                script)
  
  temp_script = tempfile(fileext = ".R")
  writeLines(script, temp_script)
  
  cat("Running:", script_name, "...\n")
  tryCatch({
    source(temp_script)
    cat("✓ SUCCESS\n")
    return(TRUE)
  }, error = function(e) {
    cat("✗ ERROR:", conditionMessage(e), "\n")
    return(FALSE)
  })
}

# STAGE 1: Process database (02*.R scripts)
cat("\n========== STAGE 1: DATABASE PROCESSING ==========\n")

# 02a - Already tested, but run again for completeness
cat("\n[1/4] 02a: Trajectories database processing\n")
success_02a = run_with_subset("02a_trajectories_database_processed.R", "Process trajectories from database")

# 02b - AGC trajectories
cat("\n[2/4] 02b: AGC trajectories processing\n")
success_02b = run_with_subset("02b_agc_trajectories_processed.R", "Process AGC recovery trajectories")

# 02c - Classified trajectories  
cat("\n[3/4] 02c: Classified trajectories processing\n")
success_02c = run_with_subset("02c_classified_trajectories_processed.R", "Classify trajectory types")

# 02d - Climate covariates
cat("\n[4/4] 02d: Climate covariates\n")
success_02d = run_with_subset("02d_climate_covariates.R", "Process climate covariate data")

# STAGE 2: Create final data (*_final.R scripts)
cat("\n========== STAGE 2: CREATE FINAL DATA ==========\n")

# Trajectories/Niche final
cat("\n[1/2] Trajectories and niche final data\n")
success_traj = run_with_subset("trajectories_niche_processed_final.R", "Create final trajectory/niche data")

# Maps/Regression final
cat("\n[2/2] Maps and regression final data\n")
success_maps = run_with_subset("maps_regression_final.R", "Create final maps/regression data")

# SUMMARY
cat("\n\n")
cat("==========================================================\n")
cat("  PIPELINE SUMMARY\n")
cat("==========================================================\n")
cat("Database Processing:\n")
cat("  02a Trajectories:       ", ifelse(success_02a, "✓", "✗"), "\n")
cat("  02b AGC:                ", ifelse(success_02b, "✓", "✗"), "\n")
cat("  02c Classification:     ", ifelse(success_02c, "✓", "✗"), "\n")
cat("  02d Climate:            ", ifelse(success_02d, "✓", "✗"), "\n")
cat("\nFinal Data Creation:\n")
cat("  Trajectories/Niche:     ", ifelse(success_traj, "✓", "✗"), "\n")
cat("  Maps/Regression:        ", ifelse(success_maps, "✓", "✗"), "\n")
cat("\n")

# List generated files
cat("\n========== GENERATED FILES ==========\n")
cat("\nProcessed data (data/processed/):\n")
proc_files = list.files(here("data", "processed"), pattern = "\\.csv$", full.names = FALSE)
for (f in head(proc_files, 20)) {
  cat("  ", f, "\n")
}
if (length(proc_files) > 20) cat("  ... and", length(proc_files) - 20, "more\n")

cat("\nFinal data (data/final/):\n")
final_files = list.files(here("data", "final"), pattern = "\\.csv$", full.names = FALSE, recursive = TRUE)
for (f in head(final_files, 20)) {
  cat("  ", f, "\n")
}
if (length(final_files) > 20) cat("  ... and", length(final_files) - 20, "more\n")

cat("\n==========================================================\n")
cat("  READY FOR VALIDATION\n")
cat("==========================================================\n")
cat("Next step: Run validate_subset_results.R to compare\n")
cat("           subset outputs with reference data/final/\n")
cat("\n")
