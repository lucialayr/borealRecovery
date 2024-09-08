setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")
source("code/utils.R")

library(tidyverse)
library(stats)
library(zoo)
library(splines)

install.packages("scico")
install.packages("cowplot")
library(cowplot)
library(scico)

install.packages("ggnewscale")
library(ggnewscale)

install.packages("rnaturalearth")
install.packages("rnaturalearthdata")
library(rnaturalearth)
library(rnaturalearthdata)

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




s = "ssp585"
variable = "cmass"
start_year = 2015
end_year = 2040


classify_trajectories = function(s, start_year, end_year) {
  
  df_dominant = read_csv(paste0("data/processed/trajectories_", s, "_", start_year, "_", end_year, "_timeseries_rf.csv"))  %>%
    filter(age < 101) %>%
    group_by(Lon, Lat, PID, age) %>%
    mutate(max_relative = max(relative)) %>%
    filter(max_relative == relative) %>%
    ungroup() %>%
    rename(dominant_pft = PFT) %>%
    group_by(Lon, Lat, PID, age) %>%
    filter(sum(cmass) > 0) %>%
    ungroup()
  
  test = read_csv(paste0("data/processed/trajectories_", s, "_", start_year, "_", end_year, "_timeseries_rf.csv"))
  
  test_filter = test %>%
    group_by(Lon, Lat, PID, year_disturbance) %>%
    filter(age == max(age))
  
  df_c1 = df_dominant %>%
    filter(age %in% seq(90, 100) & dominant_pft == "BNE") %>%
    group_by(Lon, Lat, PID) %>%
    count() %>%
    filter(n > 5) %>%
    mutate(c1 = 1) %>%
    dplyr::select(-n) %>%
    unique()
  
  df_c2 = df_dominant %>%
     filter(age %in% seq(10, 100)) %>%
     arrange(Lon, Lat, PID, age) %>%
     group_by(Lon, Lat, PID) %>%
     mutate(ibs = if_else(dominant_pft == "IBS", 1, 0),
            length_transient = cumsum(ibs)*ibs,
            s = "ssp585") %>%
     group_by(Lon, Lat, PID) %>%
     filter(length_transient == max(length_transient)) %>% #we have not yet catched presence of two transient but we assume we will catch the longest one
     dplyr::select(Lon, Lat, PID, length_transient) %>%
     unique()  %>%
    mutate(c2 = if_else(length_transient > 10, 1, 0))
  
  check = df_c2 %>%
    filter(Lon == -93.25 & Lat == 52.25 & PID == 20)

  df_c3 = df_dominant %>%
    filter(age %in% seq(90, 100) & dominant_pft == "IBS") %>%
    group_by(Lon, Lat, PID) %>%
    count() %>%
    filter(n > 5) %>%
    mutate(c3 = 1) %>%
    dplyr::select(-n) %>%
    unique()
  
  
  df_c4 = df_dominant %>%
    filter(age %in% seq(90, 100) & dominant_pft %in% c("IBS", "BNE")) %>%
    group_by(Lon, Lat, PID) %>%
    count() %>%
    filter(n > 5) %>%
    mutate(c4 = 1) %>%
    dplyr::select(-n) %>%
    unique()
  
  #Classification
  
  # labels 0,1,2
  # Criteria 1: BNE is dominant in years 90-100
  # Criteria 2: IBS is dominant is atleast 10 consecutive years 10-90
  # Criteria 3: IBS is dominant in years 90-100
  # Criteria 4: IBS then BNE is dominant in years 90-100
  
  # Class 0 C1 == True, C2==False
  # Class 1 C2 == True and (C1==True or C3==True)
  # Class 2 Rest
    
    
  df = df_dominant %>%
    dplyr::select(Lon, Lat, PID, year_disturbance) %>%
    unique() %>%
    full_join(df_c1) %>%
    full_join(df_c2) %>%
    full_join(df_c3) %>%
    full_join(df_c4) %>%
    mutate(across(everything(), ~ifelse(is.na(.), 0, .))) %>%
    mutate(class = case_when(c1 == 1 & c2 == 0 ~ 0,
                             c2 == 1 & (c1 == 1 | c3 == 1) ~ 1,
                             T ~ 2),
           s = s)

  
  return(df)
  
  
}

