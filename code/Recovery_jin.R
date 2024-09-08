setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(dplyr)
library(terra)
library(sf)

install.packages("cowplot")
library(cowplot)
#The goal of this analysis is to compare recovery dynamics from LPJ-GUESS with those Kim et al. present for the ABoVE domain. 

# we first get the LPJ-GUESS output grid as a raster
lpjguess_grid = read_table("data/picontrol_d150/cmass.out", show_col_types = F) %>%
  filter(Year == 2000) %>%
  terra::rast(crs = "EPSG:4326") #produce a raster in lpjguess resolution
  
# we take the ABoVE extent raster and reproject and resample it to match the LPJ-GUESS output
above = terra::rast("data/external/ABoVE_Study_Domain.tif") %>% #get above domain, project, resample to lpjguess resolution and get coordinates
  terra::project("EPSG:4326") %>%
  terra::resample(lpjguess_grid, method = "near") %>%
  terra::as.data.frame(xy = T) %>% #export grid as data fram
  mutate(ABoVE_Study_Domain = if_else(ABoVE_Study_Domain > 1, 2, 1)) %>% #clean up some smearing of values
  rename(Lon = x, Lat = y) %>%
  filter(ABoVE_Study_Domain == 1) # filter for ABoVE core domain

#######
# 1. Visualize the extend of ABoVE and the model

above_extend = terra::rast("data/external/ABoVE_Study_Domain.tif") %>% #get above domain, project, resample to lpjguess resolution and get coordinates
  terra::project("EPSG:4326") %>%
  terra::resample(lpjguess_grid, method = "near") %>%
  terra::as.data.frame(xy = T) %>% #export grid as data fram
  mutate(ABoVE_Study_Domain = if_else(ABoVE_Study_Domain > 1, "Extended", "Core")) %>% #clean up some smearing of values
  rename(Lon = x, Lat = y)

lpjguess_extend = read_table("data/picontrol_d150/cmass.out", show_col_types = F) %>%
  select(Lon, Lat) %>% unique()

ggplot() +
  theme_void() +
  coord_equal() +
  geom_tile(data = above_extend, aes(x = Lon, y = Lat, fill = ABoVE_Study_Domain), color = "darkgrey") +
  geom_point(data = lpjguess_extend[lpjguess_extend$Lon < -100,], aes(x = Lon, y = Lat), shape = 4, size = 0.75, stroke = .25) +
  theme(text = element_text(size = 15),
        legend.text = element_text(size = 15),
        axis.text.x = element_text(size = 15),
        axis.text.y = element_text(size = 15),
        legend.background = element_rect(fill='transparent', color = NA),
        legend.box.background = element_rect(fill='transparent', color = NA),
        panel.background = element_rect(fill = "transparent", colour = NA),  
        plot.background = element_rect(fill = "transparent", colour = NA),
        strip.background = element_rect(fill = "transparent", color = NA))

ggsave("figures/ABoVE/extend.png", height = 2)

# Maybe it would be worthwhile to simulate the whole Boreal forest, not just the selection from the previous study. 
# Anyways, we'll take all data that is within the core ABoVE domain


###next we want to divide LPJ output into the different eocregions
ecoregion_ii = st_read("data/external/NA_CEC_Eco_Level2.shp") %>%
  sf::st_transform(crs = "EPSG:4326") %>%
  sf::st_make_valid()

above_shp = terra::rast("data/external/ABoVE_Study_Domain.tif") %>% #get above domain, project, resample to lpjguess resolution and get coordinates
  terra::project("EPSG:4326") %>%
  terra::as.polygons() %>%
  sf::st_as_sf() %>%
  filter(ABoVE_Study_Domain == 1)

lpj_shp = lpjguess_grid %>%
  terra::as.polygons() %>%
  st_as_sf() %>%
  st_geometry() %>%
  sf::st_transform(crs = "EPSG:4326") %>%
  st_make_valid() %>%
  st_intersection(ecoregion_ii, .) %>%
  st_intersection(above_shp) %>%
  select("NA_L2NAME")

lpjguess_grid = read_table("data/picontrol_d150/cmass.out", show_col_types = F) %>%
  filter(Year == 2000) %>%
  select(Lon, Lat, Total) %>%
  terra::rast(crs = "EPSG:4326") %>% 
  terra::as.polygons(aggregate = F) %>%
  st_as_sf() %>%
  st_make_valid() %>%
  sf::st_join(lpj_shp) %>%
  filter(!is.na(NA_L2NAME))


