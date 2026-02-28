library(here)
library(ggplot2)

# Test 02a with 50-cell cmass-only subset
script_path = here("code", "02a_trajectories_database_processed.R")
script = readLines(script_path)

# Replace database path
script = gsub('here\\("patches2\\.duckdb"\\)', 
              'here("patches2_50cells.duckdb")', 
              script)

# Comment out the get_data_scenario() calls (lines for RF analysis we're skipping)
script = gsub('^get_data_scenario\\(', '#get_data_scenario(', script)

# Keep get_data_validation() call
# (It's the last line and processes trajectories, not RF data)

temp_script = tempfile(fileext = ".R")
writeLines(script, temp_script)

cat("=== TESTING 02a WITH 50-CELL CMASS-ONLY SUBSET ===\n")
cat("Database: patches2_50cells.duckdb (50 cells, 3 cmass tables)\n")
cat("Processing: get_data_validation() only (skipping RF data)\n\n")

source(temp_script)

cat("\n=== OUTPUT FILES ===\n")
proc_files = list.files(here("data", "processed"), pattern = "trajectories_.*\\.csv$", full.names = TRUE)
if (length(proc_files) > 0) {
  for (f in proc_files) {
    info = file.info(f)
    cat(sprintf("%-70s %8.1f KB\n", basename(f), info$size / 1024))
  }
  cat("\n✓ SUCCESS\n")
} else {
  cat("✗ No output files generated\n")
}
