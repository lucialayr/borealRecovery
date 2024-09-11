setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(duckdb)
library(tidyverse)
library(purrr)
library(terra)
library(sf)

con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
dbListTables(con)

scenario = "picontrol"
variable = "cmass"
end_year = 2040
start_year = 2015

##########################################
### plotting mean trajectories

get_data_scenario = function(scenario, start_year, end_year) {
  
  # get unique identifier of all patches disturbed between `start_year` and `end_year`
  # we filter for dhist = 1 to only get disturbed patches and for PFT = BNE, as it will make the table smaller and for now we only want the identifiers
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, Year, ndist FROM '", scenario, "_d150_cmass' WHERE Year BETWEEN ", start_year, " AND ", 
                                               end_year, " AND dhist = 1 AND PFT = 'BNE';")) %>% unique()
  
  # to select only patches who where able to recover for at least 100 years, we want to inner join this table with patches in the final recovery period `start_year` + 100 - `end_year`  + 100
  # for this we need to write `locations disturbed` to the database
  dbWriteTable(con, "locations_disturbed", locations_disturbed, overwrite = T)
  
  # and perform the inner join (remeber that each patch is uniquely defined by Lon, Lat and PID):
  # the resulting table `locations_disturbed_once` should habe less rows than `locations_disturbed`
  locations_disturbed_once = dbGetQuery(con, paste0("SELECT l.Year as year_disturbance, d.PID, d.Lon, d.Lat, d.ndist FROM '", scenario, "_d150_cmass' 
                                                    AS d INNER JOIN locations_disturbed AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat  WHERE d.Year BETWEEN ", 
                              start_year + 100, " AND ", end_year + 100, " AND age = 100 AND PFT = 'BNE'")) 
  
  # now we want to retrieve the whole time series, but only for these patches (again an inner join)
  # we write `locations_disturbed_once` to the database:
  dbWriteTable(con, "locations_disturbed_once", locations_disturbed_once, overwrite = T)
  
  
  # and join. We additionally join by `ndist`to make sure we only the that recovery trajectory.
  # for example, if a patch is disturbed in year 2030, we otherwise will additionally get the years 2015 - 2029 that we are not interested in
  df_1 = dbGetQuery(con, paste0("SELECT d.Year, d.PFT, d.PID, d.Lon, d.Lat, d.cmass, d.age FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.ndist = l.ndist WHERE d.Year BETWEEN ", 
                              start_year, " AND ", end_year + 100)) %>%
    group_by(age, Lon, Lat, PID) %>%
    mutate(relative = cmass/sum(cmass))  %>% 
    mutate(across(everything(), ~ifelse(is.na(.), 0, .))) #if sum(cmass) = 0, this will be NA (can happen in the first years after a disturbance)
  
  # initial recruitment (age = 2 as before recruitment is not really  thing and nmbers are chunk)
  df_2a = dbGetQuery(con, paste0("SELECT d.PFT, d.PID, d.Lon, d.Lat, d.exp_est as initial_recruitment FROM '", scenario, "_d150_exp_est' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.ndist = l.ndist WHERE d.Year BETWEEN ", 
                                start_year, " AND ", end_year + 100, " AND age  = 2")) 
  
  # summed recruitment over the age 2 - 10
  
  df_2b = dbGetQuery(con, paste0("SELECT d.PFT, d.PID, d.Lon, d.Lat, SUM(d.exp_est) as recruitment_ten_years FROM '", scenario, "_d150_exp_est' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.ndist = l.ndist 
                                WHERE d.Year BETWEEN ",start_year, " AND ", end_year + 100, " AND age BETWEEN 2 AND 10 GROUP BY d.Lon, d.Lat, d.PID, d.PFT")) 
  
  # get state and age the year before a disturbance
  df_3 = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance, d.PFT, d.PID, d.Lon, d.Lat, d.cmass as previous_state, d.age time_since_dist FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.Year = l.year_disturbance - 1 AND d.Year BETWEEN ", 
                                start_year-1, " AND ", end_year - 1)) %>%
    select(-Year, -year_disturbance)
  
  
  df_2 = full_join(df_2a, df_2b)
  
  df = full_join(df_1, df_2) %>%
    full_join(df_3) %>%
    mutate(PFT = case_when(PFT == "BINE" ~ "otherC",
                           PFT == "TeNE" ~ "otherC",
                           PFT == "BNS" ~ "otherC",
                           TRUE ~ PFT)) %>%
    group_by(PFT, Lon, Lat, PID, Year) %>%
    summarize(relative = sum(relative), 
              cmass = sum(cmass),
              initial_recruitment = sum(initial_recruitment),
              recruitment_ten_years = sum(recruitment_ten_years),
              previous_state = sum(previous_state),
              time_since_dist = mean(time_since_dist),
              age = mean(age))  
  
  rm(df_1, df_2, df_3, df_2a, df_2b)
  gc()
  
  # we remove `locations_disturbed` again from database
  dbExecute(con, "DROP TABLE locations_disturbed")
  # we remove `locations_disturbed_once` again from database
  dbExecute(con, "DROP TABLE locations_disturbed_once")
  
  write_csv(df, paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, ".csv" ))
  
  return(df)
}