get_climate_data = function(df, s, start_age, window, start_year, end_year) {
  
  climate = read_csv(paste0("data/processed/covariates_", s, "_", start_year, "_", end_year, "_growingseason.csv")) %>%
    dplyr::select(Lon, Lat, Year, tas_gs_dailyavg) %>%
    group_by(Lon, Lat) %>%
    mutate(tas_smoothed = rollmean(tas_gs_dailyavg, k = window, fill = NA, align = "left"), #from start year into the future
           timespan_climate = paste0("T for ", start_age, " - ", start_age + window, " years after disturbance"))
  
  df = df %>%
    dplyr::select(Lat, Lon, PID, year_disturbance, class, s, length_transient) %>%
    ungroup() %>%
    rename(Year = year_disturbance) %>%
    unique() %>%
    left_join(climate) %>% #join to filter for only year of disturbanced + 100 value
    mutate(class_factor = as.factor(class)) %>%
    filter(!is.na(tas_gs_dailyavg))
  
  return(df)
  
}

create_data = function(start_year, end_year) {
  data = list()
  
  for (s in c("ssp585", "ssp126", "picontrol")) {
    
    df = classify_trajectories(s, start_year, end_year) %>%
      get_climate_data(s, 0, 10, start_year, end_year)
    
    data = append(data, list(df))
    
  }
  
  df = purrr::reduce(data, bind_rows) %>%
    mutate(s = long_names_scenarios(s),
           tas_smoothed = tas_smoothed) 
  
  write_csv(df, paste0("data/results/all_binary_data_", start_year, "_", end_year,".csv"))
  
  return(df)
}

add_model_to_data = function(df, model, model_string) {
  
  df = df %>%
    filter(class != 2) %>%
    mutate(aic = AIC(model),
           predicted_probability = predict(model, type = "response"),
           model_type = model_string)
  
  return(df)
}

fit_binary_data = function(df, start_year, end_year) {
  
  df = df %>%
    filter(class != 2) #filter out trajectories that are in neither category
  
  null_model = glm(class ~ 1, data = df, family = binomial)
  linear_model = glm(class ~ tas_smoothed, data = df, family = binomial)
  
  df = df %>%
    mutate(T_273 = ifelse(tas_smoothed > 273, tas_smoothed - 273 , 0),
           T_275 = ifelse(tas_smoothed > 275 , tas_smoothed - 275 , 0),
           T_277 = ifelse(tas_smoothed > 277 , tas_smoothed - 277 , 0))
  
  piecewise_model_273 = glm(class ~ tas_smoothed + T_273, data = df, family = binomial)
  piecewise_model_275 = glm(class ~ tas_smoothed + T_275, data = df, family = binomial)
  piecewise_model_277 = glm(class ~ tas_smoothed + T_277, data = df, family = binomial)
  spline_model = glm(class ~ ns(tas_smoothed, df = 4), data = df, family = binomial)
  
  df_null = add_model_to_data(df, null_model, "null_model")
  df_linear = add_model_to_data(df, linear_model, "linear_model")
  df_piecewise_273 = add_model_to_data(df, piecewise_model_273, "piecewise_model_273")
  df_piecewise_275 = add_model_to_data(df, piecewise_model_275, "piecewise_model_275")
  df_piecewise_277 = add_model_to_data(df, piecewise_model_277, "piecewise_model_277")
  df_spline = add_model_to_data(df, spline_model, "spline_model")
  
  df_models = purrr::reduce(list(df_null, df_linear, df_piecewise_273, df_piecewise_275, df_piecewise_277, df_spline),
                            bind_rows)
  
  df_aic = df_models %>%
    dplyr::select(model_type, aic) %>%
    unique() %>%
    arrange(aic)
  
  print(df_aic)
  
  write_csv(df_aic, paste0("data/results/aic_binary_data_", start_year, "_", end_year, ".csv"))
  
  
  cairo_pdf(paste0("figures/results/models_binary_data_", start_year, "_", end_year , ".pdf"), height = 5)
  print(ggplot() + theme_bw() +
          geom_line(data = df_models, aes(x = tas_smoothed, y = predicted_probability, color = model_type, linetype = model_type), linewidth = 1, alpha = .8) +
          scale_x_continuous(name = "Growing season temperature, averaged over trajectory", expand = c(0,0)) +
          scale_y_continuous(name = "P(deciduous transient)", expand = c(0,0), 
                             breaks = c(0, 0.5, 1)) +
          scico::scale_colour_scico_d(name = "Models") +
          scale_linetype_manual(name = "Models", values = c("dashed", "dotted", "dashed", "solid", "dashed", "dotted")) +
          theme(axis.text = element_text(size = 15),
                axis.title =  element_text(size = 15),
                legend.background = element_rect(fill='transparent', color = NA),
                legend.box.background = element_rect(fill='transparent', color = NA),
                panel.background = element_rect(fill = "transparent", colour = NA),  
                plot.background = element_rect(fill = "transparent", colour = NA),
                strip.background = element_rect(fill = "transparent", color = NA),
                legend.position = "bottom",
                legend.direction = "vertical",
                legend.text = element_text(size = 13),
                legend.title = element_text(size = 15)))
  dev.off()
  
  df_best_fit = df_models %>%
    filter(aic == min(aic))
  
  write_csv(df_models, paste0("data/results/results_all_binary_data_", start_year, "_", end_year, ".csv"))
  
  return(df_best_fit)
  
}

