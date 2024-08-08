setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(tidyverse)

install.packages("scico")
library(scico)


###translate features to variable names
convert_m1 = function(x_t, x_s) {
  x_t = c("pr_yearlysum", "tas_gs_dailyavg", "tas_gs_dailymin", "tas_gs_dailymax", "rsds_gs_dailyavg")
  x_s = c('bulkdensity_soil', 'clay_fraction', 'ph_soil', 'sand_fraction', 'silt_fraction', 'soilcarbon', 
          'sum_exp_est_2_10', 'sum_anpp_2_10')
  
}



### Predictive power of different models

data = list()

for (i in seq(1,8)) {
  
  df = read_csv(paste0("data/random_forest/results/ssp585_2015_2040_seed_", i, "_mode_both_k_10_m4_predictions.csv")) %>%
    group_by(true_labels, predictions) %>%
    count() %>%
    group_by(true_labels) %>%
    mutate(sample = sum(n),
           share = n/sum(n),
           category = if_else(true_labels == predictions, 1, 0),
           run = i)
  
  data = append(data, list(df))
  
}

df_predictive_power = purrr::reduce(data, bind_rows) %>%
  group_by(true_labels, category) %>%
  summarize(share_mean = mean(share),
            share_sd = sd(share)) %>%
  ungroup()


ggplot() + theme_bw() + 
  geom_bar(data = df_predictive_power[df_predictive_power$category == 1, ], aes(x = true_labels, y = share_mean), stat = "identity", fill = "darkseagreen", alpha = .5, color = "black") +
  geom_errorbar(data = df_predictive_power[df_predictive_power$category == 1,], aes(x = true_labels, ymin = share_mean - share_sd, ymax = share_mean + share_sd), width = .25) +
  scale_x_discrete(expand = c(0,0.25)) +
  scale_y_continuous(expand = c(0,0))


### Partial dependence plots

n_features = 27

data = list()

for (i in seq(1,8)) {
  for (s in c("ssp585_2015_2040", "picontrol_2015_2040")) {
    for (f in seq(0, n_features)) {
      df = read_csv(paste0("data/random_forest/results/", s, "_seed_", i, "_mode_both_k_10_m4_pdp_results_feature_", f, ".csv")) %>%
        pivot_longer(cols = c("Prob_-1", "Prob_0", "Prob_1"), names_to = "feature", values_to = "probability") %>%
        mutate(run = i,
               s = s, 
               f = f)
      
      data = append(data, list(df))
    }
  }
}


df_pdp = purrr::reduce(data, bind_rows)

ggplot() + theme_bw() +
  geom_line(data = df_pdp, aes(x = Feature_Value, y = probability, color = feature, 
                           group = interaction(run, feature, s), linetype = s)) +
  scale_x_continuous(expand = c(0,0)) +
  scale_y_continuous(expand = c(0,0)) +
  facet_wrap(~ f, scales = "free", ncol = 9)

### Relative importance

data = list()

for (i in seq(1,8)) {
  df = read_csv(paste0("data/random_forest/results/ssp585_2015_2040_seed_", i, "_mode_both_k_10_m4_sfs_results.csv")) %>%
    mutate(values = gsub("\\[|\\]", "", Codes)) %>%
    separate(values, into = c("first", "second", "third", "fourth", "fifth"), sep = ", ", convert = TRUE) %>%
    mutate(run = i) %>%
    select(c(first, second, third, fourth, fifth), run)
  
  data = append(data, list(df))
}

feature_importance = purrr::reduce(data, bind_rows) %>%
  pivot_longer(cols = c(first, second, third, fourth, fifth))

ggplot() + theme_bw() +
  geom_point(data = feature_importance, aes(x = name, y = value, color = as.factor(run)), 
             size = 2, alpha = .8, position = position_jitter(width = 0.1, height = 0.1)) +
  scale_x_discrete(expand = c(0,0), name = "Importance of feature") +
  scale_y_continuous(expand = c(0,0), name = "Feature")

            