setwd("~/Desktop/PhD/borealRecovery")
source("code/utils.R")

library(tidyverse)
library(terra)
library(sf)
library(cowplot)
library(rnaturalearth)
library(rnaturalearthdata)
library(scico)


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



validation_A_plot = function() {
  
  shp = st_read("data/final/shp/validation_A.shp")
  
  study_region = st_read("data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp") %>%
    st_make_valid() %>%
    st_union() %>%
    st_geometry() %>%
    st_transform(., crs = 3408) 
  
  load_basemap()
  
  shp$ecoregion = factor(shp$ecoregion, levels = str_to_title(c("ALASKA BOREAL INTERIOR", "TAIGA CORDILLERA",
                                                                "TAIGA PLAIN", "TAIGA SHIELD", 
                                                                "BOREAL CORDILLERA", "BOREAL PLAIN")))
  
  (p1 = ggplot() + 
      add_basemap() +
      geom_sf(data = study_region, fill = "grey", alpha = 1) +
      geom_sf(data = shp, aes(fill = ecoregion)) +
      scale_fill_scico_d(name = "Ecoregions", palette = "navia", begin = .1, direction = 1) +
      scale_x_continuous(expand = c(0,0), limits = c(-4517639, 0)) +
      scale_y_continuous(expand = c(0,0), limits = c(-1000000, 3368793)) +
      theme(legend.position = "bottom",
            legend.direction = "horizontal",
            legend.title.position = "top") +
      guides(fill = guide_legend(ncol = 2, byrow = T)))
  
  return(p1)
  
}

validation_B_plot = function() {
  
  df = read_csv("data/final/validation_B.csv")
  
  df$age_bin = factor(df$age_bin, levels = c("02-05", "06-09", "10-19", "20-29", 
                                             "30-39", "40-49", "50-69", "50-59"))
  
  df$ecoregion = factor(df$ecoregion, levels = str_to_title(c("ALASKA BOREAL INTERIOR", "TAIGA CORDILLERA",
                                                              "TAIGA PLAIN", "TAIGA SHIELD", 
                                                              "BOREAL CORDILLERA", "BOREAL PLAIN")))
  
  (p2 = ggplot() +
      coord_cartesian(clip = "off") +
      facet_wrap(~ecoregion, ncol = 2) +
      geom_line(data = df, aes( x = age_bin, y = value, group = interaction(age_bin, ecoregion,PFT)), linewidth = .25, color = "black") + 
      geom_point(data = df, aes(x = age_bin, y = value, fill = PFT, shape = dataset), size = 3, color = "black") +  # Adding color for outline
      scale_x_discrete(name = "Year since disturbance") +
      scale_y_continuous(name = "Relative share of vegetation cover", 
                         breaks = c(0, 0.5, 1), limits = c(0,1), expand = c(0,0)) +
      scale_fill_manual(name = "Vegetation class",
                        values = c("Decid. Forest" = "#E69F00",  "Everg. Forest" = "#0072B2",   
                                   "Shrubs, Herb. & Sparse Veg." = "#009E73")) +
      scale_shape_manual(name = "Dataset", values = c("Observations" = 25,  "LPJ-GUESS" = 24)) +
      theme(legend.position = "bottom",
            legend.direction = "horizontal",
            legend.box = 'horizontal',
            legend.title.position = "top",
            legend.justification = c(1, 0),
            axis.text.x = element_text(angle = 90)) +
      guides(fill = guide_legend(override.aes=list(shape=24, size = 4)),
             shape = guide_legend(override.aes = list(size = 4))))
  
  return(p2)
  
}

validation_plot = function() {
  
  validation_A = validation_A_plot()
  
  validation_B = validation_B_plot()
  
  legend = get_legend(validation_B)
  
  plot_grid(validation_A, validation_B, labels = c("(a)", "(b)"), rel_widths = c(0.7, 1), align = "hv", axis = "b")
  
  ggsave("plots/recovery_validation.pdf", width = 10)
  ggsave("plots/recovery_validation.png", width = 10,  height = 6.5, dpi=300)
  
}

validation_plot()




