library(here)
library(duckdb)
library(DBI)
library(tidyverse)

set.seed(42)

cat("=== CREATING TINY SUBSET (10 cells) ===\n\n")

# Read all grid cells
all_cells = read_csv(here("data", "processed", "all_grid_cells.csv"), show_col_types = FALSE)

# Sample just 10 cells for quick testing
n_sample = 10
sampled_cells = all_cells %>%
  slice_sample(n = n_sample)

cat("Sampled", n_sample, "grid cells\n")
cat("Lon range:", min(sampled_cells$Lon), "to", max(sampled_cells$Lon), "\n")
cat("Lat range:", min(sampled_cells$Lat), "to", max(sampled_cells$Lat), "\n\n")

# Save sampled cells
write_csv(sampled_cells, here("data", "processed", "sampled_grid_cells_tiny.csv"))

# Connect to source database
con_source = dbConnect(duckdb(), here("patches2.duckdb"), read_only = TRUE)

# Create new tiny subset database
subset_path = here("patches2_tiny.duckdb")
if (file.exists(subset_path)) {
  file.remove(subset_path)
}
con_subset = dbConnect(duckdb(), subset_path, read_only = FALSE)

# Get tables
tables = dbListTables(con_source)
cat("Will copy", length(tables), "tables\n\n")

# Create WHERE clause
lon_values = paste0("(", paste(sampled_cells$Lon, collapse = ", "), ")")
lat_values = paste0("(", paste(sampled_cells$Lat, collapse = ", "), ")")

# Copy each table
for (i in seq_along(tables)) {
  table_name = tables[i]
  cat(sprintf("[%d/%d] %s ... ", i, length(tables), table_name))
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
  cat(sprintf("%-35s %10s rows\n", table_name, format(count$n, big.mark = ",")))
}

dbDisconnect(con_source, shutdown = TRUE)
dbDisconnect(con_subset, shutdown = TRUE)

file_size = file.info(subset_path)$size / 1024^2
cat("\nTiny subset size:", round(file_size, 1), "MB\n")
cat("Location:", subset_path, "\n")
cat("\n=== DONE ===\n")
