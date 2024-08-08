setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")


install.packages("scico")
install.packages("cowplot")

library(duckdb)
library(purrr)
library(scico)
library(terra)
library(sf)
library(cowplot)
library(tidyverse)
library(MASS)

con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
dbListTables(con)


##########
# plot dominance of BNE over time

scenario = "ssp585"
variable = "cmass"
end_year = 2100
start_year = 2015
pft = "BNE"


dominant_share_scenario = function(scenario, pft, data, variable, start_year, end_year) {
  
  number_patches = dbGetQuery(con, paste0("SELECT Lon, Lat, PID FROM '", scenario, "_d150_", variable, "' WHERE PFT = 'BNE' AND Year = 2100" )) %>%
    unique() %>%
    count() %>%
    as.integer()
  
  if (pft == "otherC") {
    
    variable_pft = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, ", variable, 
                                          " FROM '", scenario, "_d150_", variable, 
                                          "' WHERE PFT IN ('BINE', 'TeNE', 'BNS') AND Year BETWEEN ", start_year, " AND ", end_year)) %>%
      group_by(Year, Lon, Lat, PID) %>%
      summarize(across(everything(), sum))
    
  } else {
    
    variable_pft = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, ", variable, 
                                          " FROM '", scenario, "_d150_", variable, 
                                          "' WHERE PFT = '", pft, "' AND Year BETWEEN ", start_year, " AND ", end_year)) 
    
  }
    
  df = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, SUM(", variable, ") as Total 
                                          FROM '", scenario, "_d150_", variable, "' 
                                          WHERE Year BETWEEN ", start_year, " AND ", end_year, "GROUP BY Lon, Lat, PID, Year")) %>%
    full_join(variable_pft) %>%
    mutate(relative = !!rlang::sym(variable)/Total) %>%
    filter(relative > 0.5) %>%
    count(Year) %>%
    mutate(share_dominant = n/number_patches,
           PFT = pft)
  

  rm(variable_pft)
  gc()
  
  X = df$share_dominant[1]
  
    df = df %>%
      mutate(scenario = scenario,
           delta = share_dominant- X)
  
  data = append(data, list(df))
  
  print(paste0(scenario, " done!"))
  
  return(data)
}

dominant_share_data = function(variable, pft, start_year, end_year) {
  
  data = list()
  data = dominant_share_scenario("ssp585", pft, data, variable, start_year, end_year)
  data = dominant_share_scenario("ssp126", pft, data, variable, start_year, end_year)
  data = dominant_share_scenario("picontrol", pft, data, variable, start_year, end_year)
  
  df = purrr::reduce(data, bind_rows) %>%
    mutate(scenario =  sub("_(.*)", "", long_names_scenarios_twolines(scenario)),
           delta = delta*100)
  
  write_csv(df, paste0("data/processed/P1.A_", variable, "_", pft, "_", start_year, "_", end_year, ".csv"))
  
}

dominant_share_plot = function(variable, pft, start_year, end_year) {
  
  if (file.exists(paste0("data/processed/P1.A_", variable, "_", pft, "_", start_year, "_", end_year, ".csv"))) {
    print("Loading data")
    df = read_csv(paste0("data/processed/P1.A_", variable, "_", pft, "_", start_year, "_", end_year, ".csv"), show_col_types = F)
  } else {
    print("Creating data")
    df = dominant_share_data(variable, pft, start_year, end_year)
  }
  
  df = df %>%
    mutate(PFT = long_names_pfts_species(tolower(PFT)))
  
  df_control = df %>%
    filter(scenario == "Control")
  
  df_ribbon = df %>%
    filter(scenario %in% c("SSP5-\nRCP8.5", "SSP1-\nRCP2.6")) %>%
    dplyr::select(Year, scenario, delta, PFT) %>%
    pivot_wider(names_from = scenario, values_from = delta)
  
  (p = ggplot() + 
      geom_hline(yintercept = 0) +
      geom_ribbon(data = df_ribbon, aes(x = Year, ymin = `SSP1-\nRCP2.6`, ymax = `SSP5-\nRCP8.5`, fill = PFT), alpha = .75) +
      geom_line(data = df, aes(x = Year, y = delta, group = scenario, linetype = scenario, color = PFT), color = "black", linewidth = 1) +
      scale_x_continuous(name = "Time in years", expand = c(0,0)) +
      scale_y_continuous(name = bquote(Delta ~.(pft) ~ "-dominated patches in %"), breaks = c(-15, -10, -5, 0, 5, 10, 15), expand = c(0,0)) +
      scale_linetype_manual(name = "Scenario", values = c("Control" = "solid", "SSP1-\nRCP2.6" = "dashed", "SSP5-\nRCP8.5" = "dotdash")) +
      scale_fill_manual(name = "Vegetation type", drop = TRUE,
                         values = c("Temperate broadleaf \n(Maple, Beech)" = "#D55E00", "Pioneering broadleaf \n(Birch, Aspen)" = "#E69F00",  "Needleleaf evergreen \n(Spruce)" = "#0072B2",   
                                    "Conifers (other) \n(Pine, Larch)" = "#56B4E9", "Tundra \n(Shrubs, Grasses)" = "#009E73")) +
      add_common_layout(fontsize = 15) + 
      theme(text = element_text(size = 15),
            legend.direction = "horizontal",
            legend.position = "bottom") +
      guides(fill="none"))
  
  return(p)
}

