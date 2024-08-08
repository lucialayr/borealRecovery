library(tidyverse)

install.packages("scico")
library(scico)

setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")

df_lpj1 = readr::read_table("data/ssp370_d150/cmass.out") %>%
  filter(Year == 2005)


df = readr::read_table("data/ABOVE_agb_lpjformat.txt") 

names(df) = c("Lon", "Lat", "data")

df_old = readr::read_table("data/spinup_cmass_2005.out")

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
  mutate(data = data*0.064) %>%
  right_join(df_lpj) %>%
  mutate(diff = Total - data)

ggplot() + geom_tile(data = df_diff, aes(x = Lon, y = Lat, fill = diff)) +
  scico::scale_fill_scico(palette = "vik", midpoint = 0)

##decision: model is higher than data and interestingly also higher than in last study, even thought in last study disturbance probably was lower
# I took the .ins file from last study so only thing it could be is nitrogen deposition. Also i did not start from state so maybe it is also due to stochasticity.
# anyways, I will move forward from here as it looks ok and the higher values in the model can be explained by 1) the lack of fire 2) the lack of land use and 3) the low disturbances intervall
