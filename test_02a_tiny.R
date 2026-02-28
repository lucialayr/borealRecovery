library(here)
library(ggplot2)  # Required by utils.R

# Test with minimal database (cmass + exp_est only)
script_path = here("code", "02a_trajectories_database_processed.R")
script = readLines(script_path)

# Replace database path
script = gsub('here\\("patches2\\.duckdb"\\)', 
              'here("patches2_minimal.duckdb")', 
              script)

# Write to temp file and source it  
temp_script = tempfile(fileext = ".R")
writeLines(script, temp_script)

cat("=== TESTING 02a WITH MINIMAL SUBSET (cmass + exp_est only) ===\n")
cat("Database: patches2_minimal.duckdb (10 cells, 6 tables)\n\n")
source(temp_script)

cat("\n=== OUTPUT FILES ===\n")
proc_files = list.files(here("data", "processed"), pattern = "trajectories_.*\\.csv$", full.names = TRUE)
if (length(proc_files) > 0) {
  for (f in proc_files) {
    info = file.info(f)
    cat(sprintf("%-70s %8.1f KB\n", basename(f), info$size / 1024))
  }
  cat("\n✓ SUCCESS - 02a processing completed\n")
} else {
  cat("✗ No output files found\n")
}