create_plot_scaled = function(start_year, end_year) {
  
  if (file.exists(paste0("data/results/all_binary_data_", start_year, "_", end_year,".csv"))) {
    df = read_csv(paste0("data/results/all_binary_data_", start_year, "_", end_year,".csv"))
  } else {
    df = create_data(start_year, end_year)
  }
  
  df_logistic = fit_binary_data(df, start_year, end_year)
  
  df_log = df %>%
    filter(PID > 15) %>%
    mutate(length_transient_trans = if_else(length_transient == 0, 0, 0.5*log10(length_transient))) #transform transient length to log scale
  
  (p1 = ggplot() +
    geom_hline(yintercept = 0.5, color = "grey", linewidth = 1) +
    geom_point(data = df_log[df_log$class == 2,], aes(x = tas_smoothed, y = length_transient_trans), size = 0.75,
               color = "darkgrey",  position = position_jitter(width = 0, height = 0.025)) +
    geom_point(data = df_log[df_log$class == 0,], aes(x = tas_smoothed, y = length_transient_trans, color = s), size = 0.75,
               position = position_jitter(width = 0, height = 0.025)) +
      scico::scale_color_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer recovery \n(transient < 10 years)", direction = -1) +
      guides(color = guide_legend(override.aes = list(size = 4))) +
    ggnewscale::new_scale_color() +
    geom_point(data = df_log[df_log$class == 1,], aes(x = tas_smoothed, y = length_transient_trans, color = s), size = 0.75) +
    scico::scale_color_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Decidous transient \n> 10 years", direction = -1) +
    geom_line(data = df_logistic, aes(x = tas_smoothed, y = predicted_probability), linewidth = 1) +
    scale_x_continuous(name = "Growing season temperature in °C, averaged over trajectory", expand = c(0, 0),
                       breaks = c(271, 273, 275, 278, 283), labels = c(271 - 273, 273 - 273, 275 - 273, 278 -273, 283 - 273)) +
    scale_y_continuous(name = "Length of deciduous transient in years", expand = c(0,0), breaks = c(0, 0.25, .5, 0.75, 1), labels = c(0, 5, 10, 50, 100), limits = c(0, 1),
                       sec.axis = sec_axis(~., name = "P(Deciduous transient > 10 years)", breaks = c(0, 0.5, 1), labels = c(0, 0.5, 1))) +
    theme(legend.position = "bottom",
          legend.direction = "vertical") +
      guides(color = guide_legend(override.aes = list(size = 4))))
  
  
  return(p1)
}

