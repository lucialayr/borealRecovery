timespan = "2015_2040"

df_predictive_power_1 = read_csv(paste0("data/results/predictive_power_", timespan, ".csv")) %>%
  select(s, m, class, share_mean) %>%
  pivot_wider(names_from = c(s, class), values_from = share_mean)

timespan = "2075_2100"

df_predictive_power_2 = read_csv(paste0("data/results/predictive_power_", timespan, ".csv")) %>%
  select(s, m, class, share_mean) %>%
  pivot_wider(names_from = c(s, class), values_from = share_mean)

timespan = "2015_2040"
mean_1 = read_csv(paste0("data/results/predictive_power_", timespan, ".csv")) %>%
  select(share_mean, class) %>%
  group_by(class) %>%
  summarize(mean(share_mean))

timespan = "2075_2100"
mean_2 = read_csv(paste0("data/results/predictive_power_", timespan, ".csv")) %>%
  select(share_mean, class) %>%
  group_by(class) %>%
  summarize(mean(share_mean))


##

timespan = "2015_2040"

importance_ranking_1 = read_csv(paste0("data/results/importance_ranking_", timespan, ".csv")) %>%
  filter(category == "Climate",
         !is.na(n)) %>%
  dplyr::mutate(var = str_extract(names, ".*(?=_[^_]*$)"),
                t = str_extract(names, "[^_]+$")) %>%
  group_by(s, t) %>%
  summarize(n = sum(n, na.rm = F)) %>%
  pivot_wider(names_from = c(s), values_from = n)

timespan = "2075_2100"

importance_ranking_2 = read_csv(paste0("data/results/importance_ranking_", timespan, ".csv")) %>%
  filter(category == "Climate",
         !is.na(n)) %>%
  dplyr::mutate(var = str_extract(names, ".*(?=_[^_]*$)"),
                t = str_extract(names, "[^_]+$")) %>%
  group_by(s, t) %>%
  summarize(n = sum(n, na.rm = F)) %>%
  pivot_wider(names_from = c(s), values_from = n)


