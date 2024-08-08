setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(duckdb)
library(tidyverse)

install.packages("cowplot")
install.packages("scico")
library(cowplot)
library(scico)

end_year = 2040
start_year = 2015

con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
dbListTables(con)


get_one_scenario = function(scenario, end_year, start_year) {
  
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, Year, ndist FROM '", scenario, "_d150_cmass' WHERE Year BETWEEN ", start_year, " AND ", 
                                               end_year, " AND dhist = 1 AND PFT = 'BNE';")) %>% unique()
  
  df_class1 = read_csv(paste0("data/results/all_binary_data_", start_year, "_", end_year,".csv")) %>%
    filter(class == 1, s == long_names_scenarios(scenario)) %>%
    select(Lon, Lat, PID) %>%
    inner_join(locations_disturbed) %>%
    rename(year_disturbance = Year)
  
  
  dbWriteTable(con, "locations_disturbed_class1", df_class1, overwrite = T)
  
  df_cmass = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance,  d.PFT, d.PID, d.Lon, d.Lat, d.cmass, d.age FROM '", scenario, "_d150_cmass' 
                                AS d INNER JOIN locations_disturbed_class1 AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat WHERE d.Year >= ", 
                                    start_year, " AND d.Year >= l.year_disturbance AND d.ndist = l.ndist")) %>%
    group_by(age, Lon, Lat, PID) %>%
    mutate(relative = cmass/sum(cmass))  %>% 
    ungroup() %>%
    mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>% #if sum(cmass) = 0, this will be NA (can happen in the first years after a disturbance)
    unique()
  
  df = df_cmass %>%
    mutate(PFT = case_when(PFT == "BINE" ~ "otherC",
                           PFT == "TeNE" ~ "otherC",
                           PFT == "BNS" ~ "otherC",
                           TRUE ~ PFT)) %>%
    group_by(PFT, Lon, Lat, PID, age) %>%
    summarize(relative = sum(relative)) %>%
    mutate(PFT = long_names_pfts(tolower(PFT)),
           s = scenario)
  
  return(df)
  
}

data = list()

for (s in c("picontrol", "ssp126", "ssp585")) {
  df = get_one_scenario(s, start_year = start_year, end_year = end_year)
  
  data = append(data, list(df))
  
}

df = purrr::reduce(data, bind_rows) %>%
  mutate(s = long_names_scenarios(s))

df$PFT = factor(df$PFT, levels = rev(c( "Needleleaf evergreen", "Pioneering broadleaf" ,   
                                        "Conifers (other)", "Temperate broadleaf" , 
                                        "Tundra")))

df_mean = df %>%
  group_by(PFT, age, s) %>%
  summarize(relative_mean = mean(relative))

npatches = df %>%
  ungroup() %>%
  select(age, Lon, Lat, PID, s) %>%
  unique() %>%
  group_by(age, s) %>%
  count() %>%
  filter(age %in% c(2, 100, 150, 200, 250, 280)) 

fontsize = 15

(p1 = ggplot() + theme_bw() +
    geom_line(data = npatches, aes(x = age, y = n, group = s), color = "black") +
    geom_point(data = npatches, aes(x = age, y = n, shape = s), color = "black") +
    scale_x_continuous(name = "Year after disturbance", expand = c(0,0), breaks = c(0, 100, 200, 300), limits = c(0, 300)) +
    scale_y_continuous(name = "Number of \npatches    ", breaks = c(0, 3000, 6000))  +
    scale_shape_discrete(name = "Scenario") +
    theme(axis.title = element_text(size = fontsize),
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          legend.position = "bottom",
          legend.text = element_text(size = 13),
          legend.title = element_text(size = 15),
          legend.direction = "horizontal",
          panel.grid.x = element_blank(),
          axis.title.y = element_text(hjust = 1.5),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA),
          strip.text = element_text(size = fontsize),
          text = element_text(size = fontsize)))

(p2 = ggplot() + theme_bw() +
    geom_line(data = df[df$PID %in% c(1, 2), ], linewidth = .05, alpha = .05,
              aes(x = age, y = relative, color = PFT, group = interaction(Lon, Lat, PID,PFT))) +
    geom_line(data = df_mean, aes(x = age, y = relative_mean, color = PFT, group = PFT), linewidth = 1) +
    facet_grid(rows = vars(s)) +
    scale_color_manual(name = "Plant functional types (PFTs)", drop = TRUE,
                       values = c("Needleleaf evergreen" = "#0072B2", "Pioneering broadleaf" = "#E69F00",
                                  "Conifers (other)" = "#56B4E9", "Temperate broadleaf" = "#D55E00",   
                                  "Tundra" = "#009E73"),
                       breaks = c( "Needleleaf evergreen", "Pioneering broadleaf" ,   
                                   "Conifers (other)", "Temperate broadleaf" , 
                                   "Tundra")) +
    scale_x_continuous(name = "Year after disturbance", expand = c(0,0), breaks = c(0, 100, 200, 300), limits = c(0, 300)) +
    scale_y_continuous(name = paste0("Share of aboveground carbon"), expand = c(0,0), limits = c(0, 1),
                       breaks = c(0.50, 1.00)) +
    theme(axis.title = element_text(size = fontsize),
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          legend.position = "bottom",
          legend.text = element_text(size = 13),
          legend.title = element_text(size = 15),
          legend.direction = "horizontal",
          legend.title.position = "top",
          panel.grid.x = element_blank(),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA),
          strip.text = element_text(size = fontsize),
          text = element_text(size = fontsize)) +
    guides(color = guide_legend(override.aes = list(linewidth = 2),
                                nrow = 2, byrow = T)))


plot_grid(p2, p1, ncol = 1, rel_heights = c(1, 0.3), align = "hv", labels = c("(a)", "(b)"), axis = "lr")


ggsave("figures/results/long_term_recovery.pdf", width = 9, height = 8)


