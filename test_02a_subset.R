library(here)
library(duckdb)
library(DBI)
library(tidyverse)

# Script to test 02a with subset database and validate results

cat("=== TESTING 02a WITH SUBSET DATABASE ===\n\n")

# Step 1: Backup the full database path and use subset
original_db = here("patches2.duckdb")
subset_db = here("patches2_subset.duckdb")

# Verify subset exists
if (!file.exists(subset_db)) {
  stop("Subset database not found at: ", subset_db)
}

cat("Using subset database:", subset_db, "\n")
cat("Size:", round(file.size(subset_db) / 1024^2, 2), "MB\n\n")

# Step 2: Source 02a but with subset database
# We need to temporarily replace the database path in the script
# Read the script
script_02a = readLines(here("code", "02a_trajectories_database_processed.R"))

# Replace database path
script_02a_modified = gsub('here\\("patches2\\.duckdb"\\)', 
                           'here("patches2_subset.duckdb")', 
                           script_02a)

# Write to temp file
temp_script = tempfile(fileext = ".R")
writeLines(script_02a_modified, temp_script)

cat("Running 02a with subset database...\n")
cat("This will create files in data/processed/\n\n")

# Source the modified script
tryCatch({
  source(temp_script)
  cat("\n✓ 02a completed successfully!\n\n")
}, error = function(e) {
  cat("\n✗ Error in 02a:\n")
  print(e)
})

# Clean up
unlink(temp_script)

# Step 3: Check what files were created
processed_files = list.files(here("data", "processed"), pattern = "trajectories.*\\.csv$", full.names = TRUE)
cat("Files created:\n")
for (f in processed_files) {
  size_mb = round(file.size(f) / 1024^2, 2)
  cat("  ", basename(f), " (", size_mb, " MB)\n", sep = "")
}

cat("\n=== TEST COMPLETE ===\n")
