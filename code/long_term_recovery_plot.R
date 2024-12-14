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

long_term_recovery_A_plot = function() {
  
  df = read_csv("data/final/long_term_recovery_A_final.csv")
  
  df_mean = df %>%
    group_by(PFT, age, s) %>%
    summarize(relative_mean = mean(relative))
  
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
      guides(color = guide_legend(override.aes = list(linewidth = 2, alpha = 1),
                                  nrow = 2, byrow = T)))
  
  return(p2)
  
}

long_term_recovery_A_plot_png = function() {
  
  df = read_csv("data/final/long_term_recovery_A_final.csv")
  
  df_mean = df %>%
    group_by(PFT, age, s) %>%
    summarize(relative_mean = mean(relative))
  
  (p2 = ggplot() + 
      geom_line(data = df[df$PID %in% c(1, 2), ], linewidth = .02, alpha = 1,
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
      guides(color = guide_legend(override.aes = list(linewidth = 2, alpha = 1),
                                  nrow = 2, byrow = T)))
  
  return(p2)
  
}
  
long_term_recovery_B_plot = function() {
  
  npatches = read_csv("data/final/long_term_recovery_B_final.csv")
 
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
  
}


long_term_recovery_plot = function() {
  
  p1 = long_term_recovery_A_plot()
  p2 = long_term_recovery_B_plot()
  
  plot_grid(p1, p2, ncol = 2, rel_widths = c(1, 0.6), align = "hv", labels = c("(a)", "(b)"), axis = "bt")
  
  
  ggsave("plots/long_term_recovery.pdf", width = 10, height = 7, scale = 1)
  
  p1 = long_term_recovery_A_plot_png()
  
  plot_grid(p1, p2, ncol = 2, rel_widths = c(1, 0.6), align = "hv", labels = c("(a)", "(b)"), axis = "bt")
  
  
  ggsave("plots/long_term_recovery.png", width = 10, height = 7, scale = 1, dpi = 600)
  
  
}

long_term_recovery_plot()