create_covariates = function(scenario, start_year, end_year) {
  
  nitrogen = read_table(paste0("data/", scenario, "_d150/nuptake.out"), show_col_types = F) %>%
    mutate(Tundra = C3G +  HSE + HSS + LSS + LSE + GRT + EPDS + SPDS + CLM,
           otherC = TeNE + BINE + BNS) %>% #aggegate Tundra PFTs
    select(-c("C3G",  "HSE", "HSS", "LSS", "LSE", "GRT", "EPDS", "SPDS", "CLM", "BINE", "BNS", "TeNE")) %>%
    pivot_longer(cols = -c(Lon, Lat, Year, Total)) %>%
    rename(PFT = name, Nuptake = value, Nuptake_total = Total) %>%
    filter(Year >= start_year & Year <= end_year + 100)
  
  yearlymax = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_", scenario, "_tas_daily_inverted_2000_2250_boreal_yearlymax.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(time = as.numeric(format(time, "%Y"))) %>%
    rename(Lon = x, Lat = y, Year = time, tas_yearlymax = values)  %>%
    select(-layer) %>%
    filter(Year >= start_year & Year <= end_year  + 100) 
  
  yearlymin = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_", scenario, "_tas_daily_inverted_2000_2250_boreal_yearlymin.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(time = as.numeric(format(time, "%Y"))) %>%
    rename(Lon = x, Lat = y, Year = time, tas_yearlymin = values)  %>%
    select(-layer) %>%
    filter(Year >= start_year & Year <= end_year  + 100)
  
  yearlymean = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_", scenario, "_tas_daily_inverted_2000_2250_boreal_yearly.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(time = as.numeric(format(time, "%Y"))) %>%
    rename(Lon = x, Lat = y, Year = time, tas_yearlymeam = values)  %>%
    select(-layer) %>%
    filter(Year >= start_year & Year <= end_year  + 100)
  
  yearlysum = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_", scenario, "_pr_daily_inverted_2000_2250_boreal_yearlysum.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(time = as.numeric(format(time, "%Y"))) %>%
    rename(Lon = x, Lat = y, Year = time, pr_yearlysum = values)  %>%
    select(-layer) %>%
    filter(Year >= start_year & Year <= end_year  + 100)
  
  soil_properties = read_table("data/covariates/hwsd_lpj_0.5.dat", show_col_types = F) %>%
    select(-cn) %>%
    rename(Lon = lon, Lat = lat, sand_fraction = sand, silt_fraction = silt, clay_fraction = clay,
           bulkdensity_soil = bulkdensity, ph_soil = ph, soilcarbon = soilc)
  
  df = left_join(nitrogen, soil_properties) %>%
    left_join(yearlymax) %>%
    full_join(yearlymin) %>%
    full_join(yearlymean) %>%
    full_join(yearlysum)

  write_csv(df, paste0("data/processed/covariates_", scenario, "_", start_year, "_", end_year, ".csv" ))
  
  return(df)
  
  
}

add_covariates = function(scenario, start_year, end_year) {
  df_patch = read_csv(paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, ".csv" ), show_col_types = F) 
  
  df_covariates = read_csv(paste0("data/processed/covariates_", scenario, "_", start_year, "_", end_year, ".csv" ), show_col_types = F)
  
  df = left_join(df_patch, df_covariates)
  
  write_csv(df, paste0("data_mohit/data_", scenario, "_", start_year, "_", end_year, ".csv" ))
}

trajectories_picontrol = get_data_scenario("picontrol", 2015, 2040)
trajectories_ssp585 = get_data_scenario("ssp585", 2015, 2040)
trajectories_ssp585 = get_data_scenario("ssp585", 2100, 2125)
trajectories_ssp585 = get_data_scenario("ssp126", 2015, 2040)
trajectories_ssp585 = get_data_scenario("ssp126", 2100, 2125)


scenario_list = data.frame(scenario = c("picontrol", "ssp585", "ssp585", "ssp126", "ssp126"),
                           start_year = c(2015, 2015, 2100, 2015, 2100),
                           end_year = c(2040, 2040, 2125, 2040, 2125))

purrr::pmap(scenario_list, get_data_scenario)
purrr::pmap(scenario_list, create_covariates)
purrr::pmap(scenario_list, add_covariates)


test = read_csv("data_mohit/data_ssp585_2015_2040.csv")

##########################################
#####370 for Theresa
trajectories_ssp370 = get_data_scenario("ssp370", 2015, 2040)
create_covariates("ssp370", 2015, 2040)
add_covariates("ssp370", 2015, 2040)

scenario_list = data.frame(scenario = c("ssp370"),
                           start_year = c(2015),
                           end_year = c(2040))

purrr::pmap(scenario_list, get_data_scenario)
purrr::pmap(scenario_list, create_covariates)
purrr::pmap(scenario_list, add_covariates)

