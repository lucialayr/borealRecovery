library(here)

# Read trajectories_niche_processed_final.R and modify it
script = readLines(here("code", "trajectories_niche_processed_final.R"))

# Replace database path
script = gsub('here\\("patches2\\.duckdb"\\)', 
              'here("patches2_50cells_complete.duckdb")', 
              script)

# Write to temp file and execute
temp_script = tempfile(fileext = ".R")
writeLines(script, temp_script)

cat("Running trajectories_niche_processed_final.R with subset...\n\n")
source(temp_script)
cat("\n✓ trajectories_niche_processed_final.R completed\n")
