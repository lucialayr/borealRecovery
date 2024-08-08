setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(tidyverse)
library(stats)
library(zoo)

install.packages("scico")
library(scico)


## year disturbance needs to be fixed!!
get_veggie_data = function(s) {
  df = read_csv(paste0("data/processed/trajectories_", s, "_2015_2040_cmass_200.csv")) %>%
    filter(age %in% seq(91, 100)) %>%
    group_by(Lon, Lat, PID, age) %>%
    mutate(dominant_pft = PFT[which.max(relative)]) %>%
    ungroup() %>%
    select(Lon, Lat, PID, year_disturbance, age, dominant_pft) %>%
    unique() %>%
    group_by(Lon, Lat, PID, year_disturbance, dominant_pft) %>%
    count() %>%
    mutate(class = case_when(dominant_pft == "IBS" & n == 10 ~1,
                             dominant_pft == "BNE" & n == 10 ~ 0,
                             T ~ NA)) %>%
    mutate(s = s) %>%
    filter(!is.na(class))
  
  
  return(df)
}

get_climate_data = function(df, s, start_year, window) {
  
  climate = read_csv(paste0("data/processed/covariates_", s, "_2015_2040_growingseason.csv")) %>%
    select(Lon, Lat, Year, tas_gs_dailyavg) %>%
    group_by(Lon, Lat) %>%
    mutate(tas_smoothed = rollmean(tas_gs_dailyavg, k = window, fill = NA, align = "left"), #from start year into the future
           timespan_climate = paste0("T for ", start_year, " - ", start_year + window, " years after disturbance"))
  
  df = df %>%
    select(Lat, Lon, PID, year_disturbance, class, s) %>%
    ungroup() %>%
    rename(Year = year_disturbance) %>%
    unique() %>%
    left_join(climate) %>%
    mutate(class_factor = as.factor(class)) %>%
    filter(!is.na(tas_gs_dailyavg))
  
  return(df)
  
}




fit_model = function(df) {
  
  model = glm(class ~ tas_smoothed, data = df, family = binomial)
  
  summary(model)
  
  # Get the coefficients
  coef(model)
  # Calculate the odds ratios
  exp(coef(model))
  
  # get data
  df$predicted_prob = predict(model, type = "response")
  
  df = df %>%
    mutate(aic = AIC(model))
  
  return(df)
}

data_s = list()

for (s in c("ssp585", "ssp126", "picontrol")) {
  df = get_veggie_data(s) %>%
    get_climate_data(s, 0, 100)
  
  data_s = append(data_s, list(df)) 
}

df_all = purrr::reduce(data_s, bind_rows) %>%
  mutate(s = long_names_scenarios(s))

bin_width = 0.1

result = df_all %>%
  mutate(T_bin = floor(tas_smoothed / bin_width) * bin_width) %>%
  group_by(T_bin, class) %>%
  count() %>%
  ungroup() %>%
  complete(T_bin,  class, fill = list(n = 0)) %>%
  group_by(T_bin,) %>%
  complete() %>%
  mutate(total = sum(n),
         prob = n/sum(n)) %>%
  replace(is.na(.), 0) %>%
  filter(class == 1)

ggplot() + theme_bw() +
  geom_point(data = df_all, aes(x = tas_smoothed, y = class, color = s), 
             position = position_jitter(width = 0, height = 0.05), alpha = .25,  size = 0.5) +
  geom_point(data = result, aes(x = T_bin, y = prob)) +
  scale_x_continuous(name = "Mean growing season T of trajectory", expand = c(0,0)) +
  scale_y_continuous(name = "P(Deciduous transient)", breaks = c(0, .5, 1), expand = c(0,0),
                     sec.axis = sec_axis(~ . * 1, breaks = c(0, 1), labels = c("Direct \nconifer \nregeneration", "Deciduous \ntransient"))) +
  scico::scale_color_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Climate scenario") +
  #add_common_layout(fontsize = 15) +
  theme(axis.text = element_text(size = 15),
        axis.title =  element_text(size = 15),
        legend.position = "bottom",
        legend.direction = "horizontal",
        legend.text = element_text(size = 13),
        legend.title = element_text(size = 15)) +
  guides(color = guide_legend(override.aes = list(alpha = 1, size = 2)))

ggsave("figures/probability_transient.png")




##########
(p1 = ggplot(data = df_all) +
  geom_point(aes(x = tas_smoothed, y = class, color = class_factor, shape = s), 
             position = position_jitter(width = 0, height = 0.25), alpha = .25, hjust = 0.1, size = 2) +
  geom_smooth(method = "glm", aes(x = tas_smoothed, y = predicted_prob), method.args = list(family = binomial), se = FALSE, color = "grey30") +
  scale_color_manual(name = "Recovery trajectory", values = c("0" = "#0072B2", "1" = "#E69F00")) +
  scale_x_continuous(name = "Average temperature growing season", expand = c(0,0)) +
  scale_y_continuous(name = "Recovery type", breaks = c(0, 1), labels = c("Direct replacement", "Deciduous transient"), expand = c(0,0),
                     sec.axis = sec_axis(~ . * 1, breaks = c(0, 0.5, 1), name = ("P(deciduous transient)"))) +
  facet_wrap( ~ timespan_climate) +
  add_common_layout(fontsize = 15) +
  theme(legend.position = "None"))