create_plot_linear = function(start_year, end_year) {
  
  df = create_data(start_year, end_year)
  
  df_logistic = fit_binary_data(df, start_year, end_year)
  
  df_log = df %>%
    filter(PID > 15) %>%
    mutate(length_transient_trans = if_else(length_transient == 0, 0, 0.5*log10(length_transient))) #transform transient length to log scale
  
  (p = ggplot() + 
      geom_hline(yintercept = 10, color = "grey", linewidth = 1) +
      geom_point(data = df[df$class == 2,], aes(x = tas_smoothed, y = length_transient), size = 0.25,
                 color = "darkgrey",  position = position_jitter(width = 0, height = 2)) +
      geom_point(data = df[df$class == 0,], aes(x = tas_smoothed, y = length_transient, color = s), size = 0.25,
                 position = position_jitter(width = 0, height = 2)) +
      scico::scale_color_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer recovery \n(transient < 10 years)", direction = -1) +
      guides(color = guide_legend(override.aes = list(size = 2))) +
      ggnewscale::new_scale_color() +
      geom_point(data = df[df$class == 1,], aes(x = tas_smoothed, y = length_transient, color = s), size = 0.25) +
      scico::scale_color_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Decidous transient \n> 10 years", direction = -1) +
      scale_x_continuous(name = "Growing season temperature in °C, averaged over trajectory", expand = c(0, 0),
                         breaks = c(271, 273, 275, 278, 283), labels = c(271 - 273, 273 - 273, 275 - 273, 278 -273, 283 - 273)) +
      scale_y_continuous(name = "Length of deciduous transient in years", expand = c(0,0), breaks = c(0, 10, 50, 100), labels = c(0, 10, 50, 100), limits = c(0, 100)) +
      theme(legend.position = "bottom",
            legend.direction = "vertical") +
      guides(color = guide_legend(override.aes = list(size = 2))))
  
  return(p)
}

location_of_classes = function(start_year, end_year) {
  
  if (file.exists(paste0("data/results/classes_100years_", start_year, "_", end_year, ".csv"))) {
    
    df = read_csv(paste0("data/results/classes_100years_", start_year, "_", end_year, ".csv"))
    
  } else {
    data = list()
    
    for (s in c("ssp585", "ssp126", "picontrol")) {
      
      df = classify_trajectories(s, start_year, end_year)
      
      data = append(data, list(df))
      
    }
    
    df = purrr::reduce(data, bind_rows)
    
    write_csv(df, paste0("data/results/classes_100years_", start_year, "_", end_year, ".csv"))
  }
  
  
  
  df_sf = df %>%
    st_as_sf(coords = c("Lon", "Lat"), crs = 4326) %>%
    mutate(s = long_names_scenarios(s))
  
  
  #basemap
  load_basemap()
  
  #study region
  study_region = st_read("data/external/vegetation_ssp585_d0.003_fpc_30years2100.shp") %>%
    st_make_valid() %>%
    st_union() %>%
    st_geometry() %>%
    st_transform(., crs = 3408) 
  
  #color are obtained from 
  #scico::scale_fill_scico_d(name = "Realized niche per scenario", palette = "lajolla", begin = .2, end = .8, direction = -1) +
  
  (p2 = ggplot() + 
      add_basemap() +
      geom_sf(data = study_region, color = "black", fill = "grey", linewidth = 0.05) +
      geom_sf(data = df_sf[df_sf$class == 2 & df_sf$PID %in% seq(10, 14), ], color = "grey40", size = .005, shape = 20) +
      geom_sf(data = df_sf[df_sf$class == 0 & df_sf$PID %in% seq(10, 16), ], aes(color = s), size = .005, shape = 20) +
      scico::scale_color_scico_d(palette = "lapaz", begin = .1, end = .5, name = "Direct conifer replacement \n(transient < 10 years)", direction = -1) +
      guides(color = guide_legend(override.aes = c(size = 3))) +
      ggnewscale::new_scale_color() +
      geom_sf(data = df_sf[df_sf$class == 1 & df_sf$PID %in% seq(10, 16), ], aes(color = s), size = .005, shape = '.') +
      scico::scale_color_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Decidous transient \n> 10 years", direction = -1) +
      scale_x_continuous(expand = c(0,0)) +
      scale_y_continuous(expand = c(0,0)) +
      facet_wrap(~s, ncol = 1, strip.position="right") +
      theme(legend.position = "bottom",
            legend.direction = "vertical") +
      guides(color = guide_legend(override.aes = c(size = 3)))) # second fill guide, order ensures it goes to new line
  
  
  ggsave(paste0("figures/results/map_classes_", start_year, "_", end_year, ".pdf"), height = 5)
  
  return(p2)
  
}