lpjguess_ecoregion = lpjguess_grid %>%
  rename(ecoregion = NA_L2NAME) %>%
  mutate(Lon = round(st_coordinates(st_centroid(geometry))[, 1], 2),
         Lat = round(st_coordinates(st_centroid(geometry))[, 2], 2)) %>%
  as.data.frame() %>%
  select(-geometry, -Total) %>%
  distinct(Lon, Lat, .keep_all = TRUE) #keep only first ecoregion (not ideal but only thing that works for now)
#We'll also need a function to relcassify LPJ-GUESS vegetation to the categories from the paper

reclassify_vegetation = function(x) {
  x = gsub("ibs", "Decid. Forest", x)
  x = gsub("tebs", "Decid. Forest", x)
  x = gsub("bne", "Everg. Forest", x)
  x = gsub("tundra", "Shrubs, Herb. & Sparse Veg.", x)
  x = gsub("soil", "Non-Vegetated", x)
  x = gsub("otherc", "Everg. Forest", x)
  return(x)
}

# And we'll need a function to bin age and make everything plot ready
bin_data_for_plot = function(df, variable) {
  
  age_bins = c(-Inf, 2, 5, 9, 19, 29, 39, 49, 69)
  labels = c("pre-\ndisturbance", "2-5", "6-9", "10-19", "20-29", "30-39", "40-49", "50-69")
  
  df_binned = df %>%
    mutate(age_bin = cut(age, breaks = age_bins, labels = labels, right = FALSE)) %>%
    group_by(age_bin, PFT, ecoregion) %>%
    summarize(variable = mean(!!rlang::sym(variable), na.rm = TRUE)) %>%
    ungroup() %>%
    mutate(PFT = reclassify_vegetation(tolower(PFT))) %>%
    group_by(age_bin, PFT, ecoregion) %>%
    summarize(variable = sum(variable, na.rm = TRUE))
  
  df_binned$PFT <- factor(df_binned$PFT, levels = rev(c('Everg. Forest', 'Decid. Forest', "Shrubs, Herb. & Sparse Veg.", 'Non-Vegetated')))
  
  return(df_binned)
}


####
#2. Plot FPC. 

#Since the paper plots vegetation cover percentage, we'll first plot FPC
fpc = read_csv("data/processed/trajectories_picontrol_2015_2040_fpc_200.csv")  %>%
  inner_join(lpjguess_ecoregion) %>% #crop to ecoregions 
  filter(!is.na(age)) %>% #filter for locations that are in ABoVE but not in model ouput
  filter(age != 0, age != 1) %>% #delete year of disturbance, no meaningful data
  group_by(Lon, Lat, age, PID, ecoregion) %>%
  pivot_wider(names_from = PFT, values_from = fpc) %>%
  filter(age < 61) %>% #filter to age range of paper
  mutate(across(everything(), ~replace_na(.x, 0))) %>% #fill in missing values
  mutate(Soil = if_else(BNE + IBS + TeBS + Tundra + otherC < 1, 1 - (BNE + IBS + TeBS + Tundra + otherC), 0)) %>% #alculate soil fraction
  pivot_longer(cols = c(BNE, IBS, TeBS, Tundra, otherC, Soil), names_to = "PFT", values_to = "fpc") %>%
  group_by(age, PFT, ecoregion) %>% #make plot read, aggregate
  summarize(fpc = mean(fpc)) %>%
  bin_data_for_plot("fpc")

(p1 = ggplot() +
    theme_minimal() +
    geom_bar(data = fpc, aes(x = age_bin, y = variable, fill = PFT), stat = "identity", position = "fill", alpha = 0.7, color = "black") +
    scale_x_discrete(name = "Year since disturbance", expand = c(0,0)) +
    scale_y_continuous(name = "", expand = c(0,0)) +
    scale_fill_manual(name = "Vegetation class", drop = TRUE,
                      values = c("Decid. Forest" = "#E69F00",  "Everg. Forest" = "#0072B2",   
                                 "Non-Vegetated" = "mistyrose3", "Shrubs, Herb. & Sparse Veg." = "#009E73")) +
    theme(text = element_text(size = 15),
          legend.text = element_text(size = 15),
          axis.text.x = element_text(size = 15, angle = 90, hjust = 1, vjust = 0.5),
          axis.text.y = element_text(size = 15),
          axis.title.x = element_text(vjust = 10),
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA)))

fpc$ecoregion = factor(fpc$ecoregion, levels = c("ALASKA BOREAL INTERIOR", "TAIGA CORDILLERA",
                                                  "TAIGA PLAIN", "TAIGA SHIELD", 
                                                   "BOREAL CORDILLERA", "BOREAL PLAIN"))