###
### dominant pft

share_scenario = function(variable, scenario, year, data) {
  
  df = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM '", scenario, "_d150_", variable, "' WHERE Year = ", year)) %>%
    group_by(Lon, Lat, PID) %>%
    mutate(PFT = case_when(PFT == "BNS" ~ "otherC",
                           PFT == "TeNE" ~ "otherC",
                           PFT == "BINE" ~ "otherC",
                           TRUE ~ PFT )) %>% 
    group_by(PFT) %>%
    summarize(!!rlang::sym(variable) := sum(!!rlang::sym(variable))) %>%
    mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable))) %>%
    mutate(scenario = scenario)
  
  data = append(data, list(df))
  
  return(data)
}

share_data = function(variable, scenario, year){
  data = list()
  data = share_scenario(variable, "ssp585", year, data)
  data = share_scenario(variable, "ssp126", year, data)
  data = share_scenario(variable, "picontrol", year, data)
  
  df = purrr::reduce(data, bind_rows)
  
  write_csv(df, paste0("data/processed/P1.B_", variable, "_", year, "_share.csv"))
} 

share_plot = function(variable, scenario, year) {
  
  if (file.exists(paste0("data/processed/P1.B_", variable, "_", year, "_share.csv"))) {
    print("Loading data")
    df = read_csv(paste0("data/processed/P1.B_", variable, "_", year, "_share.csv"), show_col_types = F)
  } else {
    print("Creating data")
    df = share_data(variable, scenario, year)
  }
  
  df = df %>%
    mutate(pft = long_names_pfts_species(tolower(PFT)),
           scenario = long_names_scenarios_twolines(scenario)) 
  
  df$pft = factor(df$pft, levels = c("Tundra \n(Shrubs, Grasses)", "Temperate broadleaf \n(Maple, Beech)", 
                                     "Pioneering broadleaf \n(Birch, Aspen)", "Conifers (other) \n(Pine, Larch)", "Needleleaf evergreen \n(Spruce)"))
  
  (p = ggplot() + 
      geom_bar(data = df,  aes(x = scenario, y = relative,   fill = pft), color = "black", linewidth = .3, width = .25, stat = "identity", position = "fill") + 
      geom_area(data = df[df$scenario != "Control", ], aes(x = scenario , y = relative, fill = pft, group = pft), position = "fill", alpha = .25, color = "black", linewidth = .3) +
      scale_x_discrete(name = "Scenario") +
      scale_y_continuous(name = "Share of aboveground biomass", breaks = c(0, 0.5, 1), expand = c(0,0)) +
      scale_fill_manual(name = "Vegetation type", drop = TRUE,
                        values = c("Temperate broadleaf \n(Maple, Beech)" = "#D55E00", "Pioneering broadleaf \n(Birch, Aspen)" = "#E69F00",  
                                   "Needleleaf evergreen \n(Spruce)" = "#0072B2", 
                                   "Conifers (other) \n(Pine, Larch)" = "#56B4E9", "Tundra \n(Shrubs, Grasses)" = "#009E73")) +
      add_common_layout(fontsize = 15) +
      theme(legend.position = "bottom",
            legend.justification = "left",
            legend.margin = margin(l = -10),
            legend.direction = "horizontal") +
      guides(fill=guide_legend(nrow=2, title.position = "top", revers = T)))
  
  return(p)
}

