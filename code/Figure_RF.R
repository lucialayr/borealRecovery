library(tidyverse)

install.packages("scico")
install.packages("cowplot")

library(scico)
library(cowplot)

setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

df = data.frame(expand.grid(s = long_names_scenarios(c("picontrol", "ssp126", "ssp585")),
                 model = c("m1", "m2", "m3", "m4"),
                 class = c(1, 0)),
                accuracy = c(rep(70, 6), rep(80, 6), rep(75, 6), rep(90,6)))

df$class = factor(df$class, levels = c(1,0))

(p1 = ggplot() + theme_bw() +
    geom_bar(data = df[df$class == 0,], aes(x = model, y = accuracy, fill = s), color = "black", stat = "identity") +
    scico::scale_fill_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer replacement \n(transient < 10 years)", direction = -1) +
    ggnewscale::new_scale_fill() +
    geom_bar(data = df[df$class == 1,], aes(x = model, y = accuracy, fill = s), color = "black", stat = "identity") +
    scico::scale_fill_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Decidous transient \n> 10 years", direction = -1) +
    scale_x_discrete(name = "Model") +
    scale_y_continuous("Percentage of correctly predicted trajectories", expand = c(0, 0)) +
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
          strip.text.y = element_blank(),
          legend.position = "bottom",
          legend.direction = "vertical",
          legend.text = element_text(size = 13),
          legend.title = element_text(size = 15)))

p1 + 
  annotate("text", x = Inf, y = Inf, label = "Draft", 
           angle = 45, size = 10, color = "black", 
           hjust = 2, vjust = -0.5, alpha = 0.75)

ggsave("figures/results/predictions_rf.pdf", height = 6)


####


df = data.frame(variable = c("V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10"),
                relative_importance = sample(100, 10),
                category = sample(c("Soil", "Soil", "Soil",
                                    "Climate", "Climate", "Climate", "Climate", "Climate", 
                                    "Initial\nRecruitment", "Initial\nRecruitment"), 10, replace = F)) %>%
  arrange((relative_importance)) %>%
  mutate(variable = factor(variable, levels = variable))


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

p2 + 
  annotate("text", x = Inf, y = Inf, label = "Draft", 
           angle = 45, size = 30, color = "black", 
           hjust = 2, vjust = -0.5, alpha = 0.75)


ggsave("figures/results/variables_rf.pdf")


plot_grid(p1 + annotate("text", x = Inf, y = Inf, label = "Draft", 
                      angle = 45, size = 10, color = "black", 
                      hjust = 2, vjust = -0.5, alpha = 0.75),  
          p2 + annotate("text", x = Inf, y = Inf, label = "Draft", 
                        angle = 45, size = 30, color = "black", 
                        hjust = 1.5, vjust = 1.8, alpha = 0.75), 
          nrow = 1, rel_widths = c(1, 0.6), labels = c("(a)", "(b)"))
 
ggsave("figures/results/results_rf.pdf") 
