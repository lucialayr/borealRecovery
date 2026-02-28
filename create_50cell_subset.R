library(here)
library(duckdb)
library(DBI)
library(tidyverse)

set.seed(42)

cat("=== CREATING 50-CELL CMASS-ONLY SUBSET ===\n\n")

# Read all grid cells
all_cells = read_csv(here("data", "processed", "all_grid_cells.csv"), show_col_types = FALSE)

# Sample 50 cells for statistical validity
n_sample = 50
sampled_cells = all_cells %>% slice_sample(n = n_sample)

cat("Sampled", n_sample, "grid cells\n")
cat("Lon range:", min(sampled_cells$Lon), "to", max(sampled_cells$Lon), "\n")
cat("Lat range:", min(sampled_cells$Lat), "to", max(sampled_cells$Lat), "\n\n")

write_csv(sampled_cells, here("data", "processed", "sampled_grid_cells_50.csv"))
cat("Saved to: data/processed/sampled_grid_cells_50.csv\n\n")

# Connect to databases
con_source = dbConnect(duckdb(), here("patches2.duckdb"), read_only = TRUE)
subset_path = here("patches2_50cells.duckdb")
if (file.exists(subset_path)) file.remove(subset_path)
con_subset = dbConnect(duckdb(), subset_path, read_only = FALSE)

# Only copy cmass tables (needed for Figures 2-4)
all_tables = dbListTables(con_source)
tables_to_copy = grep("cmass", all_tables, value = TRUE)

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
  n_cells = dbGetQuery(con_subset, sprintf("SELECT COUNT(DISTINCT CONCAT(Lon, '_', Lat)) as n FROM %s", table_name))
  cat(sprintf("%-35s %12s rows, %3d cells\n", 
              table_name, format(count$n, big.mark = ","), n_cells$n))
}

dbDisconnect(con_source, shutdown = TRUE)
dbDisconnect(con_subset, shutdown = TRUE)

file_size = file.info(subset_path)$size / 1024^2
cat("\n50-cell cmass-only subset size:", round(file_size, 1), "MB\n")
cat("Location:", subset_path, "\n")
cat("\n=== READY FOR TESTING ===\n")
cat("Next: Test with 02a_trajectories_database_processed.R\n")
