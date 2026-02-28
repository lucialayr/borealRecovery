library(here)

# Read 02c script and modify it to use 50-cell subset
script = readLines(here("code", "02c_classified_trajectories_processed.R"))

# Replace database path
script = gsub('here\\("patches2\\.duckdb"\\)', 
              'here("patches2_50cells_complete.duckdb")', 
              script)

# Write to temp file and execute
temp_script = tempfile(fileext = ".R")
writeLines(script, temp_script)

cat("Running 02c with patches2_50cells_complete.duckdb...\n\n")
source(temp_script)
cat("\n✓ 02c completed\n")