### dominant pft

dominant_pfts_one_scenario = function(variable, scenario, year, data) {
  
  df = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM '", scenario, "_d150_", variable, "' WHERE Year = ", year)) %>%
    group_by(Lon, Lat, PID) %>%
    mutate(PFT = case_when(PFT == "BNS" ~ "otherC",
                           PFT == "TeNE" ~ "otherC",
                           PFT == "BINE" ~ "otherC",
                           TRUE ~ PFT )) %>% 
    group_by(PFT, Lon, Lat, PID, Year) %>%
    summarize(!!rlang::sym(variable) := sum(!!rlang::sym(variable))) %>%
    mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable))) %>%
    ungroup() %>%
    mutate(relative = replace_na(relative, 0)) %>%
    mutate(dominant_pft = case_when(relative >= 0.5 ~ PFT,
                                    TRUE ~ "Mixed")) %>%
    count(dominant_pft) %>%
    mutate(scenario = scenario)
  
  data = append(data, list(df))
  
  return(data)
}

dominant_pfts_data = function(variable, scenario, year, data){
  data = list()
  data = dominant_pfts_one_scenario(variable, "ssp585", year = 2100, data)
  data = dominant_pfts_one_scenario(variable, "ssp126", year = 2100, data)
  data = dominant_pfts_one_scenario(variable, "picontrol", year = 2100, data)
  
  df = purrr::reduce(data, bind_rows)
  
  write_csv(df, paste0("data/processed/P1.B_", variable, "_", year, ".csv"))
} 

dominant_pfts_plot = function(variable, scenario, year) {
  
  if (file.exists(paste0("data/processed/P1.B_", variable, "_", year, ".csv"))) {
    print("Loading data")
    df = read_csv(paste0("data/processed/P1.B_", variable, "_", year, ".csv"), show_col_types = F)
  } else {
    print("Creating data")
    df = dominant_pfts_data(variable, pft, start_year, end_year)
  }
  
  df = df %>%
    mutate(pft = long_names_pfts_species(tolower(dominant_pft)),
           scenario = long_names_scenarios_twolines(scenario)) %>%
    group_by(scenario) %>%
    mutate(relative = n/sum(n))
  
  df$pft = factor(df$pft, levels = c("Mixed", "Tundra \n(Shrubs, Grasses)", "Temperate broadleaf \n(Maple, Beech)", 
                                     "Pioneering broadleaf \n(Birch, Aspen)", "Conifers (other) \n(Pine, Larch)", "Needleleaf evergreen \n(Spruce)"))
  
  (p = ggplot() + 
    geom_bar(data = df,  aes(x = scenario, y = relative,   fill = pft), color = "black", linewidth = .3, width = .5, stat = "identity", position = "fill") + 
    geom_area(data = df[df$scenario != "Control", ], aes(x = scenario, y = relative, fill = pft, group = pft), position = "fill", alpha = .25, color = "black", linewidth = .3) +
    scale_x_discrete(name = "Scenario") +
    scale_y_continuous(name = "Dominant PFT in % of patches", breaks = c(0, 0.5, 1), expand = c(0,0)) +
    scale_fill_manual(name = "Vegetation type", drop = TRUE,
                      values = c("Temperate broadleaf \n(Maple, Beech)" = "#D55E00", "Pioneering broadleaf \n(Birch, Aspen)" = "#E69F00",  
                                 "Needleleaf evergreen \n(Spruce)" = "#0072B2", "Mixed" = "#CC79A7", 
                                 "Conifers (other) \n(Pine, Larch)" = "#56B4E9", "Tundra \n(Shrubs, Grasses)" = "#009E73")) +
    add_common_layout(15) +
    theme(legend.position = "bottom",
          legend.direction = "horizontal") +
    guides(fill=guide_legend(nrow=2, title.position = "top", revers = T)))
  
  return(p)
}


#######

get_2d_density <- function(x, y, ...) {
  dens <- MASS::kde2d(x, y, ...)
  ix <- findInterval(x, dens$x)
  iy <- findInterval(y, dens$y)
  ii <- cbind(ix, iy)
  return(dens$z[ii])
} #adapted from https://slowkow.com/notes/ggplot2-color-by-density/

