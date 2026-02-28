library(here)
library(duckdb)
library(DBI)
library(tidyverse)

cat("=== CREATING SUBSET DATABASE (EFFICIENT VERSION) ===\n\n")

# Configuration
N_CELLS = 100  # Reduced from 150 to save space
SEED = 42

# Connect to source database
con_source = dbConnect(duckdb(), here("patches2.duckdb"), read_only = TRUE)

# Get all unique grid cells
all_cells = dbGetQuery(con_source, 
  "SELECT DISTINCT Lon, Lat FROM ssp585_d150_cmass ORDER BY Lon, Lat")

cat("Total grid cells available:", nrow(all_cells), "\n")

# Sample grid cells
set.seed(SEED)
sampled_cells = all_cells %>% 
  slice_sample(n = N_CELLS)

cat("Sampled", N_CELLS, "grid cells\n")
cat("Lon range:", min(sampled_cells$Lon), "to", max(sampled_cells$Lon), "\n")
cat("Lat range:", min(sampled_cells$Lat), "to", max(sampled_cells$Lat), "\n\n")

# Save sampled cells
dir.create(here("data", "processed"), showWarnings = FALSE, recursive = TRUE)
write_csv(sampled_cells, here("data", "processed", "sampled_grid_cells.csv"))
cat("Saved sampled cells to data/processed/sampled_grid_cells.csv\n\n")

# Create subset database
subset_db_path = here("patches2_subset.duckdb")
if (file.exists(subset_db_path)) {
  file.remove(subset_db_path)
  cat("Removed existing subset database\n")
}

con_subset = dbConnect(duckdb(), subset_db_path)

# Prepare IN clauses for filtering
lon_values = paste0("(", paste(sampled_cells$Lon, collapse = ", "), ")")
lat_values = paste0("(", paste(sampled_cells$Lat, collapse = ", "), ")")

# Get list of tables
tables = dbListTables(con_source)
cat("Tables to copy:", paste(tables, collapse = ", "), "\n\n")

# Copy each table efficiently using CREATE TABLE AS
for (table_name in tables) {
  cat("Processing table:", table_name, "...")
  
  # Use CREATE TABLE AS SELECT for efficient copying
  query = sprintf(
    "CREATE TABLE %s AS SELECT * FROM %s WHERE Lon IN %s AND Lat IN %s",
    table_name, table_name, lon_values, lat_values
  )
  
  # Execute via source connection, then attach and copy
  temp_view = sprintf("temp_%s", table_name)
  
  dbExecute(con_source, sprintf(
    "CREATE TEMP VIEW %s AS SELECT * FROM %s WHERE Lon IN %s AND Lat IN %s",
    temp_view, table_name, lon_values, lat_values
  ))
  
  # Get data in chunks to manage memory
  data = dbGetQuery(con_source, sprintf("SELECT * FROM %s", temp_view))
  n_rows = nrow(data)
  
  # Write to subset database
  dbWriteTable(con_subset, table_name, data, overwrite = TRUE)
  
  cat(" Copied", format(n_rows, big.mark = ","), "rows\n")
  
  # Clean up
  dbExecute(con_source, sprintf("DROP VIEW %s", temp_view))
  rm(data)
  gc()
  
  # Checkpoint to compact the database
  dbExecute(con_subset, "CHECKPOINT")
}

# Final checkpoint
dbExecute(con_subset, "CHECKPOINT")

# Verify
cat("\n=== VERIFICATION ===\n")
final_tables = dbListTables(con_subset)
cat("Tables created:", length(final_tables), "\n")

for (table_name in final_tables) {
  n_rows = dbGetQuery(con_subset, sprintf("SELECT COUNT(*) as n FROM %s", table_name))$n
  cat("  ", table_name, ":", format(n_rows, big.mark = ","), "rows\n")
}

# Close connections
dbDisconnect(con_source, shutdown = TRUE)
dbDisconnect(con_subset, shutdown = TRUE)

# Check file size
file_size = file.info(subset_db_path)$size / 1024^3
cat("\nSubset database size:", round(file_size, 2), "GB\n")
cat("Expected size:", round(25 * N_CELLS / 5156, 2), "GB\n")

cat("\n=== COMPLETE ===\n")
