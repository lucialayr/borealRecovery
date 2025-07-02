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


get_data_validation = function(scenario = 'picontrol', start_year = '2015', end_year = '2040', variable = 'fpc', length = 200) {
  
  con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
  dbListTables(con)
  
  # get unique identifier of all patches disturbed between `start_year` and `end_year`
  # we filter for dhist = 1 to only get disturbed patches and for PFT = BNE, as it will make the table smaller and for now we only want the identifiers
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, Year, ndist FROM '", scenario, "_d150_cmass' WHERE Year BETWEEN ", start_year, " AND ", 
                                               end_year, " AND dhist = 1 AND PFT = 'BNE';")) %>% unique()
  
  # to select only patches who where able to recover for at least 100 years, we want to inner join this table with patches in the final recovery period `start_year` + 100 - `end_year`  + 100
  # for this we need to write `locations disturbed` to the database
  dbWriteTable(con, "locations_disturbed", locations_disturbed, overwrite = T)
  
  # and perform the inner join (remember that each patch is uniquely defined by Lon, Lat and PID):
  # the resulting table `locations_disturbed_once` should habe less rows than `locations_disturbed`
  locations_disturbed_once = dbGetQuery(con, paste0("SELECT l.Year as year_disturbance, d.PID, d.Lon, d.Lat, d.ndist FROM '", scenario, "_d150_cmass' 
                                                    AS d INNER JOIN locations_disturbed AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat  WHERE d.Year BETWEEN ", 
                                                    start_year + length, " AND ", end_year + length, " AND age = ", length, " AND PFT = 'BNE'")) 
  
  # now we want to retrieve the whole time series, but only for these patches (again an inner join)
  # we write `locations_disturbed_once` to the database:
  dbWriteTable(con, "locations_disturbed_once", locations_disturbed_once, overwrite = T)
  
  # and join. We additionally join by `ndist`to make sure we only get that recovery trajectory.
  # for example, if a patch is disturbed in year 2030, we otherwise will additionally get the years 2015 - 2029 that we are not interested in
  df_1 = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance, d.PFT, d.PID, d.Lon, d.Lat, d.", variable, ", d.age FROM '", scenario, "_d150_", variable, "' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.ndist = l.ndist WHERE d.Year BETWEEN ", 
                                start_year, " AND ", end_year + length)) %>%
    group_by(age, Lon, Lat, PID) %>%
    mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable)))  %>% 
    mutate(across(everything(), ~ifelse(is.na(.), 0, .))) 
  
  # get state and age the 5 years year before a disturbance
  df_2 = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance, d.PFT, d.PID, d.Lon, d.Lat, d.", variable, " as ", variable, " FROM '", scenario, "_d150_", variable, "' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.Year < l.year_disturbance AND d.Year BETWEEN ", 
                                start_year-5, " AND ", end_year - 1, "AND age <= ", length)) %>%
    mutate(age = Year - year_disturbance) %>%
    filter(age > -6) %>%
    group_by(age, Lon, Lat, PID) %>%
    mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable)))  %>% 
    mutate(across(everything(), ~ifelse(is.na(.), 0, .)))
  
  print("start binding rows ..")
  
  print(head(df_1))
  print(head(df_2))
  
  df = bind_rows(df_1, df_2) %>%
    mutate(PFT = case_when(PFT == "BINE" ~ "otherC",
                           PFT == "TeNE" ~ "otherC",
                           PFT == "BNS" ~ "otherC",
                           TRUE ~ PFT)) %>%
    group_by(PFT, Lon, Lat, PID, Year, age) %>%
    summarize(across(c(relative, !!variable), sum),  year_disturbance = mean(year_disturbance))
  
  rm(df_1, df_2)
  gc()
  
  # we remove `locations_disturbed` again from database
  dbExecute(con, "DROP TABLE locations_disturbed")
  # we remove `locations_disturbed_once` again from database
  dbExecute(con, "DROP TABLE locations_disturbed_once")
  
  write_csv(df, paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ))
  
  return(df)
}
get_data_validation()



