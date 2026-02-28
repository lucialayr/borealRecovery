library(here)
source(here("code", "utils.R"))

library(tidyverse)

random_forest_A_final = function(timespan) {
  
   data = list()
    
    for (i in seq(1, 99)) {
      
      for (m in c(1, 2, 3, 4, 5, 6)) {
        
        for (s in c("ssp585", "ssp126", "picontrol")) {
          
          if (m == 1) {
            nfeature = 2
            mode = "states"
          }
          else if (m == 2) {
            nfeature = 5
            mode = "states"
          }
          else if (m == 3) {
            nfeature = 6
            mode = "states"
          } 
          else if (m == 4) {
            nfeature = 10
            mode = "states"
          } 
          else if (m == 5) {
            nfeature = 5
            mode = "clim"
          }
          else {
            nfeature = 10
            mode = "both"
          } 
          
          df = read_csv(paste0(here("data", "random_forest"), "/results", s, "_", timespan, "_seed_", i, "_mode_", mode, "_k_", nfeature, "_m", m, "_predictions.csv")) %>%
            group_by(true_labels, predictions) %>%
            count() %>%
            group_by(true_labels) %>%
            mutate(sample = sum(n),
                   share = n/sum(n),
                   category = if_else(true_labels == predictions, 1, 0),
                   run = i, 
                   s = long_names_scenarios(s),
                   m = m)
          
          data = append(data, list(df))
          
        }
      }
    }
    
    
    df_predictive_power = purrr::reduce(data, bind_rows) %>%
      filter(category == 1,
             true_labels %in% c(0, 1)) %>%
      group_by(true_labels, s, m) %>%
      summarize(share_mean = mean(share),
                share_sd = sd(share)) %>%
      ungroup() %>%
      mutate(class = case_when(true_labels == 0 ~ "Conifer recovery",
                               true_labels == 1 ~ "Deciduous transient"))
    
    write_csv(df_predictive_power, paste0(here("data", "final"), "/random_forest_A_", timespan, ".csv"))
}  

random_forest_B_final  = function(timespan) {
  
 data = list()
    
    for (i in seq(1,99)) {
      
      
      for (s in c("picontrol", "ssp126", "ssp585")) {
        
        nfeature = 10
        mode = "both"
        m = 6
        
        feature_names = data.frame(names = c("pr_yearlysum_1", "pr_yearlysum_2", "pr_yearlysum_3", 
                                             "tas_gs_dailyavg_1", "tas_gs_dailyavg_2", "tas_gs_dailyavg_3", 
                                             "tas_gs_dailymin_1", "tas_gs_dailymin_2", "tas_gs_dailymin_3", 
                                             "tas_gs_dailymax_1", "tas_gs_dailymax_2", "tas_gs_dailymax_3", 
                                             "rsds_gs_dailyavg_1", "rsds_gs_dailyavg_2", "rsds_gs_dailyavg_3",
                                             'bulkdensity_soil', 'clay_fraction', 'ph_soil', 'sand_fraction', 'silt_fraction', 'soilcarbon', 
                                             'sum_exp_est_2_10', 'sum_anpp_2_10'),
                                   category = c(rep("Climate", 3*5),
                                                rep("Soil", 6),
                                                rep("Initial Recruitment", 2))) %>%
          mutate(labels = row_number() - 1)
        
        df = read_csv(paste0(here("data", "random_forest"), "/results", s, "_", timespan, "_seed_", i, "_mode_", mode, "_k_", nfeature, "_m", m, "_sfs_results.csv")) %>%
          mutate(Codes = str_remove_all(Codes, "\\[|\\]")) %>%  
          separate_rows(Codes, sep = ", ") %>%  
          rename(labels = Codes) %>%  
          mutate(labels = as.numeric(labels),
                 s = long_names_scenarios(s),
                 i = i) %>%
          left_join(feature_names)
        
        data = append(data, list(df))
        
      }
    }
    
    
    
    expand_names = data.frame(names = c("pr_yearlysum_1", "pr_yearlysum_2", "pr_yearlysum_3",
                                        "tas_gs_dailyavg_1", "tas_gs_dailyavg_2", "tas_gs_dailyavg_3", 
                                        "tas_gs_dailymin_1", "tas_gs_dailymin_2", "tas_gs_dailymin_3", 
                                        "tas_gs_dailymax_1", "tas_gs_dailymax_2", "tas_gs_dailymax_3", 
                                        "rsds_gs_dailyavg_1", "rsds_gs_dailyavg_2", "rsds_gs_dailyavg_3", 
                                        'bulkdensity_soil', 'clay_fraction', 'ph_soil', 'sand_fraction', 'silt_fraction', 'soilcarbon', 
                                        'sum_exp_est_2_10', 'sum_anpp_2_10'),
                              category = c(rep("Climate", 3*5),
                                           rep("Soil", 6),
                                           rep("Initial Recruitment", 2))) %>%
      mutate(labels = row_number() - 1)
    
    
    importance_feature = purrr::reduce(data, bind_rows) 
    
    importance_ranking = importance_feature %>%
      group_by(s, labels, names, category) %>%
      count(.drop = FALSE) %>%
      mutate(n = as.numeric(n)) %>%
      full_join(expand_names) %>%
      group_by(s) %>%
      mutate(top_five = ifelse(n %in% sort(n, decreasing = TRUE)[1:5], 1, 0.25)) %>%
      ungroup()
    
   write_csv(importance_ranking, paste0(here("data", "final"), "/random_forest_B_", timespan, ".csv"))
}

random_forest_A_final("2015_2040")
random_forest_B_final("2015_2040")

random_forest_A_final("2075_2100")
random_forest_B_final("2075_2100")
###





