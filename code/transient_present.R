setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(duckdb)
library(tidyverse)
library(purrr)
library(sf)


con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
dbListTables(con)
scenario = "ssp126"
variable = "cmass"
start_year = 2015
end_year = start_year + 25
length = 200

# run this for all 18 datasets
create_one_instance = function(scenario, variable, start_year, end_year, length) {
  df = read_csv(paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, "_", variable, "_", length, ".csv"), show_col_types = F) %>%
    mutate(relative = replace_na(relative, 0)) %>%
    group_by(Lon, Lat, PID, age) %>%
    mutate(dominant_pft = PFT[which.max(relative)]) %>%
    ungroup()
  
  df_transient = df %>%  #filter for patches exhibiting a long transient after disturbance
    filter(age > 10 & age < 150 & dominant_pft == "IBS") %>% #transient in years 10 - 150 after disturbances
    select(Lon, Lat, PID, age, dominant_pft) %>%
    unique() %>%
    group_by(Lon, Lat, PID) %>%
    count(dominant_pft) %>%
    filter(n > 10) %>% # transient should be present for at least ten years
    select(Lon, Lat, PID)
  
  df_final_bne  = df %>%
    select(Lon, Lat, PID, age, dominant_pft) %>%
    unique() %>%
    filter(age > 195 & age < 201 & dominant_pft == "BNE") %>% #filtering for patches where BNE is dominated between 195 and 201 years after disturbance
    group_by(Lon, Lat, PID) %>%
    count(dominant_pft) %>%
    filter(n == 5) %>% # make sure condition is true for all years
    select(Lon, Lat, PID)
  
  df_transient_ts = df %>%
    right_join(df_transient) %>% #all patches in df_transient
    #inner_join(df_final_bne) %>% #all patches in df_transient that are as well in df_final_bne
    mutate(PFT = long_names_pfts(tolower(PFT))) %>%
    select(Lon, Lat, PID, age, PFT, relative) %>%
    unique() %>%
    mutate(type = "Deciduous transient")
  
  df_no_transient_ts = df %>%
    right_join(df_final_bne) %>% #all patches in df_final_bne
    anti_join(df_transient) %>% #throw out all rows that have a transient
    mutate(PFT = long_names_pfts(tolower(PFT))) %>%
    select(Lon, Lat, PID, age, PFT, relative) %>%
    unique() %>%
    mutate(type = "No transient")
  
  df_other_ts = df %>%
    select(Lon, Lat, PID, ) %>%
    unique() %>%
    anti_join(df_transient) %>%
    anti_join(df_final_bne) %>%
    left_join(df) %>%
    mutate(PFT = long_names_pfts(tolower(PFT))) %>%
    mutate(type = "Other")
  
  df_other = df_other_ts %>%
    select(Lat, Lon, PID) %>%
    unique()
  
  df_ts = bind_rows(df_transient_ts, df_no_transient_ts, df_other_ts)
  
  write_csv(df_ts, paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, "_", variable, "_", length, "_binary.csv"))
}



for (scenario in c("ssp126", "ssp585", "picontrol")) {
  for (start_year in c(2015, 2045, 2075)) {
    for (variable in c("cmass")) {
      create_one_instance(scenario, variable, start_year, start_year + 25, 200) 
    }
  }
}


df_ts_mean = df_ts %>%
  group_by(age, type, PFT) %>%
  summarize(relative = mean(relative))


(ggplot() + theme_bw() +
    geom_line(data = df_ts,  aes(x = age, y = relative, group = interaction(Lon, Lat, PID, PFT), color = PFT), linewidth = .05, alpha = .25,) +
    geom_line(data = df_ts_mean,  aes(x = age, y = relative, group = interaction(PFT), color = PFT), linewidth = 2) +
    facet_grid(cols = vars(type)) +
    scale_x_continuous(name = "Year after disturbance", expand = c(0,0), limits = c(-2, 200)) +
    scale_y_continuous(name = "Share of FPC", expand = c(0,0), limits = c(0, 1.05),
                       breaks = c(0.25, 0.50, 0.75, 1.00)) +
    scale_color_manual(name = "Dominant vegetation", drop = TRUE,
                       values = c("Temperate broadleaf" = "#D55E00", "Pioneering broadleaf" = "#E69F00",  "Needleleaf evergreen" = "#0072B2",   
                                  "Conifers (other)" = "#56B4E9", "Tundra" = "#009E73")))