#########################
#########################

start_year = 2015
end_year = 2040

(p1 = create_plot_scaled(start_year, end_year))

(p2 = location_of_classes(start_year, end_year))

plot_grid(p2 + theme(legend.position = "None"), 
          p1 , 
          rel_widths = c(0.5, 1), labels = c("(a)", "(b)"), 
          ncol = 2, hjust = 0)

ggsave(paste0("figures/results/maps_regression_", start_year, "_", end_year ,".pdf"), height = 6.25, width = 10, scale = 1)


#####

start_year = 2075
end_year = 2100

(p1 = create_plot_scaled(start_year, end_year))

(p2 = location_of_classes(start_year, end_year))


plot_grid(p2 + theme(legend.position = "None"), 
          p1 , 
          rel_widths = c(0.6, 1), labels = c("(a)", "(b)"), 
          ncol = 2, hjust = 0)

ggsave(paste0("figures/results/maps_regression_", start_year, "_", end_year ,".pdf"), height = 6.25, width = 10, scale = 1)


################################
#########################

p1 = create_plot_linear(2015, 2040)
p2 = create_plot_linear(2075, 2100)

plot_grid(p1, p2, nrow = 1, labels = c("(a)", "(b)"), hjust = 0.07)

ggsave("figures/results/transient_length_unscaled.pdf", width = 15)

histograms_length_transient = function() {
  
  df1 = read_csv("data/results/all_binary_data_2015_2040.csv") %>%
    mutate(type = "Transient climate")
  
  df2 = read_csv("data/results/all_binary_data_2075_2100.csv") %>%
    mutate(type = "Equilibrium climate")
  
  df = bind_rows(df2, df1) 
  
  df$type = factor(df$type, levels = c("Transient climate", "Equilibrium climate"))
  
  ggplot() + 
    geom_histogram(data = df[df$length_transient != 0,], aes(x = length_transient, fill = s), color = "black", linewidth = .25, binwidth = 1) +
    scico::scale_fill_scico_d(palette = "lajolla", begin = .2, end = .8, name = "Scenario", direction = -1) +
    facet_wrap(~type, ncol = 1, scales = "free_y") +
    scale_x_continuous(expand = c(0,0), name = "Length of deciduous transient in years", breaks = c(10, 30, 60, 90)) +
    scale_y_continuous(expand = c(0,0), name = "Frequency") +
    theme(legend.position = c(0.15,0.88))
  
  ggsave("figures/results/histogram_transient_length.pdf", width = 10, height = 5.5, scale = 1)
  

  
}
histograms_length_transient()








location_of_classes(2075, 2100)
location_of_classes(2015, 2040)

###
#number of patches per class

df = read_csv("data/results/classes_100years_2015_2040.csv") %>%
  group_by(class, s) %>%
  count()


df = read_csv("data/results/classes_100years_2075_2100.csv") %>%
  group_by(class, s) %>%
  count()
