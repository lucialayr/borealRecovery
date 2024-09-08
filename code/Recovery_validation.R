setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(dplyr)
library(terra)
library(sf)

install.packages("cowplot")
install.packages("rnaturalearth")
install.packages("rnaturalearthdata")
install.packages("scico")
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

##

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
  labels = c("pre-\ndisturbance", "02-05", "06-09", "10-19", "20-29", "30-39", "40-49", "50-59")
  
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
  dplyr::select(NA_L2NAME)

lpjguess_grid = read_table("data/picontrol_d150/cmass.out", show_col_types = F) %>%
  filter(Year == 2000) %>%
  dplyr::select(Lon, Lat, Total) %>%
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
  dplyr::select(-geometry, -Total) %>%
  distinct(Lon, Lat, .keep_all = TRUE) #keep only first ecoregion (not ideal but only thing that works for now)

# save because we need those for Chapter 3
st_write(lpjguess_grid, "data/processed/above_ecoregion_lpjguess_grid.shp", delete_dsn = T)
write_csv(lpjguess_ecoregion, "data/processed/above_ecoregion_lpjguess_grid.csv")


### Study region and ecoregions

lpjguess_ecoregion_shp = lpjguess_grid %>%
  dplyr::select(NA_L2NAME) %>%
  rename(ecoregion = NA_L2NAME) %>%
  filter(ecoregion %in% c("ALASKA BOREAL INTERIOR", "TAIGA CORDILLERA",
                          "TAIGA PLAIN", "TAIGA SHIELD", 
                          "BOREAL CORDILLERA", "BOREAL PLAIN")) %>%
  mutate(ecoregion = str_to_title(ecoregion)) %>%
  group_by(ecoregion) %>%
  summarize(geometry = st_union(geometry)) %>%
  ungroup() %>%
  sf::st_transform(crs = 3408)

study_region = st_read("data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp") %>%
  st_make_valid() %>%
  st_union() %>%
  st_geometry() %>%
  st_transform(., crs = 3408) 

load_basemap()

lpjguess_ecoregion_shp$ecoregion = factor(lpjguess_ecoregion_shp$ecoregion, levels = str_to_title(c("ALASKA BOREAL INTERIOR", "TAIGA CORDILLERA",
                                                            "TAIGA PLAIN", "TAIGA SHIELD", 
                                                            "BOREAL CORDILLERA", "BOREAL PLAIN")))

(p1 = ggplot() + 
    add_basemap() +
    geom_sf(data = study_region, fill = "grey", alpha = 1) +
    geom_sf(data = lpjguess_ecoregion_shp, aes(fill = ecoregion)) +
    scale_fill_scico_d(name = "Ecoregions", palette = "navia", begin = .1, direction = 1) +
    scale_x_continuous(expand = c(0,0), limits = c(-4517639, 0)) +
    scale_y_continuous(expand = c(0,0), limits = c(-1000000, 3368793)) +
    theme(legend.position = "bottom",
          legend.direction = "horizontal",
          legend.title.position = "top") +
    guides(fill = guide_legend(ncol = 2, byrow = T)))


### data

##lpjguess
fpc_lpjguess = read_csv("data/processed/trajectories_picontrol_2015_2040_fpc_200.csv")  %>%
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
  bin_data_for_plot("fpc") %>%
  filter(PFT != "Non-Vegetated",
         ecoregion %in% c("ALASKA BOREAL INTERIOR", "TAIGA CORDILLERA",
                          "TAIGA PLAIN", "TAIGA SHIELD", 
                          "BOREAL CORDILLERA", "BOREAL PLAIN")) %>%
  group_by(ecoregion, age_bin) %>%
  mutate(value = variable/sum(variable),
         dataset = "LPJ-GUESS") %>%
  dplyr::select(PFT, age_bin, ecoregion, value, dataset)
  

fpc_observations = read_csv("data/external/ecoreg_lctraj2.csv") %>%
  mutate(Shrubs = Shrubs + Herb_Sparse,
         Wetlands = Wetlands + Barren) %>%
  dplyr::select(-Herb_Sparse, -Barren) %>%
  rename(ecoregion = index_ecoreg,
         age_bin = stand_bins,
         "Everg. Forest" = ENFW,
         "Decid. Forest" = DBFM,
         "Shrubs, Herb. & Sparse Veg." = Shrubs,
         "Non-Vegetated" = Wetlands) %>%
  pivot_longer(cols = c("Everg. Forest", "Decid. Forest", "Shrubs, Herb. & Sparse Veg.", "Non-Vegetated"), names_to = "PFT", values_to = "Cover") %>%
  filter(PFT != "Non-Vegetated",
         age_bin %in% c("02-05", "06-09", "10-19", "20-29", "30-39", "40-49", "50-59", "pre-fire")) %>%
  group_by(ecoregion, age_bin) %>%
  mutate(value = Cover/sum(Cover),
         dataset = "Observations",
         age_bin = case_when(age_bin == "pre-fire" ~ "pre-\ndisturbance",
                             TRUE ~ age_bin))  %>%
  dplyr::select(PFT, age_bin, ecoregion, value, dataset)

df = bind_rows(fpc_lpjguess, fpc_observations) %>%
  filter(age_bin != "pre-\ndisturbance") %>%
  mutate(ecoregion = str_to_title(ecoregion))

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

legend = get_legend(p2)

plot_grid(p1, p2, labels = c("(a)", "(b)"), rel_widths = c(0.7, 1), align = "hv", axis = "b")


ggsave("figures/results/recovery_validation.pdf", height = 8,  scale = 0.85)

