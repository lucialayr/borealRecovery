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



scenario = "ssp126"
variable = "cmass"



con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
dbListTables(con)





#these were created by manually looking at subsets of the data and finding trajectories that were able to fully recover twice in a row (pretty rare in this setting ..)
#see bottom of the script

long_transients = data.frame(Lon = c(-149.25, -157.25, -156.75, -147.75, -148.75, -149.75, -146.25, -147.75, -148.75, -149.75, -142.25, -141.75),
                             Lat = c(64.75, 66.75, 66.25, 64.75, 64.75, 64.25, 66.75, 66.25, 65.25, 64.25, 67.25, 67.25),
                             PID = c(1, 1, 2, 3, 4, 7, 10, 11, 12, 15, 16, 16)) %>%
  unique()

dbWriteTable(con, "long_transient_ssp126", long_transients, overwrite = T)

df_ts_transient = dbGetQuery(con, paste0("SELECT d.Year, d.Lon, d.Lat, d.PID, d.PFT, d.age, d.cmass, d.ndist FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN long_transient_ssp126 AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat")) %>%
  group_by(Year, Lon, Lat, PID) %>%
  mutate(relative = cmass/sum(cmass))  %>% 
  ungroup() %>%
  filter(PFT == "BNE") %>%
  mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>% #if sum(cmass) = 0, this will be NA (can happen in the first years after a disturbance)
  unique() %>%
  mutate(id = paste0(Lon, Lat, PID))


ggplot() + theme_classic() +
  geom_line(data = df_ts_transient, aes(x = Year, y = relative, color = id)) +
  scico::scale_color_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer recovery \n(transient < 10 years)", direction = -1) +
  facet_wrap(Lon ~ Lat)

long_transients_pretty = data.frame(Lon = c(-156.75, -142.25, -141.75),
                                    Lat = c(66.25, 67.25, 67.25)) %>%
  inner_join(df_ts_transient)

(p1 = ggplot() + theme_classic() +
  geom_line(data = long_transients_pretty, aes(x = Year, y = relative, color = as.factor(Lon), linetype = as.factor(Lon)), size = 1.5, alpha = .9) +
  scico::scale_color_scico_d(palette = "lapaz",  begin = .1, end = .5, name = "Direct conifer recovery \n(transient < 10 years)", direction = -1) +
  scale_x_continuous(limits = c(1800, 2175), expand = c(0,0), name = "Simulation year") +
  scale_y_continuous(limits = c(-0.01, 1), breaks = c(0, 0.5, 1), expand = c(0,0), name = "Relative share AGC") +
    scale_linetype_manual(values = c("-141.75" = "longdash", "-142.25" = "solid", "-156.75" = "dashed")) +
  theme(axis.text = element_text(size = 15),
        axis.title =  element_text(size = 15),
        legend.background = element_rect(fill='transparent', color = NA),
        legend.box.background = element_rect(fill='transparent', color = NA),
        panel.background = element_rect(fill = "transparent", colour = NA),  
        plot.background = element_rect(fill = "transparent", colour = NA),
        strip.background = element_rect(fill = "transparent", color = NA),
        legend.position = "None",
        legend.direction = "vertical",
        legend.text = element_text(size = 13),
        legend.title = element_text(size = 15)))


(p2 = ggplot() + theme_classic() +
    coord_flip() +
    geom_histogram(data = long_transients_pretty, aes(x = relative), color = "black", fill = "#0072B2",  bins = 20) +
    scale_x_continuous(limits = c(-0.01, 1), expand = c(0,0), name = "", breaks = c(0, 0.5, 1)) +
    scale_y_continuous(expand = c(0,0), name = "Frequency", breaks = c(300)) +
    theme(axis.text = element_text(size = 15),
          axis.title =  element_text(size = 15),
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA),
          legend.position = "None",
          legend.direction = "vertical",
          legend.text = element_text(size = 13),
          legend.title = element_text(size = 15))) 




#####
#select a subset of the data to plot against temperature
year = 2015
scenario = "ssp126"
variable = "cmass"

get_2d_density <- function(x, y, ...) {
  dens <- MASS::kde2d(x, y, ...)
  ix <- findInterval(x, dens$x)
  iy <- findInterval(y, dens$y)
  ii <- cbind(ix, iy)
  return(dens$z[ii])
} #adapted from https://slowkow.com/notes/ggplot2-color-by-density/




df_2d_density = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, age, cmass, ndist FROM '", scenario, "_d150_cmass' 
                                 WHERE Year = ", year, " AND Lon < -100 AND Lon > -140 AND Lat > 50 AND Lat < 70")) %>%
  group_by(Year, Lon, Lat, PID) %>%
  mutate(relative = cmass/sum(cmass))  %>% 
  ungroup() %>%
  filter(PFT == "BNE") %>%
  mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>% #if sum(cmass) = 0, this will be NA (can happen in the first years after a disturbance)
  unique()

df_climate = terra::rast(paste0("data/external/mri-esm2-0_r1i1p1f1_", scenario, "_tas_", year, "_cropped.nc")) %>%
  terra::as.polygons(aggregate = F) %>%
  st_as_sf() %>%
  st_make_valid() %>%
  mutate(Lon = round(st_coordinates(st_centroid(geometry))[, "X"], 2),
         Lat = round(st_coordinates(st_centroid(geometry))[, "Y"], 2))


