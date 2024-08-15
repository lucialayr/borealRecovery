library(tidyverse)

install.packages("scico")
install.packages("cowplot")
install.packages("ggnewscale")

library(scico)
library(cowplot)
library(ggnewscale)

setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")





plot_accuracy = function(timespan) {
  data = list()
  
  for (i in seq(1,30)) {
    
    for (m in c(1, 2, 3, 4)) {
      
      for (s in c("ssp585", "ssp126", "picontrol")) {
        
        if (m == 1) {
          nfeature = 2
          mode = "states"
        }
        else if (m == 3) {
          nfeature = 6
          mode = "states"
        } 
        else if (m == 2) {
          nfeature = 10
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
  
  
  df_predictive_power$true_labels = factor(df_predictive_power$true_labels, levels = c(1,0))
  df_predictive_power$class = factor(df_predictive_power$class, levels = (c("Conifer recovery", "Deciduous transient")))
  df_predictive_power$m = factor(df_predictive_power$m, levels = c(1, 3, 2, 4))
  
  (p1 = ggplot() + theme_classic() +
      geom_hline(yintercept = 0, color = "black", linewidth = 0.75) +
      geom_bar(data = df_predictive_power[df_predictive_power$true_labels == 1,], aes(x = m, y = share_mean, fill = s), color = "black", stat = "identity") +
      scico::scale_fill_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Deciduous transient \n> 10 years", direction = -1) +
      ggnewscale::new_scale_fill() +
      geom_bar(data = df_predictive_power[df_predictive_power$true_labels == 0,], aes(x = m, y = share_mean, fill = s), color = "black", stat = "identity") +
      scico::scale_fill_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer replacement \n(transient < 10 years)", direction = -1) +
      scale_x_discrete(name = "Model", breaks = c(1, 2, 3, 4), labels = c("M1", "M3", "M2",  "M4")) +
      geom_errorbar(data = df_predictive_power, aes(x = m, ymin = share_mean - share_sd, ymax = share_mean + share_sd), width = 0.25) +
      scale_y_continuous("Correctly predicted trajectories in %", expand = c(0, 0), limits = c(0, 1), breaks = c(0, 0.5, 1), labels = c("0 %", "50 %", "100 %")) +
      facet_grid(cols = vars(s),
                 rows = vars(class)) +
      theme(axis.text = element_text(size = 15),
            axis.title =  element_text(size = 15),
            legend.background = element_rect(fill='transparent', color = NA),
            legend.box.background = element_rect(fill='transparent', color = NA),
            panel.background = element_rect(fill = "transparent", colour = NA),  
            plot.background = element_rect(fill = "transparent", colour = NA),
            strip.background = element_rect(fill = "transparent", color = NA),
            strip.text = element_text(size = 15),
            strip.text.y = element_text(size = 15),
            legend.position = "bottom",
            legend.direction = "vertical",
            legend.text = element_text(size = 13),
            legend.title = element_text(size = 15),
            panel.spacing.y = unit(5, "mm"),
            panel.grid.major.y = element_line()))
  
  return(p1)
  
}

plot_feature_importance = function(timespan) {
  
  data = list()
  
  for (i in seq(1,30)) {
    
    
    for (s in c("picontrol", "ssp126", "ssp585")) {
      
      nfeature = 10
      mode = "both"
      
      feature_names = data.frame(names = c("pr_yearlysum_1", "pr_yearlysum_2", "pr_yearlysum_3", "pr_yearlysum_4",
                                           "tas_gs_dailyavg_1", "tas_gs_dailyavg_2", "tas_gs_dailyavg_3", "tas_gs_dailyavg_4",
                                           "tas_gs_dailymin_1", "tas_gs_dailymin_2", "tas_gs_dailymin_3", "tas_gs_dailymin_4",
                                           "tas_gs_dailymax_1", "tas_gs_dailymax_2", "tas_gs_dailymax_3", "tas_gs_dailymax_4",
                                           "rsds_gs_dailyavg_1", "rsds_gs_dailyavg_2", "rsds_gs_dailyavg_3", "rsds_gs_dailyavg_4",
                                           'bulkdensity_soil', 'clay_fraction', 'ph_soil', 'sand_fraction', 'silt_fraction', 'soilcarbon', 
                                           'sum_exp_est_2_10', 'sum_anpp_2_10'),
                                 category = c(rep("Climate", 4*5),
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
  
  
  
  expand_names = data.frame(names = c("pr_yearlysum_1", "pr_yearlysum_2", "pr_yearlysum_3", "pr_yearlysum_4",
                                      "tas_gs_dailyavg_1", "tas_gs_dailyavg_2", "tas_gs_dailyavg_3", "tas_gs_dailyavg_4",
                                      "tas_gs_dailymin_1", "tas_gs_dailymin_2", "tas_gs_dailymin_3", "tas_gs_dailymin_4",
                                      "tas_gs_dailymax_1", "tas_gs_dailymax_2", "tas_gs_dailymax_3", "tas_gs_dailymax_4",
                                      "rsds_gs_dailyavg_1", "rsds_gs_dailyavg_2", "rsds_gs_dailyavg_3", "rsds_gs_dailyavg_4",
                                      'bulkdensity_soil', 'clay_fraction', 'ph_soil', 'sand_fraction', 'silt_fraction', 'soilcarbon', 
                                      'sum_exp_est_2_10', 'sum_anpp_2_10'),
                            category = c(rep("Climate", 4*5),
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
  
  importance_ranking$names = factor(importance_ranking$names, levels = rev(c("pr_yearlysum_1", "pr_yearlysum_2", "pr_yearlysum_3", "pr_yearlysum_4",
                                                                             "tas_gs_dailyavg_1", "tas_gs_dailyavg_2", "tas_gs_dailyavg_3", "tas_gs_dailyavg_4",
                                                                             "tas_gs_dailymin_1", "tas_gs_dailymin_2", "tas_gs_dailymin_3", "tas_gs_dailymin_4",
                                                                             "tas_gs_dailymax_1", "tas_gs_dailymax_2", "tas_gs_dailymax_3", "tas_gs_dailymax_4",
                                                                             "rsds_gs_dailyavg_1", "rsds_gs_dailyavg_2", "rsds_gs_dailyavg_3", "rsds_gs_dailyavg_4",
                                                                             'bulkdensity_soil', 'clay_fraction', 'ph_soil', 'sand_fraction', 'silt_fraction', 'soilcarbon', 
                                                                             'sum_exp_est_2_10', 'sum_anpp_2_10')))
  
  
  
  
  (p2 = ggplot() + theme_classic() +
      coord_flip() +
      geom_vline(xintercept = "pr_yearlysum_1", color = "grey50", linewidth = 0.5) +
      geom_vline(xintercept = "tas_gs_dailyavg_1", color = "grey50", linewidth = 0.5) +
      geom_vline(xintercept = "tas_gs_dailymin_1", color = "grey", linewidth = 0.5) +
      geom_vline(xintercept = "tas_gs_dailymax_1", color = "grey", linewidth = 0.5) +
      geom_vline(xintercept = "rsds_gs_dailyavg_1", color = "grey50", linewidth = 0.5) +
      geom_vline(xintercept = 'bulkdensity_soil', color = "grey50", linewidth = 0.5) +
      geom_vline(xintercept = 'sum_exp_est_2_10', color = "grey50", linewidth = 0.5) +
      facet_wrap(~s, ncol = 3) +
      geom_line(data  = importance_ranking, aes(x = names, y = rank, group = rank), color = "black") +
      geom_point(data  = importance_ranking, aes(x = names, y = rank, fill = category, size = n), shape = 21, color = "black") +
      scale_color_scico_d(name = "Category", palette = "navia", begin = .4, end = .9) +
      scale_fill_scico_d(name = "Category", palette = "navia", begin = .4, end = .9) +
      scale_size_continuous(name = "Number of iterations", breaks = c(1, 15, 30), range = c(1, 7)) +
      scale_x_discrete(name = "Feature variables", labels =  rev(c(expression(P["0-25"]), expression(P["26-50"]), expression(P["51-75"]), expression(P["76-100"]), 
                                                                   expression(T[G~"0-25"]), expression(T[G~"26-50"]), expression(T[G~"51-75"]), expression(T[G~"76-100"]), 
                                                                   expression(T[G^"min"~"0-25"]), expression(T[G^"min"~"26-50"]), expression(T[G^"min"~"51-75"]), expression(T[G^"min"~"76-100"]),
                                                                   expression(T[G^"max"~"0-25"]), expression(T[G^"max"~"26-50"]), expression(T[G^"max"~"51-75"]), expression(T[G^"max"~"76-100"]),
                                                                   expression(R["0-25"]), expression(R["26-50"]), expression(R["51-75"]), expression(R["76-100"]), 
                                                                   expression(varphi[S]), expression(chi[sl]), expression(chi[sn]), expression(chi[c]), "pH", expression(C[S]),
                                                                   expression(lambda[i]), expression(NPP))),
                       expand = c(0.04, 0.04)) +
      scale_y_continuous(name = "Importance rank", expand = c(0.1, 0.1), limits = c(1, 5)) +
      theme(axis.text.x = element_text(size =15)) +
      theme(axis.text.y = element_text(size = 10),
            axis.title =  element_text(size = 15),
            legend.background = element_rect(fill='transparent', color = NA),
            legend.box.background = element_rect(fill='transparent', color = NA),
            panel.background = element_rect(fill = "transparent", colour = NA),  
            plot.background = element_rect(fill = "transparent", colour = NA),
            strip.background = element_rect(fill = "transparent", color = NA),
            strip.text = element_text(size = 15),
            panel.grid.major.y = element_line(),
            legend.position = "bottom",
            legend.direction = "vertical",
            legend.text = element_text(size = 13),
            legend.title = element_text(size = 15)) +
      guides(fill = guide_legend(override.aes = list(size = 4))))
  
}

###

(p1 = plot_accuracy(timespan = "2015_2040"))

(p2 = plot_feature_importance("2015_2040"))

plot_grid(p1, p2, nrow = 1, labels = c("(a)", "(b)"))

ggsave("figures/results/results_rf_2015_2040.pdf", scale = 1, width = 12)


###

(p1 = plot_accuracy(timespan = "2075_2100"))

(p2 = plot_feature_importance("2075_2100"))

plot_grid(p1, p2, nrow = 1, labels = c("(a)", "(b)"))

ggsave("figures/results/results_rf_2075_2100.pdf", scale = 1, width = 12)



########################### OLD

(p2 = ggplot() + theme_classic() +
    geom_bar(data = importance_feature, aes(x = names, y = rank, fill = category), color = "black", stat = "identity") +
    coord_flip() +
    facet_wrap(s ~ i, ncol = 10) +
    scale_fill_scico_d(name = "Category", palette = "navia", begin = .4, end = .9) +
    scale_x_discrete(name = "Feature variables", expand = c(0,0)) +
    scale_y_continuous(name = "Relative importance", expand = c(0,0)) +
    theme(axis.text = element_text(size = 15),
          axis.title =  element_text(size = 15),
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA),
          strip.text = element_text(size = 15),
          legend.position = "bottom",
          legend.direction = "vertical",
          legend.text = element_text(size = 13),
          legend.title = element_text(size = 15)))






(p2 = ggplot() + theme_classic() +
    geom_bar(data = df, aes(x = variable, y = relative_importance, fill = category), color = "black", stat = "identity") +
    coord_flip() +
    scale_fill_scico_d(name = "Category", palette = "navia", begin = .4, end = .9) +
    scale_x_discrete(name = "Feature variables", expand = c(0,0)) +
    scale_y_continuous(name = "Relative importance", expand = c(0,0)) +
    theme(axis.text = element_text(size = 15),
          axis.title =  element_text(size = 15),
          legend.background = element_rect(fill='transparent', color = NA),
          legend.box.background = element_rect(fill='transparent', color = NA),
          panel.background = element_rect(fill = "transparent", colour = NA),  
          plot.background = element_rect(fill = "transparent", colour = NA),
          strip.background = element_rect(fill = "transparent", color = NA),
          strip.text = element_text(size = 15),
          legend.position = "bottom",
          legend.direction = "vertical",
          legend.text = element_text(size = 13),
          legend.title = element_text(size = 15)))




ggsave("figures/results/variables_rf.pdf")


plot_grid(p1 + annotate("text", x = Inf, y = Inf, label = "Draft", 
                      angle = 45, size = 10, color = "black", 
                      hjust = 2, vjust = -0.5, alpha = 0.75),  
          p2 + annotate("text", x = Inf, y = Inf, label = "Draft", 
                        angle = 45, size = 30, color = "black", 
                        hjust = 1.5, vjust = 1.8, alpha = 0.75), 
          nrow = 1, rel_widths = c(1, 0.6), labels = c("(a)", "(b)"))
 
ggsave("figures/results/results_rf.pdf") 
