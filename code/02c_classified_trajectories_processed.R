library(here)
source(here("code", "utils.R"))

library(tidyverse)
library(stats)
library(zoo)
library(splines)





classify_trajectories_scenario = function(s, start_year, end_year) {
  
  df_dominant = read_csv(paste0(here("data", "processed"), "/trajectories_", s, "_", start_year, "_", end_year, "_timeseries_rf.csv"))  %>%
    filter(age < 101) %>%
    group_by(Lon, Lat, PID, age) %>%
    mutate(max_relative = max(relative)) %>%
    filter(max_relative == relative) %>%
    ungroup() %>%
    rename(dominant_pft = PFT) %>%
    group_by(Lon, Lat, PID, age) %>%
    filter(sum(cmass) > 0) %>%
    ungroup()

  df_c1 = df_dominant %>%
    filter(age %in% seq(90, 100) & dominant_pft == "BNE") %>%
    group_by(Lon, Lat, PID) %>%
    count() %>%
    filter(n > 5) %>%
    mutate(c1 = 1) %>%
    dplyr::select(-n) %>%
    unique()
  
  df_c2 = df_dominant %>%
     filter(age %in% seq(10, 100)) %>%
     arrange(Lon, Lat, PID, age) %>%
     group_by(Lon, Lat, PID) %>%
     mutate(ibs = if_else(dominant_pft == "IBS", 1, 0),
            length_transient = cumsum(ibs)*ibs,
            s = "ssp585") %>%
     group_by(Lon, Lat, PID) %>%
     filter(length_transient == max(length_transient)) %>% #we have not yet catched presence of two transient but we assume we will catch the longest one
     dplyr::select(Lon, Lat, PID, length_transient) %>%
     unique()  %>%
    mutate(c2 = if_else(length_transient > 10, 1, 0))

  df_c3 = df_dominant %>%
    filter(age %in% seq(90, 100) & dominant_pft == "IBS") %>%
    group_by(Lon, Lat, PID) %>%
    count() %>%
    filter(n > 5) %>%
    mutate(c3 = 1) %>%
    dplyr::select(-n) %>%
    unique()
  
  df_c4 = df_dominant %>%
    filter(age %in% seq(90, 100) & dominant_pft %in% c("IBS", "BNE")) %>%
    group_by(Lon, Lat, PID) %>%
    count() %>%
    filter(n > 5) %>%
    mutate(c4 = 1) %>%
    dplyr::select(-n) %>%
    unique()
  
  #Classification
  
  # labels 0,1,2
  # Criteria 1: BNE is dominant in years 90-100
  # Criteria 2: IBS is dominant is atleast 10 consecutive years 10-90
  # Criteria 3: IBS is dominant in years 90-100
  # Criteria 4: IBS then BNE is dominant in years 90-100
  
  # Class 0 C1 == True, C2==False
  # Class 1 C2 == True and (C1==True or C3==True)
  # Class 2 Rest
    
    
  df = df_dominant %>%
    dplyr::select(Lon, Lat, PID, year_disturbance) %>%
    unique() %>%
    full_join(df_c1) %>%
    full_join(df_c2) %>%
    full_join(df_c3) %>%
    full_join(df_c4) %>%
    mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>%
    mutate(class = case_when(c1 == 1 & c2 == 0 ~ 0,
                             c2 == 1 & (c1 == 1 | c3 == 1) ~ 1,
                             T ~ 2),
           s = s)

  
  return(df)
  
  
}

classify_trajectories_processed = function(start_year, end_year) {
  
  data = list()
    
    for (s in c("ssp585", "ssp126", "picontrol")) {
      
      df = classify_trajectories_scenario(s, start_year, end_year)
      
      data = append(data, list(df))
      
    }
    
    df = purrr::reduce(data, bind_rows)
    
    write_csv(df, paste0(here("data", "processed"), "/classified_trajectories_processed__", start_year, "_", end_year, ".csv"))
}

classify_trajectories_processed(2015, 2040)
classify_trajectories_processed(2075, 2100)  


######

