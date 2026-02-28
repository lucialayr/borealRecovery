library(here)
source(here("code", "utils.R"))
library(tidyverse)

# Define functions to create trajectory CSV files (skip shapefile creation)

trajectories_species_composition = function(start_year, end_year) {
  
  data_s = list()
  
  for (s in c("picontrol", "ssp126", "ssp585")) {
    
    df_s = read_csv(paste0(here("data", "processed"), "/trajectories_", s, "_", start_year, "_", end_year, "_timeseries_rf.csv")) %>%
      filter(age < 101) %>%
      group_by(age, PFT) %>%
      summarise(relative_mean = mean(relative)) %>%
      mutate(s = s)
    
    data_s = append(data_s, list(df_s))
  }
  
  df_plot = purrr::reduce(data_s, bind_rows) %>%
    mutate(s = long_names_scenarios(s)) %>%
    rename(PFT_long = PFT)

  write_csv(df_plot, paste0(here("data", "final"), "/trajectories_mean_A_mean_", start_year, "_", end_year, ".csv"))
}

trajectories_agb = function(start_year, end_year) {
  
  df_class = read_csv(paste0(here("data", "processed"), "/classified_trajectories_processed__", start_year, "_", end_year, ".csv")) %>%
    select(Lon, Lat, PID, class) 
  
  data_carbon = list()
  
  for (s in c("picontrol", "ssp126", "ssp585")) {
    
    df_carbon = read_csv(paste0(here("data", "processed"), "/agc_recovery_", s, "_", start_year, "_", end_year, "_.csv")) %>%
      mutate(s = s)
    
    data_carbon = append(data_carbon, list(df_carbon))
  }

  df_cmass = purrr::reduce(data_carbon, bind_rows) %>%
    filter(time_since_dist > 100) %>%
    left_join(df_class)
  
  df_cmass_mean = df_cmass %>%
    group_by(s, age) %>%
    summarise(mean_diff = mean(diff)) %>%
    mutate(s = long_names_scenarios(s),
           mean_diff = if_else(mean_diff > 1, NA, mean_diff))
  
  df_cmass_mean_class = df_cmass %>%
    filter(class %in% c(0, 1)) %>%
    group_by(s, age, class) %>%
    summarise(mean_diff = mean(diff)) %>%
    mutate(s = long_names_scenarios(s),
           class = if_else(class == 0, "Direct conifer recovery", "Deciduous transient"),
           mean_diff = if_else(mean_diff > 1, NA, mean_diff))
  
  write_csv(df_cmass_mean, paste0(here("data", "final"), "/trajectories_mean_A_agc_", start_year, "_", end_year, ".csv"))
  write_csv(df_cmass_mean_class, paste0(here("data", "final"), "/trajectories_mean_A_agc_classes_", start_year, "_", end_year, ".csv"))
}

# Run for both time periods
cat("Processing 2015-2040...\n")
trajectories_species_composition(2015, 2040)
trajectories_agb(2015, 2040)

cat("\nProcessing 2075-2100...\n")
trajectories_species_composition(2075, 2100)
trajectories_agb(2075, 2100)

cat("\n✓ Trajectory CSV files created in data/final/\n")
