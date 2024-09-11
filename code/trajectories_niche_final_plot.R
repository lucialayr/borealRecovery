setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

install.packages("scico")
install.packages("ggnewscale")
install.packages("cowplot")
install.packages("rnaturalearth")
install.packages("rnaturalearthdata")

library(tidyverse)
library(sf)
library(terra)
library(grid)
library(cowplot)
library(scico)
library(ggnewscale)
library(rnaturalearth)
library(rnaturalearthdata)


theme_set(
  theme_classic() + 
    theme(
      axis.text = element_text(color = "black", size = 15),
      axis.title = element_text(color = "black", size = 15),
      plot.title = element_text(color = "black", size = 15),
      plot.subtitle = element_text(color = "black", size = 15),
      plot.caption = element_text(color = "black", size = 15),
      strip.text = element_text(color = "black", size = 15),
      legend.text = element_text(color = "black", size = 15),
      legend.title = element_text(color = "black", size = 15),
      axis.line = element_line(color = "black"),
      panel.grid.major.y = element_line(color = "grey80", linewidth = 0.25),
      legend.background = element_rect(fill='transparent', color = NA),
      legend.box.background = element_rect(fill='transparent', color = NA),
      panel.background = element_rect(fill = "transparent", colour = NA),  
      plot.background = element_rect(fill = "transparent", colour = NA),
      strip.background = element_rect(fill = "transparent", color = NA)
    )
)



plot_trajectories_niche_B = function() {
  
  shp = st_read("data/final/shp/trajectories_niche_B.shp")
  
  load_basemap()
  #color are obtained from 
  #scico::scale_fill_scico_d(name = "Realized niche per scenario", palette = "lajolla", begin = .2, end = .8, direction = -1) +
  
  (p1 = ggplot() + 
      add_basemap() +
      geom_sf(data = shp, aes(fill = scenario), color = NA, linewidth = 0.0, alpha = 1) +
      scale_x_continuous(expand = c(0,0)) +
      scale_y_continuous(expand = c(0,0)) +
      scale_fill_manual(name = "Realized niche expansion", values = c("Control" = "#F0BD57", "SSP1-RCP2.6" = "#D85F4D", "SSP5-RCP8.5" = "#512C1E",
                                                                      "Study region\noutside\nrealized niche" = "grey"),
                        breaks = c("SSP5-RCP8.5", "SSP1-RCP2.6", "Control", "Study region\noutside\nrealized niche" )) + 
      theme(legend.position = "bottom", 
            legend.direction = "horizontal",
            legend.title.position = "top",
            legend.box = "vertical",
            legend.location = "plot",
            legend.justification = "left") +
      guides(fill = guide_legend(order = 2,  ncol = 3, byrow = T),
             color = guide_legend(order = 1))) # second fill guide, order ensures it goes to new line
  
  return(p1)
  
}


plot_trajectories_niche_A = function(start_year, end_year) {
  
  df_mean = read_csv(paste0("data/final/trajectories_mean_A_mean_", start_year, "_", end_year, ".csv"))
  df_trajectories = read_csv(paste0("data/final/trajectories_mean_A_sample_", start_year, "_", end_year, ".csv"))
  df_cmass_mean = read_csv(paste0("data/final/trajectories_mean_A_agc_", start_year, "_", end_year, ".csv"))
  df_cmass_mean_class = read_csv(paste0("data/final/trajectories_mean_A_agc_classes_", start_year, "_", end_year, ".csv"))
  
  (p2 = ggplot() + 
      geom_hline(yintercept = 1, color = "grey") +
      geom_line(data = df_cmass_mean_class, aes(x = age, y = mean_diff, linetype = class), linewidth = 0.75) +
      geom_line(data = df_cmass_mean, aes(x = age, y = mean_diff, linetype = "All patches"),  linewidth = 0.75) +
      geom_line(data = df_trajectories, aes(x = age, y = relative, color = PFT, group = interaction(Lon, Lat, PID, PFT)), linewidth = .05, alpha = .05) +
      geom_line(data = df_mean, aes(x = age, y = relative_mean, color = PFT, group = PFT), linewidth = 1) +
      facet_grid(rows = vars(s)) +
      scale_color_manual(name = "Plant functional types (PFTs)", drop = TRUE,
                         values = c("Needleleaf evergreen" = "#0072B2", "Pioneering broadleaf" = "#E69F00",
                                    "Conifers (other)" = "#56B4E9", "Temperate broadleaf" = "#D55E00",   
                                    "Non-tree V." = "#009E73")) +
      scale_linetype_manual(values = c( "All patches" = "solid", "Direct conifer recovery" = "dashed", "Deciduous transient" = "twodash"), 
                            name = "% of pre-disturbance AGC") +
      scale_x_continuous(name = "Year after disturbance", expand = c(0,0), limits = c(0, 100)) +
      scale_y_continuous(name = paste0("Share of aboveground carbon"), expand = c(0,0), limits = c(0, 1),
                         breaks = c(0.50, 1.00)) +
      theme(legend.position = "right",
            legend.title.position = "top",
            legend.direction = "horizontal",
            legend.location = "plot",
            legend.justification = "left") +
      guides(color = guide_legend(override.aes = list(linewidth = 2), 
                                  nrow = 3, byrow = T),
             linetype = guide_legend(override.aes = list(),
                                     nrow = 2, nyrow = T, keywidth = unit(1, 'cm'))
      ))
  
  return(p2)
  
}


plot_trajectories_niche = function(start_year, end_year) {
  
  trajectories_niche_A = plot_trajectories_niche_A(start_year, end_year)
  
  trajectories_niche_B = plot_trajectories_niche_B()
  
  legend = get_legend(trajectories_niche_A)
  
  line_grob = linesGrob(y = unit(c(0.5, 0.5), "npc"), gp = gpar(col = "black", lwd = 0.5))
  
  (p = plot_grid(trajectories_niche_A + theme(legend.position = "None"), 
                 plot_grid(trajectories_niche_B + theme(legend.margin=margin(0,0,0,0),
                                                        legend.box.margin=margin(-10,-10,-10,-10)), 
                           line_grob, legend, rel_heights = c(0.66, 0.05, 0.3), ncol = 1),
                 ncol = 2, rel_widths = c(1, 1), labels = c( "(a)", "(b)"), hjust = 0))
  
  ggsave(paste("plots/trajectories_niche_", start_year, "_", end_year, ".pdf"), width = 10, height = 7.75, scale = 1) 
  
  return(p)
  
}

plot_trajectories_niche(2015, 2040)

plot_trajectories_niche(2075, 2100)

