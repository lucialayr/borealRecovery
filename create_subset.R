library(here)
library(duckdb)
library(DBI)
library(tidyverse)

set.seed(42)  # For reproducibility

cat("=== CREATING SUBSET DATABASE ===\n\n")

# Read all grid cells
all_cells = read_csv(here("data", "processed", "all_grid_cells.csv"), show_col_types = FALSE)
cat("Total grid cells available:", nrow(all_cells), "\n")

# Sample 150 cells randomly for statistical representativeness
# 150 cells = ~3% of data = ~3,750 patches = ~15-20 disturbed patches per period
n_sample = 150
sampled_cells = all_cells %>%
  slice_sample(n = n_sample)

cat("Sampled", n_sample, "grid cells\n")
cat("Lon range:", min(sampled_cells$Lon), "to", max(sampled_cells$Lon), "\n")
cat("Lat range:", min(sampled_cells$Lat), "to", max(sampled_cells$Lat), "\n\n")

# Save sampled cells for reference
write_csv(sampled_cells, here("data", "processed", "sampled_grid_cells.csv"))
cat("Saved sampled cells to data/processed/sampled_grid_cells.csv\n\n")

# Connect to source database
con_source = dbConnect(duckdb(), here("patches2.duckdb"), read_only = TRUE)

# Connect to new subset database
subset_db_path = here("patches2_subset.duckdb")
if (file.exists(subset_db_path)) {
  file.remove(subset_db_path)
  cat("Removed existing subset database\n")
}
con_subset = dbConnect(duckdb(), subset_db_path, read_only = FALSE)

# Get list of all tables
tables = dbListTables(con_source)
cat("Tables to copy:", paste(tables, collapse = ", "), "\n\n")

# Create WHERE clause for filtering
lon_values = paste0("(", paste(sampled_cells$Lon, collapse = ", "), ")")
lat_values = paste0("(", paste(sampled_cells$Lat, collapse = ", "), ")")

# Copy each table with filtering
for (table_name in tables) {
  cat("Processing table:", table_name, "... ")
  
  # Read filtered data from source
  query = sprintf("
    SELECT * FROM %s
    WHERE Lon IN %s AND Lat IN %s
  ", table_name, lon_values, lat_values)
  
  data = dbGetQuery(con_source, query)
  
  # Write to subset database
  dbWriteTable(con_subset, table_name, data, overwrite = TRUE)
  
  cat("Copied", format(nrow(data), big.mark = ","), "rows\n")
  
  # Clean up memory
  rm(data)
  gc()
}

cat("\n")

# Verify subset
cat("=== VERIFICATION ===\n")
for (table_name in tables[1:3]) {  # Check first 3 tables
  query = sprintf("SELECT COUNT(DISTINCT CONCAT(CAST(Lon AS VARCHAR), '_', CAST(Lat AS VARCHAR))) as n_cells FROM %s", table_name)
  result = dbGetQuery(con_subset, query)
  cat(table_name, ": ", result$n_cells, "grid cells\n")
}

# Close connections
dbDisconnect(con_source, shutdown = TRUE)
dbDisconnect(con_subset, shutdown = TRUE)

# Check file size
file_info = file.info(subset_db_path)
cat("\nSubset database size:", round(file_info$size / 1024^2, 2), "MB\n")

cat("\n=== SUBSET DATABASE CREATED ===\n")
cat("Location:", subset_db_path, "\n")
