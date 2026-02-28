library(here)
library(duckdb)
library(DBI)
library(tidyverse)

# Connect to database
con = dbConnect(duckdb(), here("patches2.duckdb"), read_only = TRUE)

cat("=== DATABASE ANALYSIS ===\n\n")

# 1. Get total number of unique grid cells
query = "
SELECT COUNT(DISTINCT CONCAT(CAST(Lon AS VARCHAR), '_', CAST(Lat AS VARCHAR))) as n_cells
FROM ssp585_d150_cmass
"
result = dbGetQuery(con, query)
cat("Total unique grid cells:", result$n_cells, "\n\n")

# 2. Get year range
query = "SELECT MIN(Year) as min_year, MAX(Year) as max_year FROM ssp585_d150_cmass"
result = dbGetQuery(con, query)
cat("Year range:", result$min_year, "to", result$max_year, "\n\n")

# 3. Sample a few grid cells to understand patch distribution
query = "
SELECT Lon, Lat, COUNT(DISTINCT PID) as n_patches, 
       COUNT(*) as n_rows
FROM ssp585_d150_cmass
WHERE Year BETWEEN 2015 AND 2140
GROUP BY Lon, Lat
ORDER BY RANDOM()
LIMIT 10
"
result = dbGetQuery(con, query)
cat("Sample of grid cells (patches and rows for years 2015-2140):\n")
print(result)
cat("\nMean patches per cell:", mean(result$n_patches), "\n")
cat("Mean rows per cell:", mean(result$n_rows), "\n\n")

# 4. Get all unique grid cells
query = "
SELECT DISTINCT Lon, Lat
FROM ssp585_d150_cmass
ORDER BY Lon, Lat
"
all_cells = dbGetQuery(con, query)
cat("Total grid cells in database:", nrow(all_cells), "\n\n")

# 5. Estimate data size for different sample sizes
sample_sizes = c(10, 15, 20, 25, 30)
total_rows = 451150000  # From earlier analysis
total_cells = nrow(all_cells)

cat("Estimated subset sizes (based on proportional sampling):\n")
for (n in sample_sizes) {
  proportion = n / total_cells
  estimated_rows = total_rows * proportion
  estimated_gb = (estimated_rows / total_rows) * 25  # 25GB total
  cat(sprintf("  %d cells: ~%.1fM rows, ~%.2f GB\n", n, estimated_rows/1e6, estimated_gb))
}
cat("\n")

# 6. Check disturbance patterns in 2015-2040 and 2075-2100 windows
for (period in list(c(2015, 2040), c(2075, 2100))) {
  query = sprintf("
    SELECT COUNT(DISTINCT CONCAT(CAST(Lon AS VARCHAR), '_', CAST(Lat AS VARCHAR), '_', CAST(PID AS VARCHAR))) as n_disturbed
    FROM ssp585_d150_cmass
    WHERE Year BETWEEN %d AND %d AND dhist = 1
  ", period[1], period[2])
  result = dbGetQuery(con, query)
  cat(sprintf("Disturbed patches in %d-%d: %d\n", period[1], period[2], result$n_disturbed))
}

# Save grid cell list for sampling
write_csv(all_cells, here("data", "processed", "all_grid_cells.csv"))
cat("\nSaved all grid cells to data/processed/all_grid_cells.csv\n")

dbDisconnect(con, shutdown = TRUE)
cat("\n=== ANALYSIS COMPLETE ===\n")
