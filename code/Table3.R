library(here)
source(here("code", "utils.R"))

library(tidyverse)

# Generate Table 3: Trajectory counts by class, scenario, and time period
generate_table3 = function() {
  
  # Read classified trajectories for both time periods
  df1 = read_csv(paste0(here("data", "processed"), "/classified_trajectories_processed__2015_2040.csv")) %>%
    mutate(timespan = "2015-2040")
  
  df2 = read_csv(paste0(here("data", "processed"), "/classified_trajectories_processed__2075_2100.csv")) %>%
    mutate(timespan = "2075-2100")
  
  # Combine and count trajectories by timespan, scenario, and class
  df_counts = bind_rows(df1, df2) %>%
    group_by(timespan, s, class) %>%
    summarise(n_trajectories = n(), .groups = "drop")
  
  # Calculate percentages within each timespan and scenario
  df_with_percentages = df_counts %>%
    group_by(timespan, s) %>%
    mutate(
      percentage = round(n_trajectories / sum(n_trajectories) * 100, 1),
      total = sum(n_trajectories)
    ) %>%
    ungroup() %>%
    mutate(s = long_names_scenarios(s)) %>%
    arrange(timespan, s, class)
  
  # Save the table
  write_csv(df_with_percentages, here("data", "final", "Table3_trajectory_counts.csv"))
  
  cat("\n=== Table 3: Trajectory counts by class, scenario, and time period ===\n\n")
  print(df_with_percentages, n = Inf)
  
  # Also create a wide format for publication
  df_wide = df_with_percentages %>%
    mutate(
      count_pct = paste0(n_trajectories, " (", percentage, "%)")
    ) %>%
    select(timespan, s, class, count_pct) %>%
    pivot_wider(names_from = class, values_from = count_pct, names_prefix = "Class_")
  
  cat("\n\n=== Wide format (for publication) ===\n\n")
  print(df_wide, n = Inf)
  
  write_csv(df_wide, here("data", "final", "Table3_trajectory_counts_wide.csv"))
  
  cat("\n\nFiles saved:\n")
  cat("  - data/final/Table3_trajectory_counts.csv (long format)\n")
  cat("  - data/final/Table3_trajectory_counts_wide.csv (wide format)\n")
  
  return(df_with_percentages)
}

# Run the function
generate_table3()
