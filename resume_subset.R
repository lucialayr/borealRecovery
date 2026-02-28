library(here)
library(duckdb)
library(DBI)
library(tidyverse)

cat("=== RESUMING SUBSET DATABASE CREATION ===\n\n")

# Load sampled cells
sampled_cells = read_csv(here("data", "processed", "sampled_grid_cells.csv"), show_col_types = FALSE)
cat("Sampled grid cells:", nrow(sampled_cells), "\n\n")

# Connect to databases
con_source = dbConnect(duckdb(), here("patches2.duckdb"), read_only = TRUE)
con_subset = dbConnect(duckdb(), here("patches2_subset.duckdb"), read_only = FALSE)

# Get list of all tables that should exist
all_tables = dbListTables(con_source)
cat("Tables in source database:", length(all_tables), "\n")

# Get list of tables already in subset
existing_tables = dbListTables(con_subset)
cat("Tables already in subset:", length(existing_tables), "\n")

# Find tables that still need to be copied
remaining_tables = setdiff(all_tables, existing_tables)
cat("Tables remaining:", length(remaining_tables), "\n\n")

if (length(remaining_tables) == 0) {
  cat("All tables already copied!\n")
} else {
  cat("Will copy:", paste(remaining_tables, collapse = ", "), "\n\n")
  
  # Create WHERE clause for filtering
  lon_values = paste0("(", paste(sampled_cells$Lon, collapse = ", "), ")")
  lat_values = paste0("(", paste(sampled_cells$Lat, collapse = ", "), ")")
  
  # Copy remaining tables
  for (i in seq_along(remaining_tables)) {
    table_name = remaining_tables[i]
    cat(sprintf("[%d/%d] Processing table: %s ... ", i, length(remaining_tables), table_name))
    flush.console()
    
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
}

# Verify final state
cat("=== FINAL VERIFICATION ===\n")
final_tables = dbListTables(con_subset)
cat("Total tables in subset:", length(final_tables), "\n")
for (table_name in final_tables) {
  count = dbGetQuery(con_subset, sprintf("SELECT COUNT(*) as n FROM %s", table_name))
  cat(sprintf("  %-35s %15s rows\n", table_name, format(count$n, big.mark = ",")))
}

# Close connections
dbDisconnect(con_source, shutdown = TRUE)
dbDisconnect(con_subset, shutdown = TRUE)

# Check file size
file_info = file.info(here("patches2_subset.duckdb"))
cat("\nSubset database size:", round(file_info$size / 1024^3, 2), "GB\n")

cat("\n=== SUBSET DATABASE COMPLETE ===\n")
