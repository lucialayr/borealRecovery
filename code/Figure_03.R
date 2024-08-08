setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

install.packages("cowplot")
install.packages("aweSOM")
install.packages("ggforce")
install.packages("scico")
install.packages("concaveman")
install.packages("furrr")

library(duckdb)
library(tidyverse)
library(furrr)
library(aweSOM)
library(cowplot)
library(purrr)
library(ggforce)
library(scico)
library(concaveman)
library(raster)

con = dbConnect(duckdb(), dbdir = "patches2.duckdb", read_only = FALSE) #create the database
dbListTables(con)

scenario = "picontrol"
variable = "cmass"
end_year = 2040
start_year = 2015
length = 200

#### get trajectories per scenario 

get_data_scenario = function(scenario, start_year, end_year, variable, length) {
  
  # get unique identifier of all patches disturbed between `start_year` and `end_year`
  # we filter for dhist = 1 to only get disturbed patches and for PFT = BNE, as it will make the table smaller and for now we only want the identifiers
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, Year, ndist FROM '", scenario, "_d150_cmass' WHERE Year BETWEEN ", start_year, " AND ", 
                                               end_year, " AND dhist = 1 AND PFT = 'BNE';")) %>% unique()
  
  # to select only patches who where able to recover for at least 100 years, we want to inner join this table with patches in the final recovery period `start_year` + 100 - `end_year`  + 100
  # for this we need to write `locations disturbed` to the database
  dbWriteTable(con, "locations_disturbed", locations_disturbed, overwrite = T)
  
  # and perform the inner join (remember that each patch is uniquely defined by Lon, Lat and PID):
  # the resulting table `locations_disturbed_once` should habe less rows than `locations_disturbed`
  locations_disturbed_once = dbGetQuery(con, paste0("SELECT l.Year as year_disturbance, d.PID, d.Lon, d.Lat, d.ndist FROM '", scenario, "_d150_cmass' 
                                                    AS d INNER JOIN locations_disturbed AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat  WHERE d.Year BETWEEN ", 
                                                    start_year + length, " AND ", end_year + length, " AND age = ", length, " AND PFT = 'BNE'")) 
  
  # now we want to retrieve the whole time series, but only for these patches (again an inner join)
  # we write `locations_disturbed_once` to the database:
  dbWriteTable(con, "locations_disturbed_once", locations_disturbed_once, overwrite = T)
  
  # and join. We additionally join by `ndist`to make sure we only get that recovery trajectory.
  # for example, if a patch is disturbed in year 2030, we otherwise will additionally get the years 2015 - 2029 that we are not interested in
  df_1 = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance, d.PFT, d.PID, d.Lon, d.Lat, d.", variable, ", d.age FROM '", scenario, "_d150_", variable, "' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.ndist = l.ndist WHERE d.Year BETWEEN ", 
                                start_year, " AND ", end_year + length)) %>%
    group_by(age, Lon, Lat, PID) %>%
    mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable)))  %>% 
    mutate(across(everything(), ~ifelse(is.na(.), 0, .))) 
  
  # get state and age the 5 years year before a disturbance
  df_2 = dbGetQuery(con, paste0("SELECT d.Year, l.year_disturbance, d.PFT, d.PID, d.Lon, d.Lat, d.", variable, " as ", variable, " FROM '", scenario, "_d150_", variable, "' 
                                AS d INNER JOIN locations_disturbed_once AS l ON d.PID = l.PID AND d.Lon = l.Lon AND d.Lat = l.Lat AND d.Year < l.year_disturbance AND d.Year BETWEEN ", 
                                start_year-5, " AND ", end_year - 1, "AND age <= ", length)) %>%
    mutate(age = Year - year_disturbance) %>%
    filter(age > -6) %>%
    group_by(age, Lon, Lat, PID) %>%
    mutate(relative = !!rlang::sym(variable)/sum(!!rlang::sym(variable)))  %>% 
    mutate(across(everything(), ~ifelse(is.na(.), 0, .)))
  
  print("start binding rows ..")
  
  print(head(df_1))
  print(head(df_2))
  
  df = bind_rows(df_1, df_2) %>%
    mutate(PFT = case_when(PFT == "BINE" ~ "otherC",
                           PFT == "TeNE" ~ "otherC",
                           PFT == "BNS" ~ "otherC",
                           TRUE ~ PFT)) %>%
    group_by(PFT, Lon, Lat, PID, Year, age) %>%
    summarize(across(c(relative, !!variable), sum),  year_disturbance = mean(year_disturbance))
  
  rm(df_1, df_2)
  gc()
  
  # we remove `locations_disturbed` again from database
  dbExecute(con, "DROP TABLE locations_disturbed")
  # we remove `locations_disturbed_once` again from database
  dbExecute(con, "DROP TABLE locations_disturbed_once")
  
  write_csv(df, paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ))
  
  return(df)
}

