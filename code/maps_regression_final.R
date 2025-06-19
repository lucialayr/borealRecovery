setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(tidyverse)
library(stats)
library(zoo)
library(splines)


maps_regression_A_final = function(start_year, end_year) {
  
  df = read_csv(paste0("data/processed/classified_trajectories_processed__", start_year, "_", end_year, ".csv"))
  
  df_sf = df %>%
    st_as_sf(coords = c("Lon", "Lat"), crs = 4326) %>%
    mutate(s = long_names_scenarios(s))
  
  st_write(df_sf, paste0("data/final/shp/maps_regression_A_final_", start_year, "_", end_year, ".shp"))
}
maps_regression_A_final(2015, 2040)
maps_regression_A_final(2075, 2100)
#########################
#########################


classify_trajectories = function(s, start_year, end_year) {
  
  df_dominant = read_csv(paste0("data/processed/trajectories_", s, "_", start_year, "_", end_year, "_timeseries_rf.csv"))  %>%
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
  
  check = df_c2 %>%
    filter(Lon == -93.25 & Lat == 52.25 & PID == 20)

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
  
  
} # this is an redundancy of classified_trajectories_processed but I cant figure out a better way at the moment

get_climate_data = function(df, s, start_age, window, start_year, end_year) {
  
  climate = read_csv(paste0("data/processed/covariates_", s, "_", start_year, "_", end_year, "_growingseason.csv")) %>%
    dplyr::select(Lon, Lat, Year, tas_gs_dailyavg) %>%
    group_by(Lon, Lat) %>%
    mutate(tas_smoothed = rollmean(tas_gs_dailyavg, k = window, fill = NA, align = "left"), #from start year into the future
           timespan_climate = paste0("T for ", start_age, " - ", start_age + window, " years after disturbance"))
  
  df = df %>%
    dplyr::select(Lat, Lon, PID, year_disturbance, class, s, length_transient) %>%
    ungroup() %>%
    rename(Year = year_disturbance) %>%
    unique() %>%
    left_join(climate) %>% #join to filter for only year of disturbanced + 100 value
    mutate(class_factor = as.factor(class)) %>%
    filter(!is.na(tas_gs_dailyavg))
  
  return(df)
  
}

create_data = function(start_year, end_year) {
  data = list()
  
  for (s in c("ssp585", "ssp126", "picontrol")) {
    
    df = classify_trajectories(s, start_year, end_year) %>%
      get_climate_data(s, 0, 10, start_year, end_year)
    
    data = append(data, list(df))
    
  }
  
  df = purrr::reduce(data, bind_rows) %>%
    mutate(s = long_names_scenarios(s),
           tas_smoothed = tas_smoothed) 
  
  write_csv(df, paste0("data/results/all_binary_data_", start_year, "_", end_year,".csv"))
  
  return(df)
}

add_model_to_data = function(df, model, model_string) {
  
  df = df %>%
    filter(class != 2) %>%
    mutate(aic = AIC(model),
           predicted_probability = predict(model, type = "response"),
           model_type = model_string)
  
  return(df)
}

fit_binary_data = function(df, start_year, end_year) {
  
  df = df %>%
    filter(class != 2) #filter out trajectories that are in neither category
  
  null_model = glm(class ~ 1, data = df, family = binomial)
  linear_model = glm(class ~ tas_smoothed, data = df, family = binomial)
  
  df = df %>%
    mutate(T_273 = ifelse(tas_smoothed > 273, tas_smoothed - 273 , 0),
           T_275 = ifelse(tas_smoothed > 275 , tas_smoothed - 275 , 0),
           T_277 = ifelse(tas_smoothed > 277 , tas_smoothed - 277 , 0))
  
  piecewise_model_273 = glm(class ~ tas_smoothed + T_273, data = df, family = binomial)
  piecewise_model_275 = glm(class ~ tas_smoothed + T_275, data = df, family = binomial)
  piecewise_model_277 = glm(class ~ tas_smoothed + T_277, data = df, family = binomial)
  spline_model = glm(class ~ ns(tas_smoothed, df = 4), data = df, family = binomial)
  
  df_null = add_model_to_data(df, null_model, "null_model")
  df_linear = add_model_to_data(df, linear_model, "linear_model")
  df_piecewise_273 = add_model_to_data(df, piecewise_model_273, "piecewise_model_273")
  df_piecewise_275 = add_model_to_data(df, piecewise_model_275, "piecewise_model_275")
  df_piecewise_277 = add_model_to_data(df, piecewise_model_277, "piecewise_model_277")
  df_spline = add_model_to_data(df, spline_model, "spline_model")
  
  df_models = purrr::reduce(list(df_null, df_linear, df_piecewise_273, df_piecewise_275, df_piecewise_277, df_spline),
                            bind_rows)
  
  df_aic = df_models %>%
    dplyr::select(model_type, aic) %>%
    unique() %>%
    arrange(aic)
  
  print(df_aic)
  
  write_csv(df_aic, paste0("data/final/maps_regression_AIC_", start_year, "_", end_year, ".csv"))
  
  df_best_fit = df_models %>%
    filter(aic == min(aic))
  
  return(df_best_fit)
  
}


maps_regression_B_final = function(start_year, end_year) {
  df = create_data(start_year, end_year)
  
  df_logistic = fit_binary_data(df, start_year, end_year) %>%
    dplyr::select(tas_smoothed, predicted_probability) 
  
  df_log = df %>%
    filter(PID > 15) %>%
    dplyr::select(tas_smoothed, class,  length_transient, Lon, Lat, PID, s) %>%
    mutate(length_transient_trans = if_else(length_transient == 0, 0, 0.5*log10(length_transient))) #transform transient length to log scale
  
  write_csv(df_log, paste0("data/final/maps_regression_B_patches_", start_year, "_", end_year,".csv"))
  write_csv(df_logistic, paste0("data/final/maps_regression_B_model_", start_year, "_", end_year,".csv"))
  
}


maps_regression_B_final(2015, 2040)
maps_regression_B_final(2075, 2100)

