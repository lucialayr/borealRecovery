library(tidyverse)
library(terra)
library(sf)

install.packages("scico")
install.packages("cowplot")
install.packages("rnaturalearth")
install.packages("rnaturalearthdata")

library(scico)
library(cowplot)
library(rnaturalearth)
library(rnaturalearthdata)

library(here)
source(here("code", "utils.R"))

unit_conversion = function(x, var) {
  if (var == "tas") {
    x = x - 273.15
  } else if (var == "pr") {
    x = x*60 *60 *24*356
  } 
  else {
    x = x
  }
  
  return(x)
}

load_climate_variables_eoc = function(var = "tas") {
  
  data = list()

  
  for (s in c("picontrol", "ssp126", "ssp585")) {
    
    study_region = terra::vect(here("data", "external", "vegetation_ssp585_d0.003_fpc_30years2100.shp")) 
    
    raster = terra::rast(paste0(here("data", "raw", "climate_data", "mri-esm2-0_r1i1p1f1_",  s, "_", var, "_daily_inverted_1850_2300_boreal_monthly.nc")) %>%
      terra::mask(study_region) 
    
    df = data.frame("time" = terra::time(raster),
                    mean = terra::global(raster, "mean", na.rm = TRUE),
                    min = terra::global(raster, "min", na.rm = TRUE),
                    max = terra::global(raster, "max", na.rm = TRUE)) %>%
      mutate(year = format(as.Date(time), "%Y"),
             day = format(as.Date(time), "%D"),
             month = tolower(month.abb[as.numeric(format(as.Date(time), "%m"))])) %>%
      filter(year %in% seq(2070, 2100)) %>%
      group_by(month) %>%
      summarize(mean = mean(mean),
                min = mean(min),
                max = mean(max)) %>%
      mutate(mean = unit_conversion(mean, var),
             min = unit_conversion(min, var),
             max = unit_conversion(max, var),
             s = long_names_scenarios(s))
    
    data = append(data, list(df))
  }
  
  df = purrr::reduce(data, rbind)
  
  return(df)
}

load_climate_variables_maps = function(var = "tas") {
  
  data = list()
  
  
  
  study_region = terra::vect(here("data", "external", "vegetation_ssp585_d0.003_fpc_30years2100.shp")) 
  
  for (s in c("picontrol", "ssp126", "ssp585")) {
  
    raster = terra::rast(paste0(here("data", "raw", "climate_data", "mri-esm2-0_r1i1p1f1_",  s, "_", var, "_daily_inverted_1850_2300_boreal_monthly.nc")) %>%
      terra::mask(study_region) 
    
    raster = raster[[time(raster) > as.Date("2070-01-05") & time(raster) < as.Date("2100-12-31")]]
    
    
    dte = time(raster)
    m = as.numeric(format(dte, "%m"))
    i = (m %in% seq(3, 11))
    x = raster[[i]]
    
    df = terra::mean(x) %>%
      as.polygons(aggregate = T) %>%
      st_as_sf() %>%
      st_transform(crs = "EPSG:3408") %>%
      mutate(s = long_names_scenarios(s),
             mean = mean - 273.15)
    
    data = append(data, list(df))
  }
  
  df = purrr::reduce(data, rbind)
  
  return(df)
}


plot_maps = function() {
  
  df = load_climate_variables_maps()
  
  
  load_basemap()
  
  df_test = df %>%
    mutate(mean = case_when(mean < 0 ~ "< 0",
                            mean > 0 & mean < 5 ~ "0 - 5",
                            mean > 5 & mean < 10 ~ "5 - 10",
                            mean > 10 ~ "> 10")) %>%
    group_by(mean, s) %>%
    summarise()
  
  df_test$mean = factor(df_test$mean, levels = c("< 0", "0 - 5", "5 - 10", "> 10"))
  
  (p = ggplot() + 
      add_basemap() +
      geom_sf(data = df_test, aes(fill = mean), color = NA) +
      scico::scale_fill_scico_d(palette = "vik", name = expression(T[G]~"in °C"), begin = .4, end = .8) +
      scale_x_continuous(expand = c(0,0)) +
      scale_y_continuous(expand = c(0,0)) +
      facet_wrap(~s, nrow = 2) +
      theme(legend.position = c(0.8,0.2),
            legend.direction = "horizontal",
            legend.title.position = "top") +
      guides(fill = guide_legend(nrow = 2, byrow = T,
                                 override.aes = list(color = "grey", linewidth = 0.5))))
  
  return(p)
}


plot_temperature_eoc = function() {
  
  df = load_climate_variables_eoc()
  order_months = labels = c("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")
  df$month = factor(df$month, c("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"))
  
  (p = ggplot() + 
      geom_hline(yintercept = 0, color = "grey", linewidth = .3) +
      geom_ribbon(data = df, aes(x = month,  ymin = min, ymax = max, fill = s, group = interaction(s)), alpha = .1) +
      geom_line(data = df, aes(x = month, y = mean, color = s, group = interaction(s)), linewidth = 1) +
      scico::scale_fill_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Scenario", direction = -1) +
      scico::scale_color_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Scenario", direction = -1) +
      scale_x_discrete(labels = order_months, name = "Month of the year", expand = c(0,0)) + 
      scale_y_continuous(expand = c(0,0), name = "Temperature in °C", breaks = c(-20, 0, 20)) +
      theme(legend.position = c(0.55, 0.2),
            legend.direction = "vertical") +
      guides(color = guide_legend(title.position="top", 
                                  title="Climate scenario\n", 
                                  override.aes = list(linewidth = 2)),
             fill = guide_none()))
  
  return(p)
  
}

(p1 = plot_maps())
(p2 = plot_temperature_eoc())

plot_grid(p2, p1, align = "hv", axis = "b", rel_widths = c(0.9, 1), labels = c("(a)", "(b)"))

ggsave(here("plots", "growing_season_temperature.pdf",  height = 5, width = 10, scale = 1)



# Figure in background chapter of thesis that used this data. 
# I know this is not very elegent but until I have time to change it, it has to live here :)
load_climate_variables_chapter1 = function() {
  
  data = list()
  
  var  =  "pr"
  
  
  for (s in c("picontrol", "ssp126", "ssp370", "ssp585")) {
    
    study_region = terra::vect(here("data", "external", "vegetation_ssp585_d0.003_fpc_30years2100.shp")) 
    
    raster = terra::rast(paste0(here("data", "raw", "climate_data", "mri-esm2-0_r1i1p1f1_",  s, "_", var, "_daily_inverted_1850_2300_boreal_monthly.nc")) %>%
      terra::mask(study_region) 
    
    df = data.frame("time" = terra::time(raster),
                    mean = terra::global(raster, "mean", na.rm = TRUE)) %>%
      rename(mean_pr = mean) %>%
      mutate(year = format(as.Date(time), "%Y"),
             day = format(as.Date(time), "%D"),
             month = tolower(month.abb[as.numeric(format(as.Date(time), "%m"))]),
             mean_pr = mean_pr*60 *60 *24*30) %>%
      filter(year %in% seq(2085, 2100)) %>%
      group_by(month) %>%
      summarize(mean = mean(mean_pr),
                min = min(mean_pr),
                max = max(mean_pr)) %>%
      mutate(s = long_names_scenarios(s))
    
    data = append(data, list(df))
  }
  
  df = purrr::reduce(data, rbind)
  
  return(df)
}

df = load_climate_variables_chapter1()

write_csv(df, "precipitation_studyregion_2085_2100_mmmonth.csv")


