setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(duckdb)
library(tidyverse)
library(terra)
library(zoo)


add_climate_to_trajectories = function(scenario, start_year, end_year) {
  
  df_timeseries = read_csv(paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, "_timeseries_rf.csv" ))
  
  df_point_values = read_csv(paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, "_pointvalues_rf.csv" ))
  
  df_covariates = read_csv(paste0(paste0("data/processed/covariates_", scenario, "_", start_year, "_", end_year, "_growingseason.csv")), show_col_types = F)
  
  years_disturbance = df_timeseries %>%
    ungroup() %>%
    dplyr::select(Lon, Lat, PID, year_disturbance) %>%
    rename(Year = year_disturbance) %>%
    mutate(Year = Year + 1) %>% #shift by one since we want to connect two years 2 - 10 (left aligned smoothed)
    unique()
  
  df_covariates_point = df_covariates %>%
    dplyr::select(Lon, Lat, Year, pr_yearlysum, tas_gs_dailyavg, tas_gs_dailymax, tas_gs_dailymin, rsds_gs_dailyavg) %>%
    arrange(Year) %>%
    group_by(Lon, Lat) %>%
    mutate(pr_yearlysum_2_10 = rollmean(tas_gs_dailyavg, k = 9, fill = NA, align = "left"),
           tas_gs_dailyavg_2_10 = rollmean(tas_gs_dailyavg, k = 9, fill = NA, align = "left"),
           tas_gs_dailymax_2_10 = rollmean(tas_gs_dailymax, k = 9, fill = NA, align = "left"),
           tas_gs_dailymin_2_10 = rollmean(tas_gs_dailymin, k = 9, fill = NA, align = "left"),
           rsds_gs_dailyavg_2_10 = rollmean(rsds_gs_dailyavg, k = 9, fill = NA, align = "left")) %>%
    dplyr::select(-pr_yearlysum, -tas_gs_dailyavg, -tas_gs_dailymax, -tas_gs_dailymin, -rsds_gs_dailyavg) %>%
    right_join(years_disturbance) %>%
    dplyr::select(-Year)
  
  
  
  df = left_join(df_timeseries, df_covariates) %>%
    left_join(df_point_values) %>%
    left_join(df_covariates_point)
  
  write_csv(df, paste0("data/random_forest/data_", scenario, "_", start_year, "_", end_year, ".csv" ))
  
  na_count <-sapply(df, function(y) sum(length(which(is.na(y)))))
  
  na_count <- data.frame(na_count)
  
  if (sum(na_count$na_count) > 0) {
    rlang::abort("There are NA values in the dataset")
  }
  
  
}

add_climate_to_trajectories("picontrol", 2015, 2040)
add_climate_to_trajectories("ssp126", 2015, 2040)
add_climate_to_trajectories("ssp585", 2015, 2040)

add_climate_to_trajectories("picontrol", 2075, 2100)
add_climate_to_trajectories("ssp126", 2075, 2100)
add_climate_to_trajectories("ssp585", 2075, 2100)

