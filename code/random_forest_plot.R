setwd("~/Desktop/PhD/borealRecovery")
source("code/utils.R")

library(tidyverse)
library(scico)
library(cowplot)
library(ggnewscale)

random_forest_A_plot = function(timespan) {
  
  df_predictive_power = read_csv(paste0("data/final/random_forest_A_", timespan, ".csv"))

  df_predictive_power$true_labels = factor(df_predictive_power$true_labels, levels = c(1,0))
  df_predictive_power$class = factor(df_predictive_power$class, levels = (c("Conifer recovery", "Deciduous transient")))
  df_predictive_power$m = factor(df_predictive_power$m, levels = c(1, 2, 3, 4, 5, 6))
  
  (p1 = ggplot() + 
      geom_hline(yintercept = 0, color = "black", linewidth = 0.75) +
      geom_bar(data = df_predictive_power[df_predictive_power$true_labels == 1,], aes(x = m, y = share_mean, fill = s), color = "black", stat = "identity") +
      scico::scale_fill_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Deciduous transient \n> 10 years", direction = -1) +
      ggnewscale::new_scale_fill() +
      geom_bar(data = df_predictive_power[df_predictive_power$true_labels == 0,], aes(x = m, y = share_mean, fill = s), color = "black", stat = "identity") +
      scico::scale_fill_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer replacement \n(transient < 10 years)", direction = -1) +
      scale_x_discrete(name = "Model") +
      geom_errorbar(data = df_predictive_power, aes(x = m, ymin = share_mean - share_sd, ymax = share_mean + share_sd), width = 0.25) +
      scale_y_continuous("Correctly predicted trajectories in %", expand = c(0, 0), limits = c(0, 1), breaks = c(0, 0.5, 1), labels = c("0 %", "50 %", "100 %")) +
      facet_grid(cols = vars(s),
                 rows = vars(class)) +
      theme(legend.position = "bottom",
            legend.direction = "vertical",
            panel.spacing.y = unit(5, "mm")))
  
  return(p1)
}

random_forest_B_plot = function(timespan) {

  importance_ranking = read_csv(paste0("data/final/random_forest_B_", timespan, ".csv")) 
  
  importance_ranking$names = factor(importance_ranking$names, levels = rev(c("pr_yearlysum_1", "pr_yearlysum_2", "pr_yearlysum_3",
                                                                             "tas_gs_dailyavg_1", "tas_gs_dailyavg_2", "tas_gs_dailyavg_3",
                                                                             "tas_gs_dailymin_1", "tas_gs_dailymin_2", "tas_gs_dailymin_3", 
                                                                             "tas_gs_dailymax_1", "tas_gs_dailymax_2", "tas_gs_dailymax_3", 
                                                                             "rsds_gs_dailyavg_1", "rsds_gs_dailyavg_2", "rsds_gs_dailyavg_3",
                                                                             'bulkdensity_soil', 'clay_fraction', 'ph_soil', 'sand_fraction', 'silt_fraction', 'soilcarbon', 
                                                                             'sum_exp_est_2_10', 'sum_anpp_2_10')))
  
   (p2 = ggplot() +
      coord_flip() +
      geom_vline(xintercept = "pr_yearlysum_1", color = "grey50", linewidth = 0.5) +
      geom_vline(xintercept = "tas_gs_dailyavg_1", color = "grey50", linewidth = 0.5) +
      geom_vline(xintercept = "tas_gs_dailymin_1", color = "grey", linewidth = 0.5) +
      geom_vline(xintercept = "tas_gs_dailymax_1", color = "grey", linewidth = 0.5) +
      geom_vline(xintercept = "rsds_gs_dailyavg_1", color = "grey50", linewidth = 0.5) +
      geom_vline(xintercept = 'bulkdensity_soil', color = "grey50", linewidth = 0.5) +
      geom_vline(xintercept = 'sum_exp_est_2_10', color = "grey50", linewidth = 0.5) +
      facet_wrap(~s, ncol = 3) +
      geom_line(data  = importance_ranking, aes(x = names, y = 1, group = s), color = "black") +
      geom_point(data  = importance_ranking, aes(x = names, y = 1, fill = category, size = n, alpha = top_five), shape = 21, color = "black") +
      scale_color_scico_d(name = "Category", palette = "navia", begin = .4, end = .9) +
      scale_fill_scico_d(name = "Category", palette = "navia", begin = .4, end = .9) +
      scale_size_continuous(name = "Number of iterations", breaks = c(1, 50, 100), labels = c(1, 50, 100), limits = c(1,100),
                            range = c(1, 7)) +
      scale_x_discrete(name = "Feature variables", labels =  rev(c(expression(P["0-33"]), expression(P["34-66"]), expression(P["67-99"]), 
                                                                   expression(T[G~"0-33"]), expression(T[G~"34-66"]), expression(T[G~"67-99"]),
                                                                   expression(T[G^"min"~"0-33"]), expression(T[G^"min"~"34-66"]), expression(T[G^"min"~"67-99"]), 
                                                                   expression(T[G^"max"~"0-33"]), expression(T[G^"max"~"34-66"]), expression(T[G^"max"~"67-99"]), 
                                                                   expression(R["0-33"]), expression(R["34-66"]), expression(R["67-99"]), 
                                                                   expression(rho[S]), expression(chi[sl]), expression(chi[sn]), expression(chi[c]), "pH", expression(C[S]),
                                                                   expression(lambda['10']), expression(NPP['10']))),
                       expand = c(0.04, 0.04)) +
      scale_y_discrete(expand = c(0.1, 0.1)) +
      scale_alpha(range = c(0.25, 1), guide = "none") +
      theme(legend.position = "bottom",
            legend.direction = "vertical",
            axis.title.x = element_blank()) +
      guides(fill = guide_legend(override.aes = list(size = 4))))
  
  return(p2)
  
}

###

random_forest_plot = function(timespan) {
  (p1 = random_forest_A_plot(timespan))
  
  (p2 = random_forest_B_plot(timespan))
  
  plot_grid(p1, p2, nrow = 1, labels = c("(a)", "(b)"))
  
  ggsave(paste0("plots/results_rf_", timespan, ".pdf"),  width = 12, height = 6.75, scale = 0.95)
  ggsave(paste0("plots/results_rf_", timespan, ".png"),  width = 12, height = 6.75, scale = 0.95)
  
}


(random_forest_plot("2015_2040"))
(random_forest_plot("2075_2100"))



