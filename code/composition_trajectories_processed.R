setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(duckdb)
library(tidyverse)
library(terra)
library(zoo)


get_data_scenario = function(scenario, start_year, end_year) {
  
  con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
  dbListTables(con)
  
  # get unique identifier of all patches disturbed between `start_year` and `end_year`
  # we filter for dhist = 1 to only get disturbed patches and for PFT = BNE, as it will make the table smaller and for now we only want the identifiers
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, Year, ndist FROM '", scenario, "_d150_cmass' WHERE Year BETWEEN ", start_year, " AND ", 
                                               end_year, " AND dhist = 1 AND PFT = 'BNE';")) %>% unique()
  
  
  check4 = dbGetQuery(con, paste0("SELECT * FROM '", scenario, "_d150_cmass' WHERE Year BETWEEN ", start_year, " AND ", 
                                               end_year + 100, " AND Lon = -93.25 AND Lat = 52.25 AND PID = 20 AND PFT = 'BNE';"))
  
  
  #We want to select for trajectories that could recover for at least 100 years. d.ndist = l.ndist filters out years before first disturbance.dplyr code filters out disturbance after less than 100 years
  dbWriteTable(con, "locations_disturbed", locations_disturbed, overwrite = T)
  
  locations_disturbed_once = dbGetQuery(con, paste0("SELECT d.Year, l.Year as year_disturbance, d.PID, d.Lon, d.Lat, d.age, d.ndist FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN locations_disturbed AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat WHERE d.Year BETWEEN ", 
                                    start_year, " AND ", end_year + 100, " AND d.ndist = l.ndist")) %>%
    unique() %>%
    group_by(Lon, Lat, PID, year_disturbance) %>%
    filter(age == max(age)) %>%
    filter(age >= 100) %>%
    dplyr::select(-age)
  
  # now we want to retrieve the whole time series, but only for these patches (again an inner join)
  # we write `locations_disturbed_once` to the database:
  dbWriteTable(con, "locations_disturbed_once", locations_disturbed_once, overwrite = T)
  
  # and join. We filter out the part of timeseries before the disturbance and match by ndist, to exclude patches that regenerate for 100 years and then get disturbanced again
  # for example, if a patch is disturbed in year 2030, we otherwise will additionally get the years 2015 - 2029 that we are not interested in
  df_cmass = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance,  d.PFT, d.PID, d.Lon, d.Lat, d.cmass, d.age FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat WHERE d.Year BETWEEN ", 
                                    start_year, " AND ", end_year + 100, " AND d.Year >= l.year_disturbance AND d.ndist = l.ndist")) %>%
    group_by(age, Lon, Lat, PID) %>%
    mutate(relative = cmass/sum(cmass))  %>% 
    ungroup() %>%
    mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>% #if sum(cmass) = 0, this will be NA (can happen in the first years after a disturbance)
    unique()
  
  check3 = locations_disturbed %>%
    filter(Lon == -93.25 & Lat == 52.25 & PID == 20)
  
  check2 = locations_disturbed_once %>%
    filter(Lon == -93.25 & Lat == 52.25 & PID == 20)
  
  check = df_cmass %>%
    filter(Lon == -93.25 & Lat == 52.25 & PID == 20)
  
  #anpp
  df_anpp = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance,  d.PFT, d.PID, d.Lon, d.Lat, d.anpp, d.age FROM '", scenario, "_d150_npp' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat WHERE d.Year BETWEEN ", 
                                   start_year, " AND ", end_year + 100, " AND d.Year >= l.year_disturbance AND d.ndist = l.ndist")) %>%
    unique()
  
  # average recruitment over the age 2 - 10
  df_exp_est = dbGetQuery(con, paste0("SELECT d.PFT, d.PID, d.Lon, d.Lat, SUM(d.exp_est) as sum_exp_est_2_10 FROM '", scenario, "_d150_exp_est' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat
                                WHERE d.Year BETWEEN ",start_year, " AND ", end_year + 100, " AND d.ndist = l.ndist AND age BETWEEN 2 AND 10 GROUP BY d.Lon, d.Lat, d.PID, d.PFT")) 
  
  
  # get state and age the year before a disturbance
  df_previous_state = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance, d.PFT, d.PID, d.Lon, d.Lat, d.cmass as previous_state, d.age as time_since_dist FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.Year = l.year_disturbance - 1 AND d.Year BETWEEN ", 
                                             start_year-1, " AND ", end_year - 1)) 
  
  df_timeseries = full_join(df_cmass, df_anpp) %>%
    left_join(locations_disturbed_once) %>%
    mutate(PFT = case_when(PFT == "BINE" ~ "otherC",
                           PFT == "TeNE" ~ "otherC",
                           PFT == "BNS" ~ "otherC",
                           TRUE ~ PFT)) %>%
    group_by(PFT, Lon, Lat, PID, age) %>%
    summarize(relative = sum(relative), 
              cmass = sum(cmass),
              anpp = sum(anpp),
              Year = mean(Year),
              year_disturbance = mean(year_disturbance),
              .groups = "drop")
  
  if (max(df_timeseries$age > 125)) {
    rlang::abort("Maximum age is large than 125! This should not happen. Are trajectories prior to disturbances filtered out?")
  }
  
  if (!isTRUE(all(unique(df_timeseries$year_disturbance) == floor(unique(df_timeseries$year_disturbance))))) {
    rlang::abort("'year_disturbance' must only contain integer values")
  }
  
  initial_anpp = df_timeseries %>%
    dplyr::select(Lon, Lat, PID, PFT, age, anpp) %>%
    filter(age %in% seq(2, 10)) %>%
    group_by(PFT, Lon, Lat, PID) %>%
    summarize(sum_anpp_2_10 = sum(anpp),
              .groups = "drop")
  
  df_point_values = full_join(df_exp_est, df_previous_state) %>%
    mutate(PFT = case_when(PFT == "BINE" ~ "otherC",
                           PFT == "TeNE" ~ "otherC",
                           PFT == "BNS" ~ "otherC",
                           TRUE ~ PFT)) %>%
    group_by(PFT, Lon, Lat, PID) %>%
    summarize(sum_exp_est_2_10 = sum(sum_exp_est_2_10),
              previous_state = sum(previous_state),
              time_since_dist = mean(time_since_dist),
              .groups = "drop") %>%
    full_join(initial_anpp)
  
  rm(df_cmass, df_anpp, df_exp_est, df_previous_state, initial_anpp)
  gc()
  
  # we remove `locations_disturbed` again from database
  dbExecute(con, "DROP TABLE locations_disturbed")
  # we remove `locations_disturbed_once` again from database
  dbExecute(con, "DROP TABLE locations_disturbed_once")
  
  write_csv(df_timeseries, paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, "_timeseries_rf.csv" ))
  write_csv(df_point_values, paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, "_pointvalues_rf.csv" ))
  
  return(df)
}

