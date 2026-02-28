library(here)
library(duckdb)
library(DBI)
library(tidyverse)

set.seed(42)

cat("=== CREATING 50-CELL COMPLETE SUBSET (cmass + anpp + exp_est) ===\n\n")

# Read existing sampled cells
sampled_cells = read_csv(here("data", "processed", "sampled_grid_cells_50.csv"), show_col_types = FALSE)
cat("Using existing sample:", nrow(sampled_cells), "grid cells\n\n")

# Connect to databases
con_source = dbConnect(duckdb(), here("patches2.duckdb"), read_only = TRUE)
subset_path = here("patches2_50cells_complete.duckdb")
if (file.exists(subset_path)) file.remove(subset_path)
con_subset = dbConnect(duckdb(), subset_path, read_only = FALSE)

# Copy cmass, anpp, AND exp_est tables (needed for full pipeline)
all_tables = dbListTables(con_source)
tables_to_copy = grep("(cmass|anpp|exp_est)", all_tables, value = TRUE)

cat("Tables to copy (", length(tables_to_copy), "/", length(all_tables), "):\n", sep = "")
for (t in tables_to_copy) cat("  ✓", t, "\n")
cat("\n")

# Create WHERE clause
lon_values = paste0("(", paste(sampled_cells$Lon, collapse = ", "), ")")
lat_values = paste0("(", paste(sampled_cells$Lat, collapse = ", "), ")")

# Copy each table
for (i in seq_along(tables_to_copy)) {
  table_name = tables_to_copy[i]
  cat(sprintf("[%d/%d] %s ... ", i, length(tables_to_copy), table_name))
  flush.console()
  
  query = sprintf("SELECT * FROM %s WHERE Lon IN %s AND Lat IN %s", 
                  table_name, lon_values, lat_values)
  data = dbGetQuery(con_source, query)
  dbWriteTable(con_subset, table_name, data, overwrite = TRUE)
  
  cat(format(nrow(data), big.mark = ","), "rows\n")
  rm(data)
  gc()
}

cat("\n=== VERIFICATION ===\n")
for (table_name in dbListTables(con_subset)) {
  count = dbGetQuery(con_subset, sprintf("SELECT COUNT(*) as n FROM %s", table_name))
  cat(sprintf("%-35s %12s rows\n", table_name, format(count$n, big.mark = ",")))
}

dbDisconnect(con_source, shutdown = TRUE)
dbDisconnect(con_subset, shutdown = TRUE)

file_size = file.info(subset_path)$size / 1024^2
cat("\n50-cell complete subset size:", round(file_size, 1), "MB\n")
cat("Location:", subset_path, "\n")
cat("\n=== READY FOR FULL PIPELINE ===\n")
