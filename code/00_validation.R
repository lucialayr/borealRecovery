#initial check again ABoVE data to see if AGC is in the right order of magnitude
#(note: we will not expact it to match exacple due to land use ad disturbance regimes applied,
#that is not the focus of the analysis, this is more a sanity check)


library(tidyverse)

install.packages("scico")
library(scico)

library(here)

df_lpj1 = readr::read_table(here("data", "ssp370_d150", "cmass.out")) %>%
  filter(Year == 2005)


df = readr::read_table(here("data", "ABOVE_agb_lpjformat.txt")) 

names(df) = c("Lon", "Lat", "data")

df_old = readr::read_table(here("data", "spinup_cmass_2005.out"))

df_comp = df %>%
  mutate(data = data*0.064) %>%
  right_join(df_lpj) %>%
  pivot_longer(cols = c(Total, data))


ggplot() + theme_bw() +
  scale_y_continuous(expand = c(0,0), name = "") +
  scale_x_continuous(name = "Above ground carbon in kg/m²", limits = c(0, 11)) + 
  geom_histogram(data = df_comp, aes(x = value, fill = name), color = "grey20", alpha = .9, position = "dodge", bins = 30) +
  scico::scale_fill_scico_d(palette = "lapaz", begin = .3, end = .8, name = "", direction = -1)

df_diff = df %>%
  mutate(data = data*0.05) %>%
  right_join(df_lpj) %>%
  mutate(diff = Total - data)

ggplot() + geom_tile(data = df_diff, aes(x = Lon, y = Lat, fill = diff)) +
  scico::scale_fill_scico(palette = "vik", midpoint = 0)