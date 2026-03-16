library(here)

library(tidyverse)
library(stats)
library(zoo)
library(splines)
library(cowplot)

source(here("code", "utils.R"))

histograms_length_transient = function() {
  
  df1 = read_csv(paste0(here("data", "final", "maps_regression_B_patches_2015_2040.csv"))) %>%
    mutate(type = "Transient climate")
  
  df2 = read_csv(paste0(here("data", "final", "maps_regression_B_patches_2075_2100.csv"))) %>%
    mutate(type = "Equilibrium climate")
  
  df = bind_rows(df2, df1) 
  
  df$type = factor(df$type, levels = c("Transient climate", "Equilibrium climate"))
  
  df_text = df %>%
    group_by(type, s, class) %>%
    summarise(mean_length_transient = mean(length_transient))
  
  ggplot() + 
    geom_histogram(data = df[df$length_transient != 0,], aes(x = length_transient, fill = s), color = "black", linewidth = .25, binwidth = 1) +
    scico::scale_fill_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Scenario", direction = -1) +
    facet_wrap(~type, ncol = 1, scales = "free_y") +
    scale_x_continuous(expand = c(0,0), name = "Length of deciduous transient in years", breaks = c(10, 30, 60, 90)) +
    scale_y_continuous(expand = c(0,0), name = "Frequency") +
    theme(legend.position = c(0.15,0.88))
  
  ggsave(here("plots", "histogram_transient_length.pdf"), width = 10, height = 5.5, scale = 1)
  ggsave(here("plots", "histogram_transient_length.png"), width = 10, height = 5.5, scale = 1)
  
}

histograms_length_transient()

maps_regression_B_plot_linear = function(start_year, end_year) {
  
  df_log = read_csv(paste0(here("data", "final"), "/maps_regression_B_patches_", start_year, "_", end_year,".csv"))
  df_logistic = read_csv(paste0(here("data", "final"), "/maps_regression_B_model_", start_year, "_", end_year,".csv"))
  
  
  (p1 = ggplot() +
      geom_hline(yintercept = 0.5, color = "grey", linewidth = 1) +
      geom_point(data = df_log[df_log$class == 2,], aes(x = tas_smoothed, y = length_transient), size = 0.75,
                 color = "darkgrey",  position = position_jitter(width = 0, height = 0.025)) +
      geom_point(data = df_log[df_log$class == 0,], aes(x = tas_smoothed, y = length_transient, color = s), size = 0.75,
                 position = position_jitter(width = 0, height = 0.025)) +
      scico::scale_color_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer recovery \n(transient < 10 years)", direction = -1) +
      guides(color = guide_legend(override.aes = list(size = 4))) +
      ggnewscale::new_scale_color() +
      geom_point(data = df_log[df_log$class == 1,], aes(x = tas_smoothed, y = length_transient, color = s), size = 0.75) +
      scico::scale_color_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Decidous transient \n> 10 years", direction = -1) +
      geom_line(data = df_logistic, aes(x = tas_smoothed, y = predicted_probability), linewidth = 1) +
      scale_x_continuous(name = "Growing season temperature in °C, \naveraged over trajectory", expand = c(0, 0),
                         breaks = c(271, 273, 275, 278, 283), labels = c(271 - 273, 273 - 273, 275 - 273, 278 -273, 283 - 273)) +
      scale_y_continuous(name = "Length of deciduous transient in years", expand = c(0,0), breaks = c(0, 0.25, .5, 0.75, 1), labels = c(0, 5, 10, 50, 100), limits = c(0, 1),
                         sec.axis = sec_axis(~., name = "P(Deciduous transient > 10 years)", breaks = c(0, 0.5, 1), labels = c(0, 0.5, 1))) +
      theme(legend.position = "bottom",
            legend.direction = "vertical") +
      guides(color = guide_legend(override.aes = list(size = 4))))
  
  
  return(p1)
}
create_plot_linear = function() {
  
  p1 = maps_regression_B_plot_linear(2015, 2040) + 
    scale_y_continuous(name = "Length of deciduous transient in years", expand = c(0,0), breaks = c(0, 10, 50, 100), labels = c(0, 10, 50, 100), limits = c(0, 100))
  
  p2 = maps_regression_B_plot_linear(2075, 2100) + 
    scale_y_continuous(name = "Length of deciduous transient in years", expand = c(0,0), breaks = c(0, 10, 50, 100), labels = c(0, 10, 50, 100), limits = c(0, 100))
  
  plot_grid(p1, p2, nrow = 1, labels = c("(a)", "(b)"), hjust = 0.07)
  
  ggsave(here("plots", "regression_unscaled.pdf"), width = 11)
  ggsave(here("plots", "regression_unscaled.png"), width = 11, height = 6.5, dpi = 300)
  
}
create_plot_linear()
