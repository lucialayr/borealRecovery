library(here)

cat("=== Running 02a with complete 50-cell subset ===\n\n")

# Read and modify 02a script to use complete subset
script = readLines(here("code", "02a_trajectories_database_processed.R"))

# Replace database path
script = gsub('here\\("patches2\\.duckdb"\\)', 
              'here("patches2_50cells_complete.duckdb")', 
              script)

# Write to temp file and source
temp_script = tempfile(fileext = ".R")
writeLines(script, temp_script)

cat("Processing all 6 scenarios (this may take 10-15 minutes)...\n\n")
source(temp_script)

cat("\n=== Checking outputs ===\n")
files = list.files(here("data", "processed"), pattern = "*timeseries_rf.csv", full.names = FALSE)
cat("Created", length(files), "timeseries_rf files:\n")
for (f in files) {
  size = file.info(here("data", "processed", f))$size / 1024^2
  cat(sprintf("  %s (%.1f MB)\n", f, size))
}

cat("\nFiles created:\n")
system("ls -lht data/processed/*2040* | head -12")
