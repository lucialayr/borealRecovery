setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")


library(tidyverse)
library(sf)
library(terra)
library(grid)


install.packages("scico")
install.packages("ggnewscale")
install.packages("cowplot")
install.packages("rnaturalearth")
install.packages("rnaturalearthdata")
library(cowplot)
library(scico)
library(ggnewscale)
library(rnaturalearth)
library(rnaturalearthdata)


get_single_pfts_scenario = function(s) {
  
  data = list()
  
  for (p in c("ibs", "bne", "tebs", "tundra", "otherc")) {
    
    df = read.table(paste0("data/single_pft/cmass_", s, "_", p, ".out"), header = T) %>%
      filter(Year == 2100,
             Total > 0.05) %>%
      terra::rast(crs = "EPSG:4326") %>% # convert to  raster
      as.polygons(dissolve = F, aggregate = T) %>% # convert to shapefile 
      st_as_sf() %>%
      mutate(pft = p) %>%
      dplyr::select(pft) %>%
      st_union() %>%
      st_sf() %>%
      mutate(pft = long_names_pfts(p),
             scenario = long_names_scenarios(s))
    
    data = append(data, list(df))
    
  }
  
  df = purrr::reduce(data, bind_rows)
  
  return(df)
  
}

final_trajectories_niche_B = function() {
  
  # this is a file from my last study that is used to get a shapefile of the study region)
  study_region = st_read("data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp") %>%
    st_make_valid() %>%
    st_union() %>%
    st_geometry() %>%
    st_transform(., crs = 3408) 
  
  #get theoretical niche IBS for all scenarios (picontrol is enough since we know it does not change
  df_picontrol = get_single_pfts_scenario("picontrol") %>%
    filter(pft == "Pioneering broadleaf") %>%
    st_transform(., crs = 3408) 
  
  data = list()
  
  for (s in c("picontrol", "ssp126", "ssp585")) {
    for (p in c("IBS")) {
      
      df = read.table(paste0("data/", s, "_d150/cmass.out"), header = T) %>%
        filter(Year == 2100) %>%
        dplyr::select(all_of(c("Lon", "Lat", p, "Total"))) %>%
        mutate(relative = !!rlang::sym(p)/ Total) %>%
        dplyr::filter(IBS > 0.05) %>%
        terra::rast(crs = "EPSG:4326") %>% # convert to  raster
        as.polygons(dissolve = F, aggregate = T) %>% # convert to shapefile 
        st_as_sf() %>%
        mutate(pft = p) %>%
        dplyr::select(p) %>%
        st_union() %>%
        st_sf() %>%
        mutate(pft = long_names_pfts(tolower(p)),
               scenario = long_names_scenarios(s))
      
      head(df)
      
      data = append(data, list(df))
    }
  }
  
  df_reality = purrr::reduce(data, bind_rows) %>%
    st_transform(., crs = 3408) 
  
  polygon_A = df_reality[df_reality$scenario == "Control", ]
  polygon_B = df_reality[df_reality$scenario == "SSP1-RCP2.6", ]
  polygon_C = df_reality[df_reality$scenario == "SSP5-RCP8.5", ]
  
  # Calculate differences
  B_minus_A = st_difference(polygon_B, polygon_A)
  C_minus_B = st_difference(polygon_C, polygon_B)
  Theory_minus_C = st_difference(df_picontrol, polygon_C)
  
  B_minus_A$scenario = "SSP1-RCP2.6"
  C_minus_B$scenario = "SSP5-RCP8.5"
  polygon_A$scenario = "Control" # To keep the naming consistent
  Theory_minus_C$scenario = "Study region\noutside\nrealized niche"
  # Combine the geometries into one sf object for plotting
  polygons_to_plot = bind_rows(list(polygon_A, B_minus_A, C_minus_B, Theory_minus_C))
  
  
  st_write(polygons_to_plot, "data/final/shp/trajectories_niche_B.shp")
}

final_trajectories_niche_B()

final_trajectories_niche_A = function(start_year, end_year) {
  
  data = list()
  
  data_carbon = list()
  
  for (s in c("picontrol", "ssp126", "ssp585")) {
    df_timeseries = read_csv(paste0("data/processed/trajectories_", s, "_", start_year, "_", end_year, "_timeseries_rf.csv" )) %>%
      mutate(s = s)
    
    data = append(data, list(df_timeseries))
    
    df_carbon = read_csv(paste0("data/processed/agc_recovery_", scenario, "_", start_year, "_", end_year, "_.csv" )) %>%
      mutate(s = s)
    
    data_carbon = append(data_carbon, list(df_carbon))
  }
  
  df = purrr::reduce(data, bind_rows) %>%
    mutate(s = long_names_scenarios(s),
           PFT = long_names_pfts(tolower(PFT)))
  
  df$PFT = factor(df$PFT, levels = rev(c( "Needleleaf evergreen", "Pioneering broadleaf" ,   
                                          "Conifers (other)", "Temperate broadleaf" , 
                                          "Non-tree V.")))
  
  df_mean = df %>%
    group_by(s, age, PFT) %>%
    summarize(relative_mean = mean(relative, na.rm = T))
  
  sampled_ids = df %>%
    distinct(s, Lon, Lat, PID) %>%  # Identify unique time series for each 's'
    group_by(s) %>%  # Group by 's'
    slice_sample(n = 300) %>%  # Sample a fixed number of time series within each 's'
    ungroup()
  
  df_trajectories = df %>%
    semi_join(sampled_ids, by = c("Lon", "Lat", "PID"))
  
  df_class = read_csv(paste0("data/results/classes_100years_", start_year, "_", end_year, ".csv")) %>%
    dplyr::select(Lon, Lat, PID, class)
  
  df_cmass = purrr::reduce(data_carbon, bind_rows) %>%
    filter(time_since_dist > 100) %>%
    left_join(df_class)
  
  df_cmass_mean = df_cmass %>%
    group_by(s, age) %>%
    summarise(mean_diff = mean(diff)) %>%
    mutate(s = long_names_scenarios(s),
           mean_diff = if_else(mean_diff > 1, NA ,mean_diff))
  
  df_cmass_mean_class = df_cmass %>%
    filter(class %in% c(0, 1)) %>%
    group_by(s, age, class) %>%
    summarise(mean_diff = mean(diff)) %>%
    mutate(s = long_names_scenarios(s),
           class = if_else(class == 0, "Direct conifer recovery", "Deciduous transient"),
           mean_diff = if_else(mean_diff > 1,  NA ,mean_diff))

  
  write_csv(df_mean, paste0("data/final/trajectories_mean_A_mean_", start_year, "_", end_year, ".csv"))
  write_csv(df_trajectories, paste0("data/final/trajectories_mean_A_sample_", start_year, "_", end_year, ".csv"))
  write_csv(df_cmass_mean, paste0("data/final/trajectories_mean_A_agc_", start_year, "_", end_year, ".csv"))
  write_csv(df_cmass_mean_class, paste0("data/final/trajectories_mean_A_agc_classes_", start_year, "_", end_year, ".csv"))
  
 
}

final_trajectories_niche_A(2015, 2040)

final_trajectories_niche_A(2075, 2100)