create_maps = function(variable, length) {
  
  if (file.exists(paste0("data/processed/clustered_trajectories_locations_", variable, "_", length, ".csv"))) {
    
    df = read_csv(paste0("data/processed/clustered_trajectories_locations_", variable, "_", length, ".csv"), show_col_types = F) 
    
  } else {
    
    data = list()
    
    for (scenario in c("ssp126", "ssp585", "picontrol")) {
      for (start_year in c(2015, 2045, 2075)) {
        df_ts_locations = read_csv(paste0("data/processed/trajectories_", scenario, "_", start_year, "_", start_year + 25, "_", variable, "_", length, "_binary.csv"), show_col_types = F) %>%
          select(Lon, Lat, PID, type) %>%
          unique() %>%
          mutate(scenario = scenario, 
                 tD = paste0(start_year, " - ", start_year + 25))
        
        data = append(data, list(df_ts_locations))
      }
    }
    
    df = purrr::reduce(data, bind_rows)
    
    write_csv(df, paste0("data/processed/clustered_trajectories_locations_", variable, "_", length, ".csv"))
    
  }
  
  
  outline = st_read("data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp") %>%
    st_make_valid() %>%
    st_union() %>%
    st_geometry()
  
  df = df %>%
    mutate(scenario = long_names_scenarios(scenario)) %>%
    subgrid_location()
  
  fontsize = 15
  
  (p = ggplot() + theme_bw() +
      geom_sf(data = outline, color = "grey", fill = "grey") +
      geom_point(data = df[df$type == "Other", ], aes(x = Lon_PID, y = Lat_PID, color = type, fill = type),  size = .01, shape = 15) +
      geom_point(data = df[df$type != "Other", ], aes(x = Lon_PID, y = Lat_PID, color = type, fill = type),  size = .01, shape = 15) +
      facet_wrap(tD ~ scenario) +
      #facet_grid(cols = vars(scenario), rows = vars(tD)) + 
      scale_x_continuous(name = "") +
      scale_y_continuous(name = "") +
      scale_fill_manual(name = "Recovery trajectory", values = c("No transient" = "#0072B2", "Deciduous transient" = "#E69F00", "Other" = "grey40")) +
      scale_color_manual(name = "Recovery trajectory", values = c("No transient" = "#0072B2", "Deciduous transient" = "#E69F00", "Other" = "grey40")) +
      theme(axis.title = element_text(size = fontsize),
            legend.background = element_rect(fill='transparent', color = NA),
            legend.box.background = element_rect(fill='transparent', color = NA),
            legend.box.margin=unit(c(1,1,1,1), "pt"),
            panel.background = element_rect(fill = "transparent", colour = NA),  
            plot.background = element_rect(fill = "transparent", colour = NA),
            strip.background = element_rect(fill = "transparent", color = NA),
            strip.text = element_text(size = fontsize - 5),
            axis.text = element_blank(),
            text = element_text(size = fontsize),
            legend.position = "bottom",
            legend.direction = "horizontal") +
      guides(color = guide_legend(override.aes = list(size=5)))) 
  
  ggsave(paste0("figures/maps_", variable, "_", length, ".png"), height = 4, width = 9)
  
}

create_maps("cmass", 200)

df_pids = subgrid_location(df)

ggplot() + geom_tile(data = df_pids, aes(x = Lon_PID, y = Lat_PID, fill = type))

### classified time series
variable = "cmass"
length = 200
data = list()

for (scenario in c("ssp126", "ssp585", "picontrol")) {
  for (start_year in c(2015)) {
    df_ts_locations = read_csv(paste0("data/processed/trajectories_", scenario, "_", start_year, "_", start_year + 25, "_", variable, "_", length, "_binary.csv"), show_col_types = F) %>%
      mutate(scenario = scenario, 
             tD = paste0(start_year, " - ", start_year + 25))
    
    data = append(data, list(df_ts_locations))
  }
}

df = purrr::reduce(data, bind_rows) %>%
  mutate(scenario = long_names_scenarios(scenario))

df_mean = df %>%
  group_by(age, type, scenario, PFT) %>%
  summarize(relative = mean(relative))

fontsize = 15

(ggplot() + theme_bw() +
    geom_line(data = df,  aes(x = age, y = relative, group = interaction(Lon, Lat, PID, PFT), color = PFT), linewidth = .05, alpha = .25,) +
    geom_line(data = df_mean,  aes(x = age, y = relative, group = interaction(PFT), color = PFT), linewidth = 2) +
    facet_grid(rows = vars(type), cols = vars(scenario)) +
    scale_x_continuous(name = "Year after disturbance", expand = c(0,0), limits = c(-2, 200)) +
    scale_y_continuous(name = "Share of cmass", expand = c(0,0), limits = c(0, 1.05),
                       breaks = c(0.25, 0.50, 0.75, 1.00)) +
    scale_color_manual(name = "Dominant vegetation", drop = TRUE,
                       values = c("Temperate broadleaf" = "#D55E00", "Pioneering broadleaf" = "#E69F00",  "Needleleaf evergreen" = "#0072B2",   
                                  "Conifers (other)" = "#56B4E9", "Tundra" = "#009E73")) +
    theme(axis.title = element_text(size = fontsize),
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA),
          strip.text = element_text(size = fontsize),
          text = element_text(size = fontsize)))

ggsave(paste0("figures/classified_trajectories_", variable, "_", length, ".png"))
