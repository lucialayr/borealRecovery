# Helper function to build correct table names
get_table_name = function(scenario, variable) {
  if (scenario == "picontrol") {
    return(paste0(scenario, "_d150_npp_", variable))
  } else {
    return(paste0(scenario, "_d150_", variable))
  }
}

summarize_pfts = function(df) {
  df = df %>%
    mutate(bne = bne + bine,
           tundra = (c3g + hse + hss + lse + lss + grt + epds + spds + clm) ) %>% 
    select(-bine,  -c3g, -hse, -hss, -lse, -lss,  -grt, -epds, -spds, -clm)
  
  return(df)
}

check_and_fill_pfts = function(df) {
  df = df %>%
    mutate(bine = {if("bine" %in% names(.)) bine else 0},
           bne = {if("bne" %in% names(.)) bne else 0},
           ibs = {if("ibs" %in% names(.)) ibs else 0},
           tebs = {if("tebs" %in% names(.)) tebs else 0},
           tene = {if("tene" %in% names(.)) tene else 0},
           bns = {if("bns" %in% names(.)) bns else 0},
           c3g = {if("c3g" %in% names(.)) c3g else 0},
           hse = {if("hse" %in% names(.)) hse else 0},
           hss = {if("hss" %in% names(.)) hss else 0},
           lse = {if("lse" %in% names(.)) lse else 0},
           lss = {if("lss" %in% names(.)) lss else 0},
           grt = {if("grt" %in% names(.)) grt else 0},
           epds = {if("epds" %in% names(.)) epds else 0},
           spds = {if("spds" %in% names(.)) spds else 0},
           clm = {if("clm" %in% names(.)) clm else 0})
  return(df)
}


long_names_pfts = function(x) {
  x = gsub("ibs", "Pioneering broadleaf", x)
  x = gsub("tebs", "Temperate broadleaf", x)
  x = gsub("bne", "Needleleaf evergreen", x)
  x = gsub("bine", "Shade-intolerant\nneedleleaf evergreen", x)
  x = gsub("bns", "Needleleaf summergreen", x)
  x = gsub("tene", "Temperate needleleaf", x)
  x = gsub("tundra", "Non-tree V.", x)
  x = gsub("soil", "Bare soil", x)
  x = gsub("mixed forest", "Mixed forest", x)
  x = gsub("otherc", "Conifers (other)", x)
  x = gsub("regeneration failure", "Regeneration failure", x)
  return(x)
}

long_names_pfts_species = function(x) {
  x = gsub("ibs", "Pioneering broadleaf \n(Birch, Aspen)", x)
  x = gsub("tebs", "Temperate broadleaf \n(Maple, Beech)", x)
  x = gsub("bne", "Needleleaf evergreen \n(Spruce)", x)
  x = gsub("bine", "Shade-intolerant\nneedleleaf evergreen", x)
  x = gsub("bns", "Needleleaf summergreen", x)
  x = gsub("tene", "Temperate needleleaf", x)
  x = gsub("tundra", "Non-tree V. \n(Shrubs, Grasses)", x)
  x = gsub("soil", "Bare soil", x)
  x = gsub("mixed forest", "Mixed forest", x)
  x = gsub("otherc", "Conifers (other) \n(Pine, Larch)", x)
  x = gsub("regeneration failure", "Regeneration failure", x)
  return(x)
}

long_names_pfts_twolines = function(x) {
  x = gsub("ibs", "Pioneering\nbroadleaf", x)
  x = gsub("tebs", "Temperate\nbroadleaf", x)
  x = gsub("bne", "Needleleaf\nevergreen", x)
  x = gsub("bine", "Shade-intolerant\nneedleleaf evergreen", x)
  x = gsub("bns", "Needleleaf\nsummergreen", x)
  x = gsub("tene", "Temperate\nneedleleaf", x)
  x = gsub("tundra", "Non-tree V.", x)
  x = gsub("soil", "Bare soil", x)
  x = sub("mixed", "Mixed \n(none > 50 %)")
  return(x)
}

long_names_to_species = function(x) {
  x = gsub("Pioneering broadleaf", "Pioneering broadleaf \n(Birch, Aspen)", x)
  x = gsub("Temperate broadleaf", "Temperate broadleaf \n(Maple, Beech)", x)
  x = gsub("Needleleaf evergreen", "Needleleaf evergreen \n(Spruce)", x)
  x = gsub("Tundra", "Non-tree V. \n(Shrubs, Grasses)", x)
  x = gsub("Conifers (other)", "Conifers (other) \n(Pine, Larch)", x)
}

long_names_scenarios = function(x) {
  x = gsub(" control", " Historic", x)
  x = gsub("picontrol", "Control", x)
  x = gsub("ssp126", "SSP1-RCP2.6", x)
  x = gsub("ssp370", "SSP3-RCP7.0", x)
  x = gsub("ssp585", "SSP5-RCP8.5", x)
  
  return(x)
}

long_names_scenarios_twolines = function(x) {
  x = gsub(" control", " Historic", x)
  x = gsub("picontrol", "Control", x)
  x = gsub("ssp126", "SSP1-\nRCP2.6", x)
  x = gsub("ssp370", "SSP3-\nRCP7.0", x)
  x = gsub("ssp585", "SSP5-\nRCP8.5", x)
  
  return(x)
}



subgrid_location = function(df) {
  df = df %>%
    mutate(Dx = case_when(PID %in% c(0, 5, 10, 15, 20) ~ -0.2,
                          PID %in% c(1, 6, 11, 16, 21) ~ -0.1,
                          PID %in% c(2, 7, 12, 17, 22) ~    0,
                          PID %in% c(3, 8, 13, 18, 23) ~  0.1,
                          PID %in% c(4, 9, 14, 19, 24) ~  0.2),
           Dy = case_when(PID %in% seq(0 ,  4) ~ -0.2,
                          PID %in% seq(5 ,  9) ~ -0.1,
                          PID %in% seq(10, 14) ~    0,
                          PID %in% seq(15, 19) ~  0.1,
                          PID %in% seq(20, 24) ~  0.2),
           Lon_PID = Lon + Dx,
           Lat_PID = Lat + Dy)
  
  return(df)
}

load_basemap = function(epsg = "EPSG:3408") {
  
  shp_coastline <<- ne_coastline(scale = "medium", returnclass = "sf")  %>%
    st_transform(crs = epsg) %>%
    st_crop(xmin = -4555364, xmax = 4366954, ymin = -3429227, ymax = 3981392 )
  shp_countries <<- ne_countries(scale = "medium", returnclass = "sf")  %>%
    st_transform(crs = epsg) %>%
    st_make_valid() %>%
    st_crop(xmin = -4555364, xmax = 4366954, ymin = -3429227, ymax = 3981392 )
}

add_basemap = function() {
  list(geom_sf(data=shp_countries, fill = "grey95", color="grey95", linewidth = .0),
       geom_sf(data=shp_coastline, colour = "grey40", linewidth = .15))
}

# Only set theme if ggplot2 is loaded
if ("ggplot2" %in% loadedNamespaces()) {
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
}
