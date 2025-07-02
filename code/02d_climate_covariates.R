setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(tidyverse)
library(terra)
library(zoo)


create_covariates_growingseason = function(scenario, start_year, end_year) {
  
  yearlymax = terra::rast(paste0("data/raw/climate_data/mri-esm2-0_r1i1p1f1_", scenario, "_tas_daily_inverted_1850_2300_boreal_yearlymax_growingseason.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, tas_gs_dailymax = values)  %>%
    dplyr::select(-layer, -time) 
  
  yearlymin = terra::rast(paste0("data/raw/climate_data/mri-esm2-0_r1i1p1f1_", scenario, "_tas_daily_inverted_1850_2300_boreal_yearlymin_growingseason.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, tas_gs_dailymin = values)  %>%
    dplyr::select(-layer, -time) 
  
  yearlymean = terra::rast(paste0("data/raw/climate_data/mri-esm2-0_r1i1p1f1_", scenario, "_tas_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, tas_gs_dailyavg = values)  %>%
    dplyr::select(-layer, -time) 
  
  yearlysum = terra::rast(paste0("data/raw/climate_data/mri-esm2-0_r1i1p1f1_", scenario, "_pr_daily_inverted_1850_2300_boreal_yearlysum.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, pr_yearlysum = values)  %>%
    dplyr::select(-layer, -time) 
  
  yearlyrad = terra::rast(paste0("data/raw/climate_data/mri-esm2-0_r1i1p1f1_", scenario, "_rsds_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, rsds_gs_dailyavg = values)  %>%
    dplyr::select(-layer, -time) 
  
  soil_properties = read_table("data/raw/climate_data/hwsd_lpj_0.5.dat", show_col_types = F) %>%
    dplyr::select(-cn) %>%
    rename(Lon = lon, Lat = lat, sand_fraction = sand, silt_fraction = silt, clay_fraction = clay,
           bulkdensity_soil = bulkdensity, ph_soil = ph, soilcarbon = soilc)
  
  df = full_join(yearlysum, yearlymean) %>%
    full_join(yearlymin) %>%
    full_join(yearlymax) %>%
    full_join(yearlyrad) %>%
    right_join(soil_properties) %>%
    filter(!is.na(Year))
  
  write_csv(df, paste0("data/processed/covariates_", scenario, "_", start_year, "_", end_year, "_growingseason.csv" ))
  
  return(df)
  
  
}

create_covariates_growingseason("picontrol", 2015, 2040)
create_covariates_growingseason("ssp126", 2015, 2040)
create_covariates_growingseason("ssp585", 2015, 2040)

create_covariates_growingseason("picontrol", 2075, 2100)
create_covariates_growingseason("ssp126", 2075, 2100)
create_covariates_growingseason("ssp585", 2075, 2100)