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
###############################
#niche
###############################

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

plot_ibs_both = function() {
  
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
  
  
  load_basemap()
  #color are obtained from 
  #scico::scale_fill_scico_d(name = "Realized niche per scenario", palette = "lajolla", begin = .2, end = .8, direction = -1) +
  
  (p1 = ggplot() + 
      add_basemap() +
      geom_sf(data = polygons_to_plot, aes(fill = scenario), color = NA, linewidth = 0.0, alpha = 1) +
      #geom_sf(data = df_picontrol, aes(color = "Theoretical niche of pioneering broadleaf trees"), linewidth = 0.3, alpha = 0) +
      scale_x_continuous(expand = c(0,0)) +
      scale_y_continuous(expand = c(0,0)) +
      #scale_color_manual(name = "", drop = TRUE,
      #                   values = c("Theoretical niche of pioneering broadleaf trees" = "black"))+
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

(p1 = plot_ibs_both())

###############################
#trajectories
###############################

trajectories_100years = function(start_year, end_year) {
  
  data = list()
  
  data_carbon = list()
  
  for (s in c("picontrol", "ssp126", "ssp585")) {
    df_timeseries = read_csv(paste0("data/processed/trajectories_", s, "_", start_year, "_", end_year, "_timeseries_rf.csv" )) %>%
      mutate(s = s)
    
    data = append(data, list(df_timeseries))
    
    df_carbon = read_csv(paste0("data/processed/trajectories_", s, "_", start_year, "_", end_year, "_total_carbon.csv" )) %>%
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

  
  write_csv(df_mean, paste0("data/results/mean_trajectories_", start_year, "_", end_year, ".csv"))
  write_csv(df_cmass_mean, paste0("data/results/mean_recovery_cmass_", start_year, "_", end_year, ".csv"))
  write_csv(df_cmass_mean_class, paste0("data/results/mean_recovery_cmass_class_", start_year, "_", end_year, ".csv"))
  
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

end_year = 2040
start_year = 2015

p2 = trajectories_100years(start_year = start_year, end_year = end_year)

legend = get_legend(p2)

line_grob = linesGrob(y = unit(c(0.5, 0.5), "npc"), gp = gpar(col = "black", lwd = 0.5))

(p = plot_grid(p2 + theme(legend.position = "None"), 
               plot_grid(p1 + theme(legend.margin=margin(0,0,0,0),
                                    legend.box.margin=margin(-10,-10,-10,-10)), 
                         line_grob, legend, rel_heights = c(0.66, 0.05, 0.3), ncol = 1),
               ncol = 2, rel_widths = c(1, 1), labels = c( "(a)", "(b)"), hjust = 0))

ggsave("figures/results/niche_trajectories_2015_2040.pdf", width = 10, height = 7.75, scale = 1) 

######

start_year = 2075
end_year = 2100

p2 = trajectories_100years(start_year = start_year, end_year = end_year)

(p = plot_grid(p2 + theme(legend.position = "None"), 
               plot_grid(p1 + theme(legend.margin=margin(0,0,0,0),
                                    legend.box.margin=margin(-10,-10,-10,-10)), 
                         line_grob, legend, rel_heights = c(0.66, 0.05, 0.3), ncol = 1),
               ncol = 2, rel_widths = c(1, 1), labels = c( "(a)", "(b)"), hjust = 0))

ggsave("figures/results/niche_trajectories_2075_2100.pdf", width = 10, height = 7.75, scale = 1)

###############################
###############################
###############################
plot_theoretical_niche = function() {
  
  df_picontrol = get_single_pfts_scenario("picontrol")
  df_ssp126 = get_single_pfts_scenario("ssp126")
  df_ssp585 = get_single_pfts_scenario("ssp585")
  
  df = purrr::reduce(list(df_picontrol, df_ssp126, df_ssp585), bind_rows)
  
  df$pft = factor(df$pft, levels = c("Needleleaf evergreen",  "Pioneering broadleaf", "Temperate broadleaf", "Conifers (other)", "Tundra"))
  
  outline = st_read("data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp") %>%
    st_make_valid() %>%
    st_union() %>%
    st_geometry()
  
  fontsize = 15
  
  (p = ggplot() + theme_bw() +
      geom_sf(data = outline, color = "grey", fill = "grey") +
      geom_sf(data = df, aes(fill = pft, linetype = scenario), color = "black", alpha = .33) +
      scale_x_continuous(expand = c(0,0)) +
      scale_y_continuous(expand = c(0,0)) +
      facet_wrap(~pft, ncol = 1) +
      theme(axis.title = element_text(size = fontsize),
            legend.background = element_rect(fill='transparent', color = NA),
            legend.box.background = element_rect(fill='transparent', color = NA),
            panel.background = element_rect(fill = "transparent", colour = NA),  
            plot.background = element_rect(fill = "transparent", colour = NA),
            strip.background = element_rect(fill = "transparent", color = NA),
            strip.text = element_text(size = fontsize),
            text = element_text(size = fontsize)) +
      scale_color_manual(name = "Dominant vegetation", drop = TRUE,
                         values = c("Temperate broadleaf" = "#D55E00", "Pioneering broadleaf" = "#E69F00",  "Needleleaf evergreen" = "#0072B2",   
                                    "Conifers (other)" = "#56B4E9", "Tundra" = "#009E73")) +
      scale_fill_manual(name = "Dominant vegetation", drop = TRUE,
                        values = c("Temperate broadleaf" = "#D55E00", "Pioneering broadleaf" = "#E69F00",  "Needleleaf evergreen" = "#0072B2",   
                                   "Conifers (other)" = "#56B4E9", "Tundra" = "#009E73")) + 
      scale_linetype_manual(name = "Scenario", values = c("Control" = "solid", "SSP1-RCP2.6" = "dashed", "SSP5-RCP8.5" = "dotted")) + 
      guides(fill = guide_legend(override.aes = list(alpha = 1))))
  
  
  ggsave("figures/theoretical_niche.png", width = 13, height = 10)
  
}

plot_theoretical_niche()

##actual niche

realized_niche = function() {
  
  data = list()
  
  for (s in c("picontrol", "ssp126", "ssp585")) {
    for (p in c("IBS", "BNE")) {
      
      df = read.table(paste0("data/", s, "_d150/cmass.out"), header = T) %>%
        filter(Year == 2100) %>%
        select(all_of(c("Lon", "Lat", p, "Total"))) %>%
        mutate(relative = !!rlang::sym(p)/ Total) %>%
        filter(relative > 0.05) %>%
        terra::rast(crs = "EPSG:4326") %>% # convert to  raster
        as.polygons(dissolve = F, aggregate = T) %>% # convert to shapefile 
        st_as_sf() %>%
        mutate(pft = p) %>%
        select(p) %>%
        st_union() %>%
        st_sf() %>%
        mutate(pft = long_names_pfts(tolower(p)),
               scenario = long_names_scenarios(s))
      
      head(df)
      
      data = append(data, list(df))
    }
  }
  
  df = purrr::reduce(data, bind_rows) 
  
  outline = st_read("data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp") %>%
    st_make_valid() %>%
    st_union() %>%
    st_geometry()
  
  df$scenario = factor(df$scenario, c("Control", "SSP1-RCP2.6", "SSP5-RCP8.5"))
  
  df = df %>% arrange(desc(scenario))
  
  fontsize = 15
  
  (p = ggplot() + theme_bw() +
      geom_sf(data = outline, color = "grey", fill = "grey") +
      geom_sf(data = df, aes(fill = pft, linetype = scenario), color = "black", alpha = .33) +
      scale_x_continuous(expand = c(0,0)) +
      scale_y_continuous(expand = c(0,0)) +
      facet_wrap(~pft, ncol = 1) +
      scale_color_manual(name = "Dominant vegetation", drop = TRUE,
                         values = c("Temperate broadleaf" = "#D55E00", "Pioneering broadleaf" = "#E69F00",  "Needleleaf evergreen" = "#0072B2",   
                                    "Conifers (other)" = "#56B4E9", "Tundra" = "#009E73")) +
      scale_fill_manual(name = "Dominant vegetation", drop = TRUE,
                        values = c("Temperate broadleaf" = "#D55E00", "Pioneering broadleaf" = "#E69F00",  "Needleleaf evergreen" = "#0072B2",   
                                   "Conifers (other)" = "#56B4E9", "Tundra" = "#009E73")) + 
      scale_linetype_manual(name = "Scenario", values = c("Control" = "solid", "SSP1-RCP2.6" = "dashed", "SSP5-RCP8.5" = "dotted")) + 
      theme(axis.title = element_text(size = fontsize),
            legend.background = element_rect(fill='transparent', color = NA),
            legend.box.background = element_rect(fill='transparent', color = NA),
            panel.background = element_rect(fill = "transparent", colour = NA),  
            plot.background = element_rect(fill = "transparent", colour = NA),
            strip.background = element_rect(fill = "transparent", color = NA),
            strip.text = element_text(size = fontsize),
            text = element_text(size = fontsize)) +
      guides(fill = guide_legend(override.aes = list(alpha = 1))))
  
  ggsave("figures/realized_niche.png", width = 13.5, height = 5)
}

realized_niche()





  