make_figure_trajectories = function(start_year, end_year, variable, length) {
  
  print("creating trajectories ...")
  
  if (file.exists(paste0("data/processed/trajectories_picontrol_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ))) {
    trajectories_picontrol = read_csv(paste0("data/processed/trajectories_picontrol_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ), show_col_types = F) %>%
      mutate(scenario = "picontrol")
  } else {
    print("creating data ..")
    trajectories_picontrol = get_data_scenario("picontrol", start_year, end_year, variable, length) %>%
      mutate(scenario = "picontrol")
  }
  
  if (file.exists(paste0("data/processed/trajectories_ssp585_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ))) {
    trajectories_ssp585 = read_csv(paste0("data/processed/trajectories_ssp585_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ), show_col_types = F) %>%
      mutate(scenario = "ssp585")
  } else {
    print("creating data ..")
    trajectories_ssp585 = get_data_scenario("ssp585", start_year, end_year, variable, length) %>%
      mutate(scenario = "ssp585")
  }
  
  if (file.exists(paste0("data/processed/trajectories_ssp126_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ))) {
    trajectories_ssp126 = read_csv(paste0("data/processed/trajectories_ssp126_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ), show_col_types = F) %>%
      mutate(scenario = "ssp126")
  } else {
    print("creating data ..")
    trajectories_ssp126 = get_data_scenario("ssp126", start_year, end_year, variable, length) %>%
      mutate(scenario = "ssp126")
  }
  

  print("start plotting ...")
  #make names pretty
  df_trajectories = purrr::reduce(list(trajectories_picontrol, trajectories_ssp585, trajectories_ssp126), bind_rows) %>%
    mutate(PFT = long_names_pfts_species(tolower(PFT)),
          name = paste0(long_names_scenarios(scenario), " \n(", start_year, "-", end_year, ")")) # make names pretty
  
  #calculate mean trajectories
  df_mean = df_trajectories %>%
    group_by(age, PFT, name) %>%
    summarize(relative = mean(relative, na.rm = T)) 
  
  if (variable == "fpc") tag = "FPC" else if (variable == "cmass") tag = "AGC"
  
  p = ggplot() + 
    geom_line(data = df_trajectories[df_trajectories$PID %in% seq(1, 2) & df_trajectories$age > 0, ], linewidth = .05, alpha = .25,
              aes(x = age, y = relative, color = PFT, group = interaction(Lon, Lat, PID,PFT))) +
    geom_line(data = df_mean, aes(x = age, y = relative, color = PFT, group = PFT), linewidth = 2) +
    facet_grid(rows = vars(name)) +
    scale_x_continuous(name = "Year after disturbance", expand = c(0,0), limits = c(-2, length)) +
    scale_y_continuous(name = paste0("Share of", tag), expand = c(0,0), limits = c(0, 1.05),
                       breaks = c(0.25, 0.50, 0.75, 1.00)) +
    scale_color_manual(name = "Vegetation type", drop = TRUE,
                       values = c("Temperate broadleaf \n(Maple, Beech)" = "#D55E00", "Pioneering broadleaf \n(Birch, Aspen)" = "#E69F00",  "Needleleaf evergreen \n(Spruce)" = "#0072B2",   
                                  "Conifers (other) \n(Pine, Larch)" = "#56B4E9", "Tundra \n(Shrubs, Grasses)" = "#009E73")) +
    add_common_layout() +
    theme(text = element_text(size = 25))
  
  ggsave(paste0("figures/trajectories_", start_year, "_", end_year, "_", variable, "_", length, ".png"), width = 10, height = 7, dpi = 600)
  
  #return(p)
}

#create data for binary clustering
for (start_year in c(2015, 2045, 2075)) {
  for (variable in c("cmass", "fpc")) {
    make_figure_trajectories(start_year, start_year + 25, variable, 200)
  }
}

#2045 cmass is missing but I guess I could move on without it.



####### 

cluster_one_year = function(scenario, variable, rel_time, start_year, end_year, n2, n, length) {
  
  df =  read_csv(paste0("data/processed/trajectories_", scenario, "_", start_year, "_", end_year, "_", variable, "_", length, ".csv" )) %>%
    filter(age == rel_time) %>%
    group_by(Lon, Lat, PID) %>%
    mutate(dominant_pft = PFT[which.max(relative)]) %>%
    ungroup() %>%
    dplyr::select(-!!rlang::sym(variable)) %>%
    pivot_wider(names_from = PFT, values_from = relative)
  
  train.data = df %>%
    dplyr::select(BNE, otherC, Tundra, IBS, TeBS)   %>%
    as.matrix() #scale is important to get it in the format we want
  
  set.seed(1465*n)
  ### Initialization (PCA grid)
  init = somInit(train.data, 2, n2)
  ## Train SOM
  patches.som = kohonen::som(train.data, grid = kohonen::somgrid(2, n2, "hexagonal"), 
                             rlen = 100, alpha = c(0.05, 0.01), radius = c(2.65,-2.65), 
                             dist.fcts = "sumofsquares", init = init)
  
  
  superclust_pam = cluster::pam(patches.som$codes[[1]], n2)
  
  superclustering = data.frame("cluster" = seq(1, n2*2),
                               "supercluster" = as.vector(superclust_pam$clustering))
  
  
  print(somQuality(patches.som, train.data))
  
  
  df_final = df %>%
    dplyr::select(BNE, otherC, Tundra, IBS, TeBS, dominant_pft, Lon, Lat, PID, Year) %>%
    cbind(cluster = patches.som$unit.classif) %>%
    full_join(superclustering)
  
  write_delim(df_final, paste0("data/processed/clustering_results/clustering_", scenario, "_", variable,  "_yearAD", rel_time, "_", start_year, "_", end_year, "_", n,  "_", length, ".csv"), delim = ",")
}

cluster_one_year("ssp585", "fpc", 100, 2015, 2040, 3, 1, 100)
cluster_one_year("picontrol", "fpc", 100, 2015, 2040, 3, 1, 100)

cluster_one_year("ssp585", "fpc", 100, 2015, 2040, 3, 1, 110)
cluster_one_year("picontrol", "fpc", 100, 2015, 2040, 3, 1, 110)


cluster_one_year("ssp585", "fpc", 100, 2015, 2040, 3, 1, 150)
cluster_one_year("picontrol", "fpc", 100, 2015, 2040, 3, 1, 150)


cluster_one_year("ssp585", "fpc", 100, 2015, 2040, 3, 1, 200)
cluster_one_year("picontrol", "fpc", 100, 2015, 2040, 3, 1, 200)
cluster_one_year("ssp126", "fpc", 100, 2015, 2040, 3, 1, 200)

cluster_one_year("ssp585", "fpc", 150, 2015, 2040, 3, 1, 150)
cluster_one_year("picontrol", "fpc", 150, 2015, 2040, 3, 1, 150)


cluster_one_year("ssp585", "fpc", 200, 2015, 2040, 3, 1, 200)
cluster_one_year("picontrol", "fpc", 200, 2015, 2040, 3, 1, 200)



cluster_final_state = function(variable) {

  cluster_one_year("ssp585", variable, 100, 2015, 2040, 3, 1, 110)
  cluster_one_year("ssp126", variable, 100, 2015, 2040, 3, 1, 110)
  cluster_one_year("picontrol", variable, 100, 2015, 2040, 3, 1, 110)
  
}

cluster_final_state("fpc")

cluster_empirical = function() {
  
  plan(multisession, workers = 10)
  
  input = expand.grid(yearAD = seq(2,100), iteration = seq(1, 3)) #this was clustered in steps because the algorithm sometimes froze
  
  #furrr::future_map2(input$yearAD, input$iteration,  ~cluster_one_year("ssp585", "cmass", ..1, 2015, 2040, 3, ..2, 200), seed = TRUE)
  #furrr::future_map2(input$yearAD, input$iteration, ~cluster_one_year("ssp585", "cmass", ..1, 2100, 2125, 3, ..2, 200), seed = TRUE)
  furrr::future_map2(input$yearAD, input$iteration, ~cluster_one_year("picontrol", "cmass", ..1, 2015, 2040, 3, ..2, 200), seed = TRUE)
  
}

cluster_empirical()


###plot trajectories as clusters

plot_trajectories_clusters = function(cluster_year, start_year, end_year, variable, length) {
  
  if (file.exists(paste0("data/processed/trajectories_", start_year, "_", end_year, "_", variable,  "_clustered", cluster_year, "_", length, ".csv" ))) {
    df_trajectories = read_csv(paste0("data/processed/trajectories_", start_year, "_", end_year, "_", variable, "_clustered", cluster_year,  "_", length,".csv" ), show_col_types = F)
  } else {
    if (file.exists(paste0("data/processed/trajectories_picontrol_", start_year, "_", end_year, "_", variable,"_", length,  ".csv" ))) {
      trajectories_picontrol = read_csv(paste0("data/processed/trajectories_picontrol_", start_year, "_", end_year, "_", variable, "_", length,".csv" ), 
                                        show_col_types = F) %>%
        mutate(scenario = "picontrol")
    } else {
      print("creating data ..")
      trajectories_picontrol = get_data_scenario("picontrol", start_year, end_year, variable) %>%
        mutate(scenario = "picontrol")
    }
    
    if (file.exists(paste0("data/processed/trajectories_ssp585_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ))) {
      trajectories_ssp585 = read_csv(paste0("data/processed/trajectories_ssp585_", start_year, "_", end_year, "_", variable, "_", length,".csv" ), 
                                     show_col_types = F) %>%
        mutate(scenario = "ssp585")
    } else {
      print("creating data ..")
      trajectories_ssp585 = get_data_scenario("ssp585", start_year, end_year, variable) %>%
        mutate(scenario = "ssp585")
    }
    
    if (file.exists(paste0("data/processed/trajectories_ssp126_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ))) {
      trajectories_ssp126 = read_csv(paste0("data/processed/trajectories_ssp126_", start_year, "_", end_year, "_", variable, "_", length,".csv" ), 
                                     show_col_types = F) %>%
        mutate(scenario = "ssp126")
    } else {
      print("creating data ..")
      trajectories_ssp126 = get_data_scenario("ssp126", start_year, end_year, variable) %>%
        mutate(scenario = "ssp126")
    }
    
    
    
    clusters_picontrol = read_csv(paste0("data/processed/clustering_results/clustering_picontrol_", variable,  "_yearAD",cluster_year,  "_", start_year, "_", end_year, "_1", "_", length,".csv"), 
                                  show_col_types = F) %>% mutate(scenario = "picontrol")
    clusters_ssp585 = read_csv(paste0("data/processed/clustering_results/clustering_ssp585_", variable,  "_yearAD", cluster_year, "_", start_year, "_", end_year, "_1", "_", length,".csv"), 
                               show_col_types = F) %>% mutate(scenario = "ssp585")
    clusters_ssp126 = read_csv(paste0("data/processed/clustering_results/clustering_ssp126_", variable,  "_yearAD", cluster_year, "_", start_year, "_", end_year, "_1", "_", length,".csv"), 
                               show_col_types = F) %>% mutate(scenario = "ssp126")
    
    
    df_clusters = purrr::reduce(list(clusters_picontrol, clusters_ssp126, clusters_ssp585), bind_rows) %>%
      dplyr::select(Lon, Lat, PID, scenario, cluster) %>%
      unique()
    
    print("start plotting ...")
    # make names pretty
    df_trajectories = purrr::reduce(list(trajectories_picontrol, trajectories_ssp126, trajectories_ssp585), bind_rows) %>%
      full_join(df_clusters) %>%
      mutate(PFT = long_names_pfts(tolower(PFT)),
             name = paste0(long_names_scenarios(scenario), " (", start_year, "-", end_year, ")"))  # make pft names pretty
    
    write_csv(df_trajectories, paste0("data/processed/trajectories_", start_year, "_", end_year, "_", variable, "_clustered", cluster_year, "_", length, ".csv" ))
  }
  
  df_mean = df_trajectories %>%
    group_by(age, PFT, name, cluster) %>%
    summarize(relative = mean(relative, na.rm = T)) 
  
  p = ggplot() + 
    geom_vline(xintercept = 100, color = "grey30", linewidth = .5) +
    geom_line(data = df_trajectories[df_trajectories$age > 0 & df_trajectories$PID < 15, ], linewidth = .05, alpha = .25,
              aes(x = age, y = relative, color = PFT, group = interaction(Lon, Lat, PID,PFT))) +
    geom_line(data = df_mean, aes(x = age, y = relative, color = PFT, group = PFT), linewidth = 2) +
    facet_wrap(name ~ cluster, ncol = 6, nrow = 3) +
    scale_x_continuous(name = "Year after disturbance", expand = c(0,0), limits = c(-2, length)) +
    scale_y_continuous(name = "Share of FPC", expand = c(0,0), limits = c(0, 1.05),
                       breaks = c(0.25, 0.50, 0.75, 1.00)) +
    scale_color_manual(name = "Dominant vegetation", drop = TRUE,
                       values = c("Temperate broadleaf" = "#D55E00", "Pioneering broadleaf" = "#E69F00",  "Needleleaf evergreen" = "#0072B2",   
                                  "Conifers (other)" = "#56B4E9", "Tundra" = "#009E73")) +
    add_common_layout() +
    theme(text = element_text(size = 25))
  
  ggsave(paste0("figures/trajectories_clustered", cluster_year, "_", length,"_oneline.png"), width = 15, height = 13)
  
  return(p)
}

plot_trajectories_clusters_oneline = function(cluster_year, start_year, end_year, variable, length) {
  
  if (file.exists(paste0("data/processed/trajectories_", start_year, "_", end_year, "_", variable,  "_clustered", cluster_year, "_", length, ".csv" ))) {
    df_trajectories = read_csv(paste0("data/processed/trajectories_", start_year, "_", end_year, "_", variable, "_clustered", cluster_year,  "_", length,".csv" ), show_col_types = F)
  } else {
    if (file.exists(paste0("data/processed/trajectories_picontrol_", start_year, "_", end_year, "_", variable,"_", length,  ".csv" ))) {
      trajectories_picontrol = read_csv(paste0("data/processed/trajectories_picontrol_", start_year, "_", end_year, "_", variable, "_", length,".csv" ), 
                                        show_col_types = F) %>%
        mutate(scenario = "picontrol")
    } else {
      print("creating data ..")
      trajectories_picontrol = get_data_scenario("picontrol", start_year, end_year, variable) %>%
        mutate(scenario = "picontrol")
    }
    
    if (file.exists(paste0("data/processed/trajectories_ssp585_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ))) {
      trajectories_ssp585 = read_csv(paste0("data/processed/trajectories_ssp585_", start_year, "_", end_year, "_", variable, "_", length,".csv" ), 
                                     show_col_types = F) %>%
        mutate(scenario = "ssp585")
    } else {
      print("creating data ..")
      trajectories_ssp585 = get_data_scenario("ssp585", start_year, end_year, variable) %>%
        mutate(scenario = "ssp585")
    }
    
    if (file.exists(paste0("data/processed/trajectories_ssp126_", start_year, "_", end_year, "_", variable, "_", length, ".csv" ))) {
      trajectories_ssp126 = read_csv(paste0("data/processed/trajectories_ssp126_", start_year, "_", end_year, "_", variable, "_", length,".csv" ), 
                                     show_col_types = F) %>%
        mutate(scenario = "ssp126")
    } else {
      print("creating data ..")
      trajectories_ssp126 = get_data_scenario("ssp126", start_year, end_year, variable) %>%
        mutate(scenario = "ssp126")
    }
    
    
    
    clusters_picontrol = read_csv(paste0("data/processed/clustering_results/clustering_picontrol_", variable,  "_yearAD",cluster_year,  "_", start_year, "_", end_year, "_1", "_", length,".csv"), 
                                  show_col_types = F) %>% mutate(scenario = "picontrol")
    clusters_ssp585 = read_csv(paste0("data/processed/clustering_results/clustering_ssp585_", variable,  "_yearAD", cluster_year, "_", start_year, "_", end_year, "_1", "_", length,".csv"), 
                               show_col_types = F) %>% mutate(scenario = "ssp585")
    clusters_ssp126 = read_csv(paste0("data/processed/clustering_results/clustering_ssp126_", variable,  "_yearAD", cluster_year, "_", start_year, "_", end_year, "_1", "_", length,".csv"), 
                               show_col_types = F) %>% mutate(scenario = "ssp126")
    
    
    df_clusters = purrr::reduce(list(clusters_picontrol, clusters_ssp126, clusters_ssp585), bind_rows) %>%
      dplyr::select(Lon, Lat, PID, scenario, cluster) %>%
      unique()
    
    print("start plotting ...")
    # make names pretty
    df_trajectories = purrr::reduce(list(trajectories_picontrol, trajectories_ssp126, trajectories_ssp585), bind_rows) %>%
      full_join(df_clusters) %>%
      mutate(PFT = long_names_pfts(tolower(PFT)),
             name = paste0(long_names_scenarios(scenario), " (", start_year, "-", end_year, ")"))  # make pft names pretty
    
    write_csv(df_trajectories, paste0("data/processed/trajectories_", start_year, "_", end_year, "_", variable, "_clustered", cluster_year, "_", length, ".csv" ))
  }
  
  df_mean = df_trajectories %>%
    group_by(age, PFT, name, cluster) %>%
    summarize(relative = mean(relative, na.rm = T)) 
  
  p = ggplot() + 
    geom_vline(xintercept = 100, color = "grey30", linewidth = .5) +
    geom_line(data = df_trajectories[df_trajectories$age > 0 & df_trajectories$PID < 15, ], linewidth = .05, alpha = .25,
              aes(x = age, y = relative, color = PFT, group = interaction(Lon, Lat, PID,PFT))) +
    geom_line(data = df_mean, aes(x = age, y = relative, color = PFT, group = PFT), linewidth = 2) +
    facet_grid(cols = vars(cluster), rows = vars(name)) +
    scale_x_continuous(name = "Year after disturbance", expand = c(0,0), limits = c(-2, length)) +
    scale_y_continuous(name = "Share of FPC", expand = c(0,0), limits = c(0, 1.05),
                       breaks = c(0.25, 0.50, 0.75, 1.00)) +
    scale_color_manual(name = "Dominant vegetation", drop = TRUE,
                       values = c("Temperate broadleaf" = "#D55E00", "Pioneering broadleaf" = "#E69F00",  "Needleleaf evergreen" = "#0072B2",   
                                  "Conifers (other)" = "#56B4E9", "Tundra" = "#009E73")) +
    add_common_layout() +
    theme(text = element_text(size = 25),
          legend.position = "bottom",
          legend.direction = "horizontal") +
    guides(fill=guide_legend(nrow=2, title.position = "top", revers = T))
  
  ggsave(paste0("figures/trajectories_clustered", cluster_year, "_", length,"_oneline.png"), width = 20, height = 9)
  
  return(p)
}


plot_trajectories_clusters(100, 2015, 2040, "fpc", 100)
plot_trajectories_clusters(100, 2015, 2040, "fpc", 150)
plot_trajectories_clusters_oneline(100, 2015, 2040, "fpc", 200)

plot_trajectories_clusters(150, 2015, 2040, "fpc", 150)
plot_trajectories_clusters(200, 2015, 2040, "fpc", 200)

#### plotting clusters in climate space

create_data_climate_clusters = function() {
  
  climate_disturbance_picontrol = read_csv("data/processed/covariates_picontrol_2015_2040.csv") %>%
    select(Lon, Lat, Year, tas_yearlymeam) %>%
    filter(Year >= 2015 & Year <= 2040 | Year >= 2015 + 100 & Year <= 2040 + 100) %>%
    rename(MAT = tas_yearlymeam) %>%
    mutate(scenario = "picontrol")
  
  climate_disturbance_ssp585 = read_csv("data/processed/covariates_ssp585_2015_2040.csv") %>%
    select(Lon, Lat, Year, tas_yearlymeam) %>%
    filter(Year >= 2015 & Year <= 2040 | Year >= 2015 + 100 & Year <= 2040 + 100) %>%
    rename(MAT = tas_yearlymeam) %>%
    mutate(scenario = "ssp585")
  
  climate_monthly_ssp585 = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_ssp585_tas_daily_inverted_2014_2150_boreal_yearmonmin.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y")),
           Month = as.numeric(format(time, "%M"))) %>%
    select(-layer, -time) %>%
    rename(Lon = x, Lat = y, tas_monthly = values) %>%
    filter(Year >= 2015 & Year <= 2040 | Year >= 2015 + 100 & Year <= 2040 + 100) %>%
    mutate(scenario = "ssp585") %>%
    full_join(climate_disturbance_ssp585)
  
  climate_monthly_picontrol = terra::rast(paste0("data/covariates/mri-esm2-0_r1i1p1f1_picontrol_tas_daily_inverted_2014_2150_boreal_yearmonmin.nc")) %>%
    terra::as.data.frame(xy = TRUE, time = TRUE, wide = F) %>%
    mutate(Year = as.numeric(format(time, "%Y")),
           Month = as.numeric(format(time, "%M"))) %>%
    select(-layer, -time) %>%
    rename(Lon = x, Lat = y, tas_monthly = values) %>%
    filter(Year >= 2015 & Year <= 2040 | Year >= 2015 + 100 & Year <= 2040 + 100) %>%
    mutate(scenario = "picontrol") %>%
    full_join(climate_disturbance_picontrol)
      
  
  data_climate = bind_rows(climate_monthly_picontrol, climate_monthly_ssp585) 
  
  
  data_vegetation = read_csv(paste0("data/processed/trajectories_", start_year, "_", end_year, "_", variable, "_clustered.csv" ), show_col_types = F) %>%
    select(PFT, Lon, Lat, PID, relative, Year, year_disturbance, scenario, cluster, name) %>%
    filter(Year == year_disturbance + 100) %>%
    mutate(year_cluster = year_disturbance + 100) %>%
    select(-Year) %>%
    group_by(Lon, Lat, PID) %>%
    mutate(dominant_pft = PFT[which.max(relative)]) %>%
    select(-relative, -PFT) %>%
    ungroup() %>%
    pivot_longer(cols = c(year_disturbance, year_cluster), names_to = "time", values_to = "Year")
  
  
  df = data_vegetation_climate %>%
    left_join(data_climate) %>%
    filter(!is.na(MAT))
  
  write_csv(df, "data/processed/climate_space.csv")
  
  return(df)
  
}

plot_climate_space = function() {
  
if (file.exists("data/processed/climate_space.csv")) {
  df = read_csv("data/processed/climate_space.csv", show_col_types = F)
} else {
  df = create_data_climate_clusters()
}
  
  df = df %>%
    select(Lon, Lat, PID, scenario, cluster, name, dominant_pft, time, MAT, tas_monthly) %>%
    unique %>%
    mutate(MAT = MAT - 273.15,
           Tcmin = tas_monthly - 273.15,
           scenario = long_names_scenarios(scenario),
           dominant_pft = long_names_to_species(dominant_pft))
    
  
  (p = ggplot() + theme_bw() +
      geom_hline(yintercept = -30, color = "#E69F00", alpha = .5) +
      geom_hline(yintercept = -13, color = "#D55E00", alpha = .5) +
      geom_hline(yintercept = -30.5, color = "#0072B2", alpha = .5) +
      geom_point(data = unique(df[df$time == "year_cluster" & df$PID < 6 ,]), aes(x = MAT, y = Tcmin,  color = as.factor(dominant_pft), shape = as.factor(cluster)),   stroke = .5, size = 1) +
      stat_ellipse(data = df, aes(x = MAT, y = Tcmin, color = as.factor(cluster), linetype = time),  type = "t")+
      facet_wrap(~scenario, ncol = 1) +
      scale_color_manual(name = "Dominant vegetation", drop = TRUE,
                         values = c("Temperate broadleaf \n(Maple, Beech)" = "#D55E00", "Pioneering broadleaf \n(Birch, Aspen)" = "#E69F00",  "Needleleaf evergreen \n(Spruce)" = "#0072B2",   
                                    "Conifers (other) \n(Pine, Larch)" = "#56B4E9", "Tundra \n(Shrubs, Grasses)" = "#009E73")) + 
      scale_x_continuous(name = "Mean annual temperature in °C", limits = c(-8.5, 10.5), expand = c(0,0)) +
      scale_y_continuous(name = "Minimum monthly temperature in °C", limits = c(-37, 1), expand = c(0,0)) + 
      scale_shape_manual(name = "Cluster", values = seq(0,5)) +
      scale_linetype_manual(name = "Time", labels = c("Year of Disturbance", "Year of Clustering"),
                            values = c("year_disturbance" = "dashed", "year_cluster" = "solid")) +
      add_common_layout() +
      guides(shape = 'none') +
      theme(text = element_text(size = 30)))
  
  ggsave("figures/clusteres_climate.png", width = 15, height = 10)
  
  return(p)
}

  
plot_climate_space()



######



load_year = function(scenario, variable, rel_time, start_year, end_year, n) {
  

    df = read_csv(paste0("data/processed/clustering_results/clustering_", scenario, "_", variable, "_yearAD", rel_time, "_", start_year, "_", end_year, "_", n, "_", length, ".csv"),
                  show_col_types = F) %>%
      mutate("yearAD" = rel_time,
             id = paste0(Lon, "_",  Lat, "_", PID))
    
    return(df)
  
  
}

reclassify_one_cluster = function(df, cluster) {
  dfx = df %>%
    filter(t1 == cluster) %>%
    count(t0, t1) %>%
    mutate(percentage = n/sum(n))
  
  dfx = dfx %>%
    mutate(t0_new = if_else(percentage > 0.5, t1,
                            if_else(percentage == max(dfx$percentage), t1, NA))) %>%
    select(t0, t0_new, percentage, t1) %>%
    filter(!is.na(t0_new))
  
  return(dfx)
}
check_duplicates = function(vec) {
  if (length(unique(vec)) < 6) {
    missing_value = setdiff(seq(1, 6), vec)
    vec[duplicated(vec)] = missing_value
  }
  return(vec)
}
reclassify_timestep = function(scenario, variable, time_step, df1, start_year, end_year, n) {
  
  df0 = load_year(scenario, variable, time_step, start_year, end_year, n) %>%
    select(cluster, id) %>%
    rename(t0 = cluster)
  
  df1 = df1 %>%
    select(cluster, id) %>%
    rename(t1 = cluster)
  
  df = right_join(df0, df1)
  
  classification_table = purrr::map_dfr(seq(1,6), ~reclassify_one_cluster(df, .x))
  
  print(time_step)
  
  print(classification_table)
  
  classification_table$t0_corrected = check_duplicates(classification_table$t0)
  
  classification_table = classification_table %>%
    select(t0_new, t0_corrected) %>%
    rename(cluster = t0_corrected)
  
  print(classification_table)
  
  df1 = load_year(scenario, variable, time_step, start_year, end_year, n)  %>%
    mutate(pft = long_names_pfts(tolower(dominant_pft))) %>%
    select(pft, cluster, yearAD, id) %>%
    left_join(classification_table) %>%
    select(-cluster) %>%
    rename(cluster = t0_new)
  
  return(df1)
}

get_percentage_detected = function(scenario, variable,  yearAD, start_year, end_year, n, length) {
  df_100 = load_year(scenario, variable, 100, start_year, end_year, n)  %>%
    mutate(pft = long_names_pfts(tolower(dominant_pft))) %>%
    select(cluster, id) %>%
    rename(cluster100 = cluster)
  
  df = load_year(scenario, variable, yearAD, start_year, end_year, n)  %>%
    mutate(pft = long_names_pfts(tolower(dominant_pft))) %>%
    select(cluster, id) %>%
    rename(cluster2 = cluster) %>%
    right_join(df_100) %>%
    count(cluster100, cluster2) %>%
    group_by(cluster100) %>%
    mutate(relative = n/sum(n),
           nsum = sum(n)) %>%
    filter(relative == max(relative)) %>%
    ungroup()
  
  return(df)
}

create_data_scenario_for_plot = function(scenario, variable, start_year, end_year, n, length) {
  ad100 = load_year(scenario, variable, length, start_year, end_year, n)  %>%
    mutate(pft = long_names_pfts(tolower(dominant_pft))) %>%
    select(pft, cluster, yearAD, id) 
  
  ad2 = reclassify_timestep(scenario, variable, 2, ad100, start_year, end_year, n)
  
  df1 = purrr::reduce(list(ad100, ad2), bind_rows) %>%
    mutate(scenario = paste0(long_names_scenarios(scenario), " (", start_year, " - ", end_year, ")"))
  
  return(df1)
}

plot_cluster = function(n, length) {
  
  df1 = create_data_scenario_for_plot("ssp585", "cmass", 2015, 2040, 1, length)
  df2 = create_data_scenario_for_plot("ssp585", "cmass", 2100, 2125, 1, length)
  df3 = create_data_scenario_for_plot("picontrol", "cmass", 2015, 2040, 1, length)
  
  df = purrr::reduce(list(df1, df2, df3), bind_rows)
  
  detected1 = get_percentage_detected("ssp585", "cmass", 2, 2015, 2040, n, length) %>%
    mutate(scenario = paste0(long_names_scenarios("ssp585"), " (2015 - 2040)")) 
  
  detected2 = get_percentage_detected("ssp585", "cmass", 2, 2100, 2125, n, length) %>%
    mutate(scenario = paste0(long_names_scenarios("ssp585"), " (2100 - 2125)")) 
  
  detected3 = get_percentage_detected("picontrol", "cmass", 2, 2015, 2040, n, length) %>%
    mutate(scenario = paste0(long_names_scenarios("picontrol"), " (2015 - 2040)"))
  
  df_detected = purrr::reduce(list(detected1, detected2, detected3), bind_rows) %>%
    rename(cluster = cluster100) %>%
    select(cluster, relative, scenario) %>%
    mutate(label = paste(round(relative, 2)*100, "%"))
  
  df$scenario = factor(df$scenario, levels = rev(c("Control (2015 - 2040)", "SSP5-RCP8.5 (2100 - 2125)", "SSP5-RCP8.5 (2015 - 2040)")))
  df_detected$scenario = factor(df_detected$scenario, levels = rev(c("Control (2015 - 2040)", "SSP5-RCP8.5 (2100 - 2125)", "SSP5-RCP8.5 (2015 - 2040)")))
  
  (p = ggplot() + theme_classic() +
      facet_wrap(~scenario, ncol = 1) + 
      geom_line(data = df, aes(x = yearAD, y = cluster, group = id), position = position_jitternormal(sd_x = 3 , sd_y = .2, seed = 123), linewidth = .05, alpha = .5, color = "grey70") + 
      geom_point(data = df, aes(x = yearAD, y =  cluster, color = pft), position = position_jitternormal(sd_x = 3 , sd_y = .2, seed = 123), pch = 4, stroke = 1, alpha = .75, size = .1) +
      geom_text(data = df_detected, aes(y = cluster, x =  length + 15, label = label), size = 7.5) +
      scale_x_continuous(breaks = c(2, length), name = "Years after disturbance") +
      scale_y_discrete(name = "Cluster", labels = seq(1,6), breaks = seq(1,6)) +
      scale_color_manual(name = "Dominant vegetation", drop = TRUE,
                         values = c("Temperate broadleaf" = "#D55E00", "Pioneering broadleaf" = "#E69F00",  "Needleleaf evergreen" = "#0072B2",   
                                    "Conifers (other)" = "#56B4E9", "Tundra" = "#009E73")) +
      add_common_layout() +
      theme(text = element_text(size = 30),
            legend.position = "None"))
  
  ggsave("figures/clusters_lines.png", width = 9, height = 9)
  
  return(p)
  
}

plot_cluster(1, 100)


### plotting overlap between clusters over time
# because we have so many datasets we first generate each trajectory seperately and then put them together.


average_overlap_per_year = function(scenario, variable, yearAD, start_year, end_year, n, length) {
  df = get_percentage_detected(scenario, variable, yearAD, start_year, end_year, n, length) %>%
    summarize(relative = weighted.mean(relative, nsum)) %>%
    mutate(yearAD = yearAD,
           n = n)
  
  return(df)
}


average_overlap_per_year("ssp585", "cmass", 2, 2015, 2040, 1, 150)

data = list() 
for (i in c(1, 2, 3)) {
  for (yad in seq(2,100)) {
    df = average_overlap_per_year("ssp585", "cmass", yad, 2015, 2040, i, 200)
    
    data = append(data, list(df))
  }
}


df_ssp585 = purrr::reduce(data, bind_rows)

write_csv(df_ssp585, "data/processed/clustering_results/overlap_per_time_ssp585.csv")

data = list() 

for (i in c(1, 2, 3)) {
  for (yad in seq(2,100)) {
    df = average_overlap_per_year("picontrol", "cmass", yad, 2015, 2040, i, 200)
    
    data = append(data, list(df))
  }
}


df_picontrol = purrr::reduce(data, bind_rows)

write_csv(df_picontrol, "data/processed/clustering_results/overlap_per_time_picontrol.csv")


df1 = read_csv("data/processed/clustering_results/overlap_per_time_ssp585.csv") %>%
  mutate(scenario = "ssp585")

df2 = read_csv("data/processed/clustering_results/overlap_per_time_picontrol.csv") %>%
  mutate(scenario = "picontrol")

df = bind_rows(df1, df2)

ggplot() + theme_classic() +
  geom_hline(yintercept = 1, linetype = "dashed") +
  geom_line(data = df, aes(x = yearAD, y = relative, group = interaction(n, scenario), color = scenario)) +
  theme(axis.title = element_text(size = fontsize),
        legend.background = element_rect(fill='transparent', color = NA),
        legend.box.background = element_rect(fill='transparent', color = NA),
        legend.box.margin=unit(c(1,1,1,1), "pt"),
        panel.background = element_rect(fill = "transparent", colour = NA),  
        plot.background = element_rect(fill = "transparent", colour = NA),
        strip.background = element_rect(fill = "transparent", color = NA),
        strip.text = element_text(size = fontsize - 5),
        text = element_text(size = fontsize),
        legend.position = "bottom",
        legend.direction = "horizontal")

ggsave("figures/cluster_overlap.png")


######



input = expand.grid(yearAD = seq(2, 100), iteration = seq(1,30))

df1 = furrr::future_map2_dfr(input$yearAD, input$iteration,  ~average_overlap_per_year("ssp585", "cmass", ..1, 2015, 2040, ..2, 150)) %>%
  mutate(scenario = paste0(long_names_scenarios("ssp585"), " (2015 - 2040)"))

write_csv(df1, "processed/clustering/results/df1.csv")

df2 = furrr::future_map2_dfr(input$yearAD, input$iteration, ~average_overlap_per_year("ssp585", "cmass", ..1, 2100, 2125, ..2, 150)) %>%
  mutate(scenario = paste0(long_names_scenarios("ssp585"), " (2100 - 2125)"))

write_csv(df2, "processed/clustering/results/df2.csv")

df3 = furrr::future_map2_dfr(input$yearAD, input$iteration, ~average_overlap_per_year("picontrol", "cmass", ..1, 2015, 2040, ..2, 150)) %>%
  mutate(scenario = paste0(long_names_scenarios("picontrol"), " (2015 - 2040)"))


write_csv(df3, "processed/clustering/results/df3.csv")

df = bind_rows(read_csv("processed/clustering/results/df1.csv"), read_csv("processed/clustering/results/df2.csv"), read_csv("processed/clustering/results/df3.csv"))

write_csv(df, "processed/clustering/results/overlap.csv")

df = read_csv("processed/clustering/results/overlap.csv")

df_mean = df1 %>%
  group_by(yearAD, scenario) %>%
  summarize(relative = mean(relative))

fill = expand.grid(relative = seq(1/6, 1, length = 200), yearAD = seq(60, 95, length = 200))

ggplot() + theme_classic() +
  geom_tile(data = fill, aes(y =  relative, x = yearAD, fill = yearAD)) +
  geom_rect(aes(xmin = 95, xmax = 150, ymin = -Inf, ymax = 1), fill = "grey90") +
  geom_hline(yintercept = 1, color = "grey", linewidth = .25) +
  geom_hline(yintercept = 1/6, color = "grey", linewidth = .25) +
  geom_line(data = df, aes(x = yearAD, y = relative, color = scenario, group = interaction(n, scenario)), linewidth = .1, alpha = .5) +
  geom_line(data = df_mean, aes(x = yearAD, y = relative, color = scenario), linewidth = 1) +
  scale_x_continuous(name = "Year after disturbance", expand = c(0,0)) +
  scale_y_continuous(name = "Percentage of stable clustering", expand = c(0,0), breaks = c(round(1/6, 2), 0.25, 0.5, 0.75, 1))+
  scale_fill_gradient(low = "white", high = "grey90", limits = c(60, 95)) +
  scico::scale_color_scico_d(palette = "managua", begin = .2, end = .8, name = "Scenario \n(Time of disturbance)") +
  theme(axis.title = element_text(size = fontsize),
        legend.background = element_rect(fill='transparent', color = NA),
        legend.box.background = element_rect(fill='transparent', color = NA),
        legend.box.margin=unit(c(1,1,1,1), "pt"),
        panel.background = element_rect(fill = "transparent", colour = NA),  
        plot.background = element_rect(fill = "transparent", colour = NA),
        strip.background = element_rect(fill = "transparent", color = NA),
        strip.text = element_text(size = fontsize - 5),
        axis.text = element_blank(),
        text = element_text(size = fontsize),
        legend.position = "bottom",
        legend.direction = "horizontal")

ggsave("figures/cluster_overlap_per_year.png")


##########################################
### plotting mean trajectories

get_data_scenario_mean = function(scenario, start_year, end_year, variable) {
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, dhist, Year FROM '", scenario, "_d0.003333333_", variable, "' WHERE ", start_year, " <= Year AND Year <= ", 
                                               end_year, " AND dhist = 1;")) %>% #get all patches that have experienced a disturbance is specified time window
    unique()
  
  locations_disturbed_again = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, dhist, Year FROM '", scenario, "_d0.003333333_", variable, "' WHERE ", start_year + 40, " <= Year AND Year <= ", 
                                                     end_year + 100, " AND dhist = 1;")) %>% #get all patches that have experienced a disturbance in the time between the first year
                                                                                            # of recovery and the last possible year of recovery  
    unique() %>%
    rename(dhist2 = dhist,
           Year2 = Year) 
  
  locations_disturbed_once = left_join(locations_disturbed, locations_disturbed_again) %>% #left_join, as we only want to keep patches that have been disturbed in the initial time window
    mutate(difference = Year2 - Year) %>%
    filter(is.na(dhist2) | #filters out all rows that did not experience disturbance again (dhist2 will have no entry)
             (!is.na(dhist2) & difference > 100)) %>% #filters out all rows where disturbance occured later (e.g. disturbed in 2015 and again in 2040 -> not a problem here)
    select(Lon, Lat, PID) %>%
    unique()
  
  df = dbGetQuery(con, paste0("SELECT Year, PFT, PID, Lon, Lat, ", variable, ", relative_time FROM '", scenario, "_d0.003333333_", variable, "' WHERE Year > ", start_year, " AND ndist > 0 AND Year < ", end_year + 101)) %>%
    mutate(PFT = if_else(PFT %in% c("BINE", "BNS", "TeNE"), "otherC", PFT)) %>%
    mutate(PFT = if_else(PFT %in% c("C3G",  "HSE", "HSS", "LSS", "LSE", "GRT", "EPDS", "SPDS", "CLM"), "Tundra", PFT)) %>% 
    group_by(relative_time, Lon, Lat, PID, PFT) %>%
    summarize(variable = sum(!!rlang::sym(variable))) %>%
    ungroup() %>%
    inner_join(locations_disturbed_once) %>%
    filter(PFT %in% c("BNE", "otherC", "IBS", "TeBS", "Tundra")) %>% #for now because broken files have some issues
    group_by(relative_time, Lon, Lat, PID) %>%
    mutate(relative = variable/sum(variable)) %>%
    filter(!is.na(relative)) %>%
    group_by(PFT, relative_time) %>%
    summarize(relative = mean(relative)) %>%
    mutate(PFT = long_names_pfts_species(tolower(PFT)),
           scenario = long_names_scenarios(scenario),
           name = paste0(long_names_scenarios(scenario), " (", start_year, " - ", end_year, ")"))
  
  return(df)
}

get_data_scenario_trajectories = function(scenario, start_year, end_year, variable) {
  
  locations_disturbed = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, dhist, Year FROM '", scenario, "_d0.003333333_", variable, "' WHERE ", start_year, " <= Year AND Year <= ", 
                                               end_year, " AND dhist = 1;")) %>% #get all patches that have experienced a disturbance is specified time window
    unique()
  
  locations_disturbed_again = dbGetQuery(con, paste0("SELECT PID, Lon, Lat, dhist, Year FROM '", scenario, "_d0.003333333_", variable, "' WHERE ", start_year + 40, " <= Year AND Year <= ", 
                                                     end_year + 100, " AND dhist = 1;")) %>% #get all patches that have experienced a disturbance in the time between the first year
    # of recovery and the last possible year of recovery  
    unique() %>%
    rename(dhist2 = dhist,
           Year2 = Year) 
  
  locations_disturbed_once = left_join(locations_disturbed, locations_disturbed_again) %>% #left_join, as we only want to keep patches that have been disturbed in the initial time window
    mutate(difference = Year2 - Year) %>%
    filter(is.na(dhist2) | #filters out all rows that did not experience disturbance again (dhist2 will have no entry)
             (!is.na(dhist2) & difference > 100)) %>% #filters out all rows where disturbance occured later (e.g. disturbed in 2015 and again in 2040 -> not a problem here)
    select(Lon, Lat, PID) %>%
    unique()
  
  df_trajectories = dbGetQuery(con, paste0("SELECT Year, PFT, PID, Lon, Lat, ", variable, ", relative_time FROM '", scenario, "_d0.003333333_", variable, "' WHERE ", start_year, " <= Year AND Year <= ", 
                                           end_year + 101)) %>% #select for one PID generates random subsample of data that is plotable
    mutate(PFT = if_else(PFT %in% c("BINE", "BNS", "TeNE"), "otherC", PFT)) %>%
    mutate(PFT = if_else(PFT %in% c("C3G",  "HSE", "HSS", "LSS", "LSE", "GRT", "EPDS", "SPDS", "CLM"), "Tundra", PFT)) %>% 
    group_by(relative_time, Lon, Lat, PID, PFT) %>%
    summarize(variable = sum(!!rlang::sym(variable))) %>%
    ungroup() %>%
    inner_join(locations_disturbed_once) %>%
    filter(PFT %in% c("BNE", "otherC", "IBS", "TeBS", "Tundra")) %>% #for now because broken files have some issues
    group_by(relative_time, Lon, Lat, PID) %>%
    mutate(relative = variable/sum(variable)) %>%
    filter(!is.na(relative)) %>%
    mutate(PFT = long_names_pfts_species(tolower(PFT)),
           scenario = long_names_scenarios(scenario),
           name = paste0(long_names_scenarios(scenario), " (", start_year, " - ", end_year, ")")) %>%
    unique()
  
  return(df_trajectories)
}

figure_2 = function() {
  df1 = get_data_scenario_mean("ssp585", 2015, 2040, "cmass")
  df2 = get_data_scenario_mean("ssp585", 2100, 2125, "cmass")
  df3 = get_data_scenario_mean("picontrol", 2015, 2040, "cmass")
  
  df4 = get_data_scenario_trajectories("ssp585", 2015, 2040, "cmass")
  
  write_csv(df4, "test.csv")
  df5 = get_data_scenario_trajectories("ssp585", 2100, 2125, "cmass")
  df6 = get_data_scenario_trajectories("picontrol", 2015, 2040, "cmass")
  
  df = purrr::reduce(list(df1, df2, df3), bind_rows)
  df_trajectories = purrr::reduce(list(df4, df5, df6), bind_rows)
  
  df$name = factor(df$name, levels = rev(c("Control (2015 - 2040)", "SSP5-RCP8.5 (2100 - 2125)", "SSP5-RCP8.5 (2015 - 2040)")))
  df_trajectories$name = factor(df_trajectories$name, levels = rev(c("Control (2015 - 2040)", "SSP5-RCP8.5 (2100 - 2125)", "SSP5-RCP8.5 (2015 - 2040)")))
  
  ggplot() + 
    geom_line(data = df_trajectories, linewidth = .05, alpha = .25,
              aes(x = relative_time, y = relative, color = PFT, group = interaction(Lon, Lat, PID,PFT))) +
    geom_line(data = df, aes(x = relative_time, y = relative, color = PFT, group = PFT), linewidth = 2) +
    facet_grid(rows = vars(name)) +
    scale_x_continuous(name = "Year after disturbance", limits = c(0, 100), expand = c(0,0)) +
    scale_y_continuous(name = "Share of aboveground biomass", expand = c(0,0), limits = c(0, 1.1),
                       breaks = c(0.25, 0.50, 0.75, 1.00)) +
    scale_color_manual(name = "Dominant vegetation", drop = TRUE,
                       values = c("Temperate broadleaf \n(Maple, Beech)" = "#D55E00", "Pioneering broadleaf \n(Birch, Aspen)" = "#E69F00",  
                                  "Needleleaf evergreen \n(Spruce)" = "#0072B2", "Conifers (other) \n(Pine, Larch)" = "#56B4E9", 
                                  "Tundra \n(Shrubs, Grasses)" = "#009E73")) +
    add_common_layout() +
    theme(text = element_text(size = 30),
          legend.position = "None")
  
  ggsave("figures/trajectories.png", width = 8, height = 9)
}

write_csv(df3, "test.csv")