create_one_scenario_density = function(var_climate, variable,  scenario, year, pft, data){
  
  df_climate = terra::rast(paste0("data/external/mri-esm2-0_r1i1p1f1_", scenario, "_", var_climate, "_", year, "_cropped.nc")) %>%
    terra::as.polygons(aggregate = F) %>%
    st_as_sf() %>%
    st_make_valid() %>%
    mutate(Lon = round(st_coordinates(st_centroid(geometry))[, "X"], 2),
           Lat = round(st_coordinates(st_centroid(geometry))[, "Y"], 2))
  
  if (pft == "otherC") {
    
    df_vegetation = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM '", scenario, "_d150_", variable, "' WHERE Year = ", year, "")) %>%
      group_by(Lon, Lat, PID) %>%
      mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable))) %>%
      filter(PFT %in%c("BINE", "TeNE", "BNS")) %>%
      group_by(PFT, Lon, Lat, PID, Year) %>%
      summarize(relative = sum(relative)) %>%
      mutate(relative = replace_na(relative, 0))
      
  } else {
    
    df_vegetation = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM '", scenario, "_d150_", variable, "' WHERE Year = ", year, "")) %>%
      group_by(Lon, Lat, PID) %>%
      mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable))) %>%
      filter(PFT == pft) %>%
      mutate(relative = replace_na(relative, 0))
    
  }
  
  print(head(df_vegetation))
  
  df = df_climate %>%
    dplyr::select(tas, Lon, Lat) %>%
    right_join(df_vegetation) %>%
    st_drop_geometry()
  
  bw_x <- max(sd(df$tas) * 0.1, 0.1)  # Set minimum bandwidth
  bw_y <- max(sd(df$relative) * 0.1, 0.1)  # Set minimum bandwidth
  
  # Kernel density estimation
  df$density = get_2d_density(df$tas, df$relative, n = 100, lims = c(range(df$tas), range(df$relative)), h = c(bw_x, bw_y))
  
  data = append(data, list(df))
  
  return(data)
}

density_2d_data = function(variable, scenario, pft) {
  data = list()
  
  data = create_one_scenario_density("tas", variable, scenario, 2015, pft, data) #todo look at 1850, climate data needs to be adapted for this
  data = create_one_scenario_density("tas", variable, scenario, 2050, pft, data)
  data = create_one_scenario_density("tas", variable, scenario, 2100, pft, data)
  
  print(data)
  
  df = purrr::reduce(data, bind_rows) %>%
    mutate(tas = tas - 273.15)
  
 write_csv(df, paste0("data/processed/P1.C_", variable, "_", pft, ".csv"))
  
  return(df)
}

density_2d_plot = function(variable, scenario, pft) {
  
  print(pft)
  
  if (file.exists(paste0("data/processed/P1.C_", variable, "_", pft, ".csv"))) {
    print("Loading data")
    df = read_csv(paste0("data/processed/P1.C_", variable, "_", pft, ".csv"), show_col_types = F)
  } else {
    print("Creating data")
    df = density_2d_data(variable, scenario, pft)
  }
  
  print(head(df))
  
  (p = ggplot(df, aes(x=tas, y=relative) ) + 
      geom_rect(aes(xmin = -Inf, xmax = Inf, ymin = .5, ymax = Inf), fill = "grey95") +
     geom_point(aes(color = density), stroke = 0, shape = 16, size = .5) +
     geom_hline(yintercept = 0.5, color = "grey40", linetype = "dotted") +
     facet_wrap(~Year, ncol = 1) +
     scale_x_continuous(name = "Mean annual temperature in °C", expand = c(0,0)) +
     scale_y_continuous(name = bquote(Share ~ "of" ~ .(pft) ~ "per patch" ~ chi[~.(pft)]), breaks = c(0, 0.5, 1), expand = c(0,0)) +
     scico::scale_color_scico(palette = "lipari", direction = -1, name = "Density", begin = .3) +
      add_common_layout(fontsize = 15) +
      theme(text = element_text(size = 15)) +
      annotate("text", x = 8, y = 0.55, label = "Dominance"))
}


(p1 = density_2d_plot("cmass", "ssp585", "BNE"))

(p2 = density_2d_plot("cmass", "ssp585", "IBS"))





