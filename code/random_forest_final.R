setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(tidyverse)

plot_accuracy = function(timespan) {
  
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
          
          df = read_csv(paste0("data/random_forest/results/", s, "_", timespan, "_seed_", i, "_mode_", mode, "_k_", nfeature, "_m", m, "_predictions.csv")) %>%
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
    
    write_csv(df_predictive_power, paste0("data/results/predictive_power_", timespan, ".csv"))
}  


plot_feature_importance = function(timespan) {
  
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
        
        df = read_csv(paste0("data/random_forest/results/", s, "_", timespan, "_seed_", i, "_mode_", mode, "_k_", nfeature, "_m", m, "_sfs_results.csv")) %>%
          mutate(Codes = str_remove_all(Codes, "\\[|\\]")) %>%  
          separate_rows(Codes, sep = ", ") %>%  
          rename(labels = Codes) %>%  
          mutate(labels = as.numeric(labels),
                 rank = row_number(),
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
      mutate(labels = row_number() - 1,
             s = long_names_scenarios("picontrol"),
             rank = 0)
    
    
    importance_feature = purrr::reduce(data, bind_rows) 
    
    importance_ranking = importance_feature %>%
      group_by(s, rank, labels, names, category) %>%
      count(.drop = FALSE) %>%
      mutate(n = as.numeric(n)) %>%
      full_join(expand_names)
    
   write_csv(importance_ranking, paste0("data/results/importance_ranking_", timespan, ".csv"))
}

###

(p1 = plot_accuracy(timespan = "2015_2040"))

(p2 = plot_feature_importance("2015_2040"))

plot_grid(p1, p2, nrow = 1, labels = c("(a)", "(b)"))

ggsave("figures/results/results_rf_2015_2040.pdf",  width = 12, scale = 0.95)


###