df = df_climate %>%
  dplyr::select(tas, Lon, Lat) %>%
  right_join(df_2d_density) %>%
  st_drop_geometry()


write_csv(df, "/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/transient_alphastable/data/processed/lpjguess_2d.csv")


bw_x <- max(sd(df$tas) * 0.5, 0.5)  # Set minimum bandwidth
bw_y <- max(sd(df$relative) * 0.5, 0.5)  # Set minimum bandwidth

# Kernel density estimation
df$density = get_2d_density(df$tas, df$relative, n = 100, lims = c(range(df$tas), range(df$relative)), h = c(bw_x, bw_y))

(p3 = ggplot() + theme_classic() +
  geom_point(data = df, aes(x = tas, y = relative, color = density), size = .5) +
  scale_color_scico(palette = "lipari", direction = 1, name = "Relative density") +
  scale_x_continuous(limits = c(265.5, 272), expand = c(0,0), breaks = c(266, 268, 270, 272), labels = c(266 - 273, 268 - 273, 270 - 273, 272 - 273) ,
                     name = "Mean annual temperature in °C") +
  scale_y_continuous(expand = c(0,0), breaks = c(0, 0.5, 1), name = "Relative share AGC") +
  theme(axis.text = element_text(size = 15),
        axis.title =  element_text(size = 15),
        legend.background = element_rect(fill='transparent', color = NA),
        legend.box.background = element_rect(fill='transparent', color = NA),
        panel.background = element_rect(fill = "transparent", colour = NA),  
        plot.background = element_rect(fill = "transparent", colour = NA),
        strip.background = element_rect(fill = "transparent", color = NA),
        legend.position = "bottom",
        axis.text.x = element_text(hjust = 1),
        legend.direction = "horizontal",
        legend.text = element_text(size = 13),
        legend.title = element_text(size = 15)))


plot_grid(p3,
          plot_grid(p1, p2, nrow = 1, align = "hv", axis = "l", rel_widths = c(1, 0.5), labels = c("", "(c)"), hjust = .05),
          nrow = 2,  labels = c("(a)", "(b)"), hjust = .05, rel_heights = c(1, 0.9))


ggsave("figures/results/lpj_transients_bistable.pdf")



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
    
    df_vegetation = dbGetQuery(con, paste0("SELECT Year, Lon, Lat, PID, PFT, ", variable, " FROM '", scenario, "_d150_", variable, "' WHERE Year = ", year, 
    " AND Lon < -100 AND Lat > 60 AND Lat < 70")) %>%
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
  
  bw_x <- max(sd(df$tas) * 0.5, 0.5)  # Set minimum bandwidth
  bw_y <- max(sd(df$relative) * 0.5, 0.5)  # Set minimum bandwidth
  
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
  
  if (file.exists(paste0("data/processed/density_", variable, "_", pft, ".csv"))) {
    print("Loading data")
    df = read_csv(paste0("data/processed/density_", variable, "_", pft, ".csv"), show_col_types = F)
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

density_2d_plot("cmass", "ssp126", "BNE")


##################
##################
###looking for long transients
fully_recovered = dbGetQuery(con, paste0("SELECT Lon, Lat, PID FROM '", scenario, "_d150_", variable, "' WHERE age = 300 AND Year > 2100" )) %>%
  unique() 

dbWriteTable(con, "fully_recovered", fully_recovered, overwrite = T)

df_cmass = dbGetQuery(con, paste0("SELECT d.Year, d.PFT, d.PID, d.Lon, d.Lat, d.cmass, d.age FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN fully_recovered AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat"))

df_cmass_test = df_cmass %>%
  filter(PID == 16 & Lon < -140 & Lon > -160) %>%
  group_by(Year, Lon, Lat, PID) %>%
  mutate(relative = cmass/sum(cmass))  %>% 
  ungroup() %>%
  filter(PFT == "BNE") %>%
  mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>% #if sum(cmass) = 0, this will be NA (can happen in the first years after a disturbance)
  unique()


ggplot() + theme_classic() +
  geom_line(data = df_cmass_test, aes(x = Year, y = relative, group = interaction(Lon, Lat, PID))) +
  geom_point(data = df_cmass_test[df_cmass_test$age > 300,], aes(x = Year, y = relative), color = "red", shape = 4) +
  scale_x_continuous(breaks = c(1900, 2100)) +
  facet_wrap(Lon ~ Lat)






hist(df_cmass[df_cmass$Lon < -140 & df_cmass$Lon > -160 & df_cmass$PFT == "BNE" & df_cmass$Year == 2100,]$cmass)


df_cmass_subset = df_cmass %>%
  filter(Lon < -140 & Lon > -160 & Lat > 64 & Lat < 67) %>%
  group_by(Year, Lon, Lat, PID) %>%
  mutate(relative = cmass/sum(cmass))  %>% 
  ungroup() %>%
  filter(PFT == "BNE") %>%
  mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>% #if sum(cmass) = 0, this will be NA (can happen in the first years after a disturbance)
  unique()

hist(df_cmass_subset$relative, breaks = 30)



