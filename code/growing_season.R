setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(tidyverse)
install.packages("scico")
library(scico)

data = list()
v = "mgpp"

for (s in c("ssp585", "ssp126", "picontrol")) {
  df = read_table(paste0("data/", s, "_d150_npp/", v, ".out")) %>%
    pivot_longer(cols = -c(Lon, Lat, Year), names_to = "month") %>%
    filter(Year %in% c(2070, 2100)) %>%
    group_by(Lon, Lat, month) %>%
    summarise(mean = mean(value),
              sd = sd(value)) %>%
    mutate(s = s)
  
  data = append(data, list(df))
}

df = purrr::reduce(data, bind_rows) %>%
  mutate(month = tolower(month)) 

df$month = factor(df$month, levels = c("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"))

ggplot() + theme_bw() +
  scale_y_continuous(expand = c(0,0)) +
  scale_x_discrete(expand = c(0,0)) +
  geom_jitter(data = df, aes(x = month, y = mean, color = s, group = interaction(Lon, Lat,s)), shape = 4, size = .25, alpha = .25, height = 0) +
  geom_hline(yintercept = 0, color = "black") +
  scico::scale_color_scico_d(palette = "managua")