(p2 = ggplot() +
    theme_classic() +
    facet_wrap(~ecoregion, ncol = 2) +
    geom_bar(data = fpc[fpc$PFT != "Non-Vegetated" & fpc$ecoregion %in% c("ALASKA BOREAL INTERIOR", "BOREAL CORDILLERA",
                                                                          "TAIGA PLAIN", "TAIGA SHIELD", 
                                                                          "TAIGA CORDILLERA",  "BOREAL PLAIN") , ], 
             aes(x = age_bin, y = variable, fill = PFT), stat = "identity", position = "fill", alpha = 0.7, color = "black") +
    scale_x_discrete(name = "Year since disturbance", expand = c(0,0)) +
    scale_y_continuous(name = "", expand = c(0,0)) +
    scale_fill_manual(name = "Vegetation class", drop = TRUE,
                      values = c("Decid. Forest" = "#E69F00",  "Everg. Forest" = "#0072B2",   
                                 "Non-Vegetated" = "mistyrose3", "Shrubs, Herb. & Sparse Veg." = "#009E73")) +
    theme(text = element_text(size = 15),
          legend.text = element_text(size = 15),
          axis.text.x = element_text(size = 15, angle = 90, hjust = 1, vjust = 0.5),
          axis.text.y = element_text(size = 15),
          axis.title.x = element_text(vjust = 10),
          legend.position = "bottom",
          legend.direction = "horizontal",
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA)))


ggsave("trajectories_by_ecoregions.pdf", scale = 1)

legend = get_legend(p1)

cowplot::plot_grid(cowplot::plot_grid(p1 + theme(legend.position = "None"), 
                                      p2 + theme(legend.position = "None"),
                                      nrow = 1, labels = c("A", "B")), 
                   legend,
                   nrow = 2, rel_heights = c(1, .25))

ggsave("figures/ABoVE/fpc.png", width = 10, height = 7)

# Since the bare soil fraction is so high, the question is if we just simulate way to little vegetation. Let's therefore also look at aboveground carbon

cmass = read_csv("data/processed/trajectories_picontrol_2015_2040_cmass_200.csv") %>%
  right_join(above) %>% #crop to ABoVE domain via right join
  filter(!is.na(age)) %>% #filter for locations that are in ABoVE but not in model ouput
  filter(age != 0, age != 1) %>% #delete year of disturbance, no meaningful data
  group_by(Lon, Lat, age, PID) %>%
  filter(age < 61) %>% #filter to age range of paper
  group_by(age, PFT) %>% #make plot read, aggregate
  summarize(cmass = mean(cmass)) %>%
  bin_data_for_plot("cmass")

(p1 = ggplot() +
    theme_minimal() +
    geom_bar(data = cmass, aes(x = age_bin, y = variable, fill = PFT), stat = "identity", alpha = 0.7, color = "black") +
    scale_x_discrete(name = "Year since disturbance", expand = c(0,0)) +
    scale_y_continuous(name = "Aboveground carbon in kg/m²", expand = c(0,0)) +
    scale_fill_manual(name = "Vegetation class", drop = TRUE,
                      values = c("Decid. Forest" = "#E69F00",  "Everg. Forest" = "#0072B2",   
                                 "Non-Vegetated" = "mistyrose3", "Shrubs, Herb. & Sparse Veg." = "#009E73")) +
    theme(text = element_text(size = 15),
          legend.text = element_text(size = 15),
          axis.text.x = element_text(size = 15, angle = 90, hjust = 1, vjust = 0.5),
          axis.text.y = element_text(size = 15),
          axis.title.x = element_text(vjust = 10),
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA)))

(p2 = ggplot() +
    theme_minimal() +
    geom_bar(data = cmass, aes(x = age_bin, y = variable, fill = PFT), stat = "identity", position = "fill", alpha = 0.7, color = "black") +
    scale_x_discrete(name = "Year since disturbance", expand = c(0,0)) +
    scale_y_continuous(name = "Aboveground carbon rescaled", expand = c(0,0)) +
    scale_fill_manual(name = "Vegetation class", drop = TRUE,
                      values = c("Decid. Forest" = "#E69F00",  "Everg. Forest" = "#0072B2",   
                                 "Non-Vegetated" = "mistyrose3", "Shrubs, Herb. & Sparse Veg." = "#009E73")) +
    theme(text = element_text(size = 15),
          legend.text = element_text(size = 15),
          axis.text.x = element_text(size = 15, angle = 90, hjust = 1, vjust = 0.5),
          axis.text.y = element_text(size = 15),
          axis.title.x = element_text(vjust = 10),
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA)))


legend = get_legend(p1)

cowplot::plot_grid(cowplot::plot_grid(p1 + theme(legend.position = "None"), 
                                      p2 + theme(legend.position = "None"),
                                      nrow = 1, labels = c("A", "B")), 
                   legend,
                   nrow = 2, rel_heights = c(1, .25))

ggsave("figures/ABoVE/cmass.png", width = 10, height = 7)
