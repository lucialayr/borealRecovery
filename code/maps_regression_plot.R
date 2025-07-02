setwd("~/Desktop/PhD/borealRecovery")
source("code/utils.R")

library(tidyverse)
library(stats)
library(zoo)
library(splines)
library(cowplot)
library(scico)
library(ggnewscale)
library(rnaturalearth)
library(rnaturalearthdata)



maps_regression_A_plot = function(start_year, end_year) {
  
  shp = st_read(paste0("data/final/shp/maps_regression_A_final_", start_year, "_", end_year, ".shp"))
  
  load_basemap()
  
  study_region = st_read("data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp") %>%
    st_make_valid() %>%
    st_union() %>%
    st_geometry() %>%
    st_transform(., crs = 3408) 
  
  #color are obtained from 
  #scico::scale_fill_scico_d(name = "Realized niche per scenario", palette = "lajolla", begin = .2, end = .8, direction = -1) +
  
  (p2 = ggplot() + 
      add_basemap() +
      geom_sf(data = study_region, color = "black", fill = "grey", linewidth = 0.05) +
      geom_sf(data = shp[shp$class == 2 & shp$PID %in% seq(10, 14), ], color = "grey40", size = .005, shape = 20) +
      geom_sf(data = shp[shp$class == 0 & shp$PID %in% seq(10, 16), ], aes(color = s), size = .005, shape = 20) +
      scico::scale_color_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer replacement \n(transient < 10 years)", direction = -1) +
      guides(color = guide_legend(override.aes = c(size = 3))) +
      ggnewscale::new_scale_color() +
      geom_sf(data = shp[shp$class == 1 & shp$PID %in% seq(10, 16), ], aes(color = s), size = .005, shape = '.') +
      scico::scale_color_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Decidous transient \n> 10 years", direction = -1) +
      scale_x_continuous(expand = c(0,0)) +
      scale_y_continuous(expand = c(0,0)) +
      facet_wrap(~s, ncol = 1, strip.position="right") +
      theme(legend.position = "bottom",
            legend.direction = "vertical") +
      guides(color = guide_legend(override.aes = c(size = 3)))) # second fill guide, order ensures it goes to new line
  
  return(p2)
}

maps_regression_B_plot = function(start_year, end_year) {
  
  df_log = read_csv(paste0("data/final/maps_regression_B_patches_", start_year, "_", end_year,".csv"))
  df_logistic = read_csv(paste0("data/final/maps_regression_B_model_", start_year, "_", end_year,".csv"))
  
  
  (p1 = ggplot() +
     geom_hline(yintercept = 0.5, color = "grey", linewidth = 1) +
     geom_point(data = df_log[df_log$class == 2,], aes(x = tas_smoothed, y = length_transient_trans), size = 0.75,
                color = "darkgrey",  position = position_jitter(width = 0, height = 0.025)) +
     geom_point(data = df_log[df_log$class == 0,], aes(x = tas_smoothed, y = length_transient_trans, color = s), size = 0.75,
                position = position_jitter(width = 0, height = 0.025)) +
     scico::scale_color_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer recovery \n(transient < 10 years)", direction = -1) +
     guides(color = guide_legend(override.aes = list(size = 4))) +
     ggnewscale::new_scale_color() +
     geom_point(data = df_log[df_log$class == 1,], aes(x = tas_smoothed, y = length_transient_trans, color = s), size = 0.75) +
     scico::scale_color_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Decidous transient \n> 10 years", direction = -1) +
     geom_line(data = df_logistic, aes(x = tas_smoothed, y = predicted_probability), linewidth = 1) +
     scale_x_continuous(name = "Growing season temperature in °C, averaged over trajectory", expand = c(0, 0),
                        breaks = c(271, 273, 275, 278, 283), labels = c(271 - 273, 273 - 273, 275 - 273, 278 -273, 283 - 273)) +
     scale_y_continuous(name = "Length of deciduous transient in years", expand = c(0,0), breaks = c(0, 0.25, .5, 0.75, 1), labels = c(0, 5, 10, 50, 100), limits = c(0, 1),
                        sec.axis = sec_axis(~., name = "P(Deciduous transient > 10 years)", breaks = c(0, 0.5, 1), labels = c(0, 0.5, 1))) +
     theme(legend.position = "bottom",
           legend.direction = "vertical") +
     guides(color = guide_legend(override.aes = list(size = 4))))
  
  
  return(p1)
}

maps_regression_B_plot_linear = function(start_year, end_year) {
  
  df_log = read_csv(paste0("data/final/maps_regression_B_patches_", start_year, "_", end_year,".csv"))
  df_logistic = read_csv(paste0("data/final/maps_regression_B_model_", start_year, "_", end_year,".csv"))
  
  
  (p1 = ggplot() +
      geom_hline(yintercept = 0.5, color = "grey", linewidth = 1) +
      geom_point(data = df_log[df_log$class == 2,], aes(x = tas_smoothed, y = length_transient), size = 0.75,
                 color = "darkgrey",  position = position_jitter(width = 0, height = 0.025)) +
      geom_point(data = df_log[df_log$class == 0,], aes(x = tas_smoothed, y = length_transient, color = s), size = 0.75,
                 position = position_jitter(width = 0, height = 0.025)) +
      scico::scale_color_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer recovery \n(transient < 10 years)", direction = -1) +
      guides(color = guide_legend(override.aes = list(size = 4))) +
      ggnewscale::new_scale_color() +
      geom_point(data = df_log[df_log$class == 1,], aes(x = tas_smoothed, y = length_transient, color = s), size = 0.75) +
      scico::scale_color_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Decidous transient \n> 10 years", direction = -1) +
      geom_line(data = df_logistic, aes(x = tas_smoothed, y = predicted_probability), linewidth = 1) +
      scale_x_continuous(name = "Growing season temperature in °C, \naveraged over trajectory", expand = c(0, 0),
                         breaks = c(271, 273, 275, 278, 283), labels = c(271 - 273, 273 - 273, 275 - 273, 278 -273, 283 - 273)) +
      scale_y_continuous(name = "Length of deciduous transient in years", expand = c(0,0), breaks = c(0, 0.25, .5, 0.75, 1), labels = c(0, 5, 10, 50, 100), limits = c(0, 1),
                         sec.axis = sec_axis(~., name = "P(Deciduous transient > 10 years)", breaks = c(0, 0.5, 1), labels = c(0, 0.5, 1))) +
      theme(legend.position = "bottom",
            legend.direction = "vertical") +
      guides(color = guide_legend(override.aes = list(size = 4))))
  
  
  return(p1)
}

maps_regression_plot = function(start_year, end_year) {
  
  maps_regression_A = maps_regression_A_plot(start_year, end_year)
  
  maps_regression_B = maps_regression_B_plot(start_year, end_year)
  
  plot_grid(maps_regression_A + theme(legend.position = "None"), 
            maps_regression_B , 
            rel_widths = c(0.5, 1), labels = c("(a)", "(b)"), 
            ncol = 2, hjust = 0)
  
  ggsave(paste0("plots/maps_regression_", start_year, "_", end_year ,".pdf"), height = 6.25, width = 10, scale = 1)
  ggsave(paste0("plots/maps_regression_", start_year, "_", end_year ,".png"), height = 6.25, width = 10, scale = 1, dpi = 300)
  
}

maps_regression_plot(2015, 2040)
maps_regression_plot(2075, 2100)

