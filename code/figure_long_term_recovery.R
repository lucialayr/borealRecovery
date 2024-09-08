setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(duckdb)
library(tidyverse)

install.packages("cowplot")
install.packages("scico")
library(cowplot)
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

con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
dbListTables(con)

scenario = "picontrol"
end_year = 2040
start_year = 2015

get_one_scenario = function(scenario, start_year, end_year) {
  
  
  
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, Year, ndist FROM '", scenario, "_d150_cmass' WHERE Year BETWEEN ", start_year, " AND ", 
                                               end_year, " AND dhist = 1 AND PFT = 'BNE';")) %>% unique()
  
  df_class1 = read_csv(paste0("data/results/all_binary_data_", start_year, "_", end_year,".csv")) %>%
    filter(class == 1, s == long_names_scenarios(scenario)) %>%
    dplyr::select(Lon, Lat, PID) %>%
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

get_data = function(start_year, end_year) {
  
 
  
  data = list()
  
  for (s in c("picontrol", "ssp126", "ssp585")) {
    df = get_one_scenario(s, start_year = start_year, end_year = end_year)
    
    data = append(data, list(df))
    
  }
  
  df = purrr::reduce(data, bind_rows) %>%
    mutate(s = long_names_scenarios(s))
  
  df$PFT = factor(df$PFT, levels = rev(c( "Needleleaf evergreen", "Pioneering broadleaf" ,   
                                          "Conifers (other)", "Temperate broadleaf" , 
                                          "Non-tree V.")))
  
  return(df)
  
}

df = get_data(2015, 2040)

df_mean = df %>%
  group_by(PFT, age, s) %>%
  summarize(relative_mean = mean(relative))

npatches = df %>%
  ungroup() %>%
  dplyr::select(age, Lon, Lat, PID, s) %>%
  unique() %>%
  group_by(age, s) %>%
  count() %>%
  filter(age %in% c(2, 100, 150, 200, 250, 280)) 

(p1 = ggplot() + 
    geom_line(data = npatches, aes(x = age, y = n, group = s), color = "black") +
    geom_point(data = npatches, aes(x = age, y = n, shape = s), color = "black", size = 3) +
    scale_x_continuous(name = "Year after disturbance", expand = c(0,0), breaks = c(0, 100, 200, 300), limits = c(0, 300)) +
    scale_y_continuous(name = "Number of patches    ", breaks = c(0, 3500, 7000), expand = c(0,0), limits = c(0, 7000))  +
    scale_shape_discrete(name = "Scenario") +
    theme(legend.position = "bottom",
          legend.title.position = "top",
          legend.text = element_text(size = 13),
          legend.title = element_text(size = 15),
          legend.direction = "horizontal",
          legend.location = "plot",
          legend.justification = "left",
          plot.margin = unit(c(1,0.5,0,0), "cm")) +
    guides(shape = guide_legend(nrow = 2, byrow = T)))

(p2 = ggplot() + 
    geom_line(data = df[df$PID %in% c(1, 2), ], linewidth = .05, alpha = .05,
              aes(x = age, y = relative, color = PFT, group = interaction(Lon, Lat, PID,PFT))) +
    geom_line(data = df_mean, aes(x = age, y = relative_mean, color = PFT, group = PFT), linewidth = 1) +
    facet_wrap(~s, ncol = 1) +
    scale_color_manual(name = "Plant functional types (PFTs)", drop = TRUE,
                       values = c("Needleleaf evergreen" = "#0072B2", "Conifers (other)" = "#56B4E9", "Non-tree V." = "#009E73",
                                  "Pioneering broadleaf" = "#E69F00", "Temperate broadleaf" = "#D55E00"),
                       breaks = c( "Needleleaf evergreen", "Conifers (other)",  "Non-tree V.",
                                    "Pioneering broadleaf", "Temperate broadleaf")) +
    scale_x_continuous(name = "Year after disturbance", expand = c(0,0), breaks = c(0, 100, 200, 300), limits = c(0, 300)) +
    scale_y_continuous(name = paste0("Share of aboveground carbon"), expand = c(0,0), limits = c(0, 1),
                       breaks = c(0.50, 1.00)) +
    theme(legend.position = "bottom",
          legend.direction = "horizontal",
          legend.title.position = "top",
          legend.location = "plot",
          legend.justification = "left",
          plot.margin = unit(c(0,-3,0,0), "cm")) +
    guides(color = guide_legend(override.aes = list(linewidth = 2),
                                nrow = 2, byrow = T)))


plot_grid(p2, p1, ncol = 2, rel_widths = c(1, 0.6), align = "hv", labels = c("(a)", "(b)"), axis = "bt")


ggsave("figures/results/long_term_recovery.pdf", width = 10, height = 7, scale = 1)