get_data_scenario("ssp585", 2015, 2040)
get_data_scenario("picontrol", 2015, 2040)
get_data_scenario("ssp126", 2015, 2040)

get_data_scenario("ssp585", 2075, 2100)
get_data_scenario("picontrol", 2075, 2100)
get_data_scenario("ssp126", 2075, 2100)

create_covariates_growingseason = function(scenario, start_year, end_year) {
  
yearlymax = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_", scenario, "_tas_daily_inverted_1850_2300_boreal_yearlymax_growingseason.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, tas_gs_dailymax = values)  %>%
    dplyr::select(-layer, -time) 
  
  yearlymin = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_", scenario, "_tas_daily_inverted_1850_2300_boreal_yearlymin_growingseason.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, tas_gs_dailymin = values)  %>%
    dplyr::select(-layer, -time) 
  
  yearlymean = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_", scenario, "_tas_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, tas_gs_dailyavg = values)  %>%
    dplyr::select(-layer, -time) 
  
  yearlysum = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_", scenario, "_pr_daily_inverted_1850_2300_boreal_yearlysum.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, pr_yearlysum = values)  %>%
    dplyr::select(-layer, -time) 
  
  yearlyrad = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_", scenario, "_rsds_daily_inverted_1850_2300_boreal_yearlyavg_growingseason.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y"))) %>%
    filter(Year %in% seq(start_year, end_year + 100)) %>%
    rename(Lon = x, Lat = y, rsds_gs_dailyavg = values)  %>%
    dplyr::select(-layer, -time) 
  
  soil_properties = read_table("data/covariates/hwsd_lpj_0.5.dat", show_col_types = F) %>%
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

add_climate_covariates = function(scenario, start_year, end_year) {
  
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

add_climate_covariates("picontrol", 2015, 2040)
add_climate_covariates("ssp126", 2015, 2040)
add_climate_covariates("ssp585", 2015, 2040)

add_climate_covariates("picontrol", 2075, 2100)
add_climate_covariates("ssp126", 2075, 2100)
add_climate_covariates("ssp585", 2075, 2100)


######

df = read_csv("data/random_forest/data_ssp126_2015_2040.csv")

na_count <-sapply(df, function(y) sum(length(which(is.na(y)))))

na_count <- data.frame(na_count)


