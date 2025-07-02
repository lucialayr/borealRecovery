setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

install.packages("duckdb", version = "1.0.0")

library(duckdb)
library(tidyverse)
library(terra)
library(zoo)


agc_cabon_processed = function(scenario, start_year, end_year) {
  
  con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) 
  dbListTables(con)
  
  # get unique identifier of all patches disturbed between `start_year` and `end_year`
  # we filter for dhist = 1 to only get disturbed patches and for PFT = BNE, as it will make the table smaller and for now we only want the identifiers
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, Year, ndist FROM '", scenario, "_d150_cmass' WHERE Year BETWEEN ", start_year, " AND ", 
                                               end_year, " AND dhist = 1 AND PFT = 'BNE';")) %>% unique()
  
  
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
    summarize(Total = sum(cmass, na.rm = T))  %>% 
    ungroup() %>%
    mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>% #if sum(cmass) = 0, this will be NA (can happen in the first years after a disturbance)
    unique()
  
  # get state and age the year before a disturbance
  df = dbGetQuery(con, paste0("SELECT l.year_disturbance, d.PFT, d.PID, d.Lon, d.Lat, d.cmass as previous_state, d.age as time_since_dist FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.Year = l.year_disturbance - 1 AND d.Year BETWEEN ", 
                                             start_year-1, " AND ", end_year - 1)) %>%
    group_by(Lon, Lat, PID) %>%
    summarize(previous_state = sum(previous_state, na.rm = T),
              time_since_dist = mean(time_since_dist)) %>%
    full_join(df_cmass) %>%
    mutate(diff = 1 + (Total - previous_state)/previous_state) %>%
    filter(!is.infinite(diff))
  
  rm(df_cmass)
  gc()
  
  # we remove `locations_disturbed` again from database
  dbExecute(con, "DROP TABLE locations_disturbed")
  # we remove `locations_disturbed_once` again from database
  dbExecute(con, "DROP TABLE locations_disturbed_once")
  
  write_csv(df, paste0("data/processed/agc_recovery_", scenario, "_", start_year, "_", end_year, "_.csv" ))
  
  return(df)
}

agc_cabon_processed("ssp585", 2015, 2040)
agc_cabon_processed("picontrol", 2015, 2040)
agc_cabon_processed("ssp126", 2015, 2040)

agc_cabon_processed("ssp585", 2075, 2100)
agc_cabon_processed("picontrol", 2075, 2100)
agc_cabon_processed("ssp126", 2075, 2100)