create_figure_1 = function(variable, pft) {
  (p1 = share_plot(variable, pft, 2100))
  (p2 = dominant_share_plot(variable, pft, 2015, 2100)) 
  (p3 = density_2d_plot(variable, "ssp585", pft))
  
  (p = plot_grid(plot_grid(p1, p2, 
                           nrow = 2,  rel_heights = c(1, .8),
                           labels = c("A", "B")),
                 p3, rel_widths = c(1.1, 1),
                 nrow = 1,
                 labels = c("", "C")))
  
  
  ggsave(paste0("figures/figure1_", variable, "_", pft, ".png"), width = 12, height = 10.25)
  
  return(p)
}

create_figure_1("cmass", "BNE")
create_figure_1("cmass", "IBS")
create_figure_1("cmass", "TeBS")
create_figure_1("cmass", "Tundra")
create_figure_1("cmass", "otherC")



#####

plot_density = function(variable, pft) {
  
  if (pft == "otherC") {
    
    df_vegetation = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM '", scenario, "_d150_", variable, "' WHERE Year = ", year, "")) %>%
      group_by(Lon, Lat, PID) %>%
      mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable))) %>%
      filter(PFT %in%c("BINE", "TeNE", "BNS")) %>%
      group_by(PFT, Lon, Lat, PID, Year) %>%
      summarize(relative = sum(relative))
    
  } else {
    
    df_vegetation = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM '", scenario, "_d150_", variable, "' WHERE Year = ", year, "")) %>%
      group_by(Lon, Lat, PID) %>%
      mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable))) %>%
      filter(PFT == pft) 
    
  }
  
  h = hist(df$relative, breaks = 21, plot = F)
  
  df_h = data.frame(x = h$mids,
                    y = h$counts/sum(h$counts))
  
  data = list()
  
  for (year in c(2015, 2050, 2100)) {
    
    if (pft == "otherC") {
      
      df_vegetation = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM '", scenario, "_d150_", variable, "' WHERE Year = ", year, "")) %>%
        group_by(Lon, Lat, PID) %>%
        mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable))) %>%
        filter(PFT %in%c("BINE", "TeNE", "BNS")) %>%
        group_by(PFT, Lon, Lat, PID, Year) %>%
        summarize(relative = sum(relative))
      
    } else {
      
      df_vegetation = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM '", scenario, "_d150_", variable, "' WHERE Year = ", year, "")) %>%
        group_by(Lon, Lat, PID) %>%
        mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable))) %>%
        filter(PFT == pft) 
      
    }
    
    h = hist(df$relative, breaks = 21, plot = F)
    
    df_p = data.frame(x = h$mids,
                      y = h$counts/sum(h$counts),
                      Year = as.character(year)) 
    
    data = append(data, list(df_p))
    
  }
  
  df = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM 'ssp585_d150_", variable, "' WHERE Year = 1850")) %>%
    group_by(Lon, Lat, PID) %>%
    mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable))) %>%
    filter(PFT == pft)
  
  h = hist(df$relative, breaks = 21, plot = F)
  
  df_p = data.frame(x = h$mids,
                    y = h$counts/sum(h$counts),
                    Year = as.character(1850)) 
  
  data = append(data, list(df_p))
  
  df_p = purrr::reduce(data, bind_rows)
  
  (p = ggplot() + theme_bw() +  
      geom_bar(data = df_h, aes(x = x, y = y, fill = x), stat = "identity", color = "grey20", alpha = .6) +
      geom_line(data = df_p, aes(x = x, y = y, linetype = Year), stat = "identity", color = "black") +
      geom_point(data = df_p, aes(x = x, y = y, shape = Year), stat = "identity", color = "black", size = 2) +
      scale_x_continuous(name = bquote(Share ~ "of" ~ .(pft) ~ "per patch" ~ chi[~.(pft)]), breaks = c(0, 0.5, 1)) +
      scale_y_continuous(name = "Relative frequency", breaks = c(0, 0.15, .3)) +
      scico::scale_fill_scico(palette= "vik", direction = -1, name = "") +
      scale_shape_manual(values = c(1, 2, 3, 4)) +
      theme(text = element_text(size = 15),
            legend.position = "bottom",
            legend.direction = "horizontal") +
      guides(fill = FALSE))
  
  return(p)
}


