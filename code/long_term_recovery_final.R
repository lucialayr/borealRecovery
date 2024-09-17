setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(duckdb)
library(tidyverse)


con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
dbListTables(con)


get_one_scenario = function(scenario, start_year, end_year) {
  
  
  
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, Year, ndist FROM '", scenario, "_d150_cmass' WHERE Year BETWEEN ", start_year, " AND ", 
                                               end_year, " AND dhist = 1 AND PFT = 'BNE';")) %>% unique()
  
  df_class1 = read_csv(paste0("data/results/all_binary_data_", start_year, "_", end_year,".csv")) %>%
    filter(class == 1, s == long_names_scenarios(scenario)) %>%
    dplyr::select(Lon, Lat, PID) %>%
    inner_join(locations_disturbed) %>%
    rename(year_disturbance = Year)
  
  
  dbWriteTable(con, "locations_disturbed_class1", df_class1, overwrite = T)
  
  df_cmass = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance,  d.PFT, d.PID, d.Lon, d.Lat, d.cmass, d.age FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN locations_disturbed_class1 AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat WHERE d.Year >= ", 
                                    start_year, " AND d.Year >= l.year_disturbance AND d.ndist = l.ndist")) %>%
    group_by(age, Lon, Lat, PID) %>%
    mutate(relative = cmass/sum(cmass))  %>% 
    ungroup() %>%
    mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>% #if sum(cmass) = 0, this will be NA (can happen in the first years after a disturbance)
    unique()
  
  df = df_cmass %>%
    mutate(PFT = case_when(PFT == "BINE" ~ "otherC",
                           PFT == "TeNE" ~ "otherC",
                           PFT == "BNS" ~ "otherC",
                           TRUE ~ PFT)) %>%
    group_by(PFT, Lon, Lat, PID, age) %>%
    summarize(relative = sum(relative)) %>%
    mutate(PFT = long_names_pfts(tolower(PFT)),
           s = scenario)
  
  return(df)
  
}

long_term_recovery_A_final = function(start_year, end_year) {
  
  data = list()
  
  for (s in c("picontrol", "ssp126", "ssp585")) {
    df = get_one_scenario(s, start_year = start_year, end_year = end_year)
    
    data = append(data, list(df))
    
  }
  
  df = purrr::reduce(data, bind_rows) %>%
    mutate(s = long_names_scenarios(s))
  
  df$PFT = factor(df$PFT, levels = rev(c( "Needleleaf evergreen", "Pioneering broadleaf" ,   
                                          "Conifers (other)", "Temperate broadleaf" , 
                                          "Non-tree V.")))
  
  write_csv(df, "data/final/long_term_recovery_A_final.csv")
  
  return(df)
  
}

long_term_recovery_B_final = function(df) {
  npatches = df %>%
    ungroup() %>%
    dplyr::select(age, Lon, Lat, PID, s) %>%
    unique() %>%
    group_by(age, s) %>%
    count() %>%
    filter(age %in% c(2, 100, 150, 200, 250, 280)) 
  
  write_csv(npatches, "data/final/long_term_recovery_B_final.csv")
}

df = long_term_recovery_A_final(2015, 2040)

long_term_recovery_B_final(df)






