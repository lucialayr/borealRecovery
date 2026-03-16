library(here)
source(here("code", "utils.R"))

library(duckdb)
library(tidyverse)

con = dbConnect(duckdb(), dbdir = here("patches3.duckdb"), read_only = FALSE) #create the database
dbListTables(con) #check, should be empty

read_write_dataset_var = function(configuration, run, variable) {
  print(paste(configuration, "run", run, " for variable ", variable))
  
  configuration = as.character(configuration)
  variable = as.character(variable)
  
  df = readr::read_table(paste0(here("data", "", configuration, "/run", run, "/vegstruct_patch.out"), show_col_types = F) %>%
    filter(!is.na(Year)) %>%
    dplyr::select(Year, age, Lon, Lat, PID, PFT, !!rlang::sym(variable)) %>%
    pivot_wider(names_from = PFT, values_from = !!rlang::sym(variable)) %>%
    mutate(across(everything(), ~replace_na(.x, 0))) %>% # add in 0 where PFT is NA because not present
    mutate(Tundra = C3G +  HSE + HSS + LSS + LSE + GRT + EPDS + SPDS + CLM) %>% #aggegate Tundra PFTs
    dplyr::select(-c("C3G",  "HSE", "HSS", "LSS", "LSE", "GRT", "EPDS", "SPDS", "CLM")) %>%
    mutate(dhist = !sign(age)) %>% #calculate dhist
    group_by(Lon, Lat, PID) %>%
    mutate(ndist = cumsum(dhist)) %>% #calculate ndist
    pivot_longer(cols = -c(Year, Lon, Lat, PID, dhist, ndist, age), names_to = "PFT", values_to = variable) #bring back in long format
  
  
  dbWriteTable(con, paste0(configuration, "_", variable), df, append = T) 
  
  rm(df)
  
  gc()
  
  return("sucessful")
  
} #function to load one run folder of one scenario

s = c("picontrol") #specify scenarios
d = c("150") #specify disturbance of scenario
v = c("anpp",  "exp_est", "fpc") #specify variables 

# adapted to read in npp data
configurations = paste0(s, "_d", d, "_npp")  #create scenario tags. might need to be adapted if folder is namees differently

input = expand.grid(run = seq(1, 160), vars = v, scenario = configurations) #create a table with all unique combinations of scenario, run folder and variable

purrr::pmap(input, ~ read_write_dataset_var(..3, ..1, ..2)) #give table and function to purrr to map over all combinations


#rename files

for (s in s) {
  for (v in v) {
    # Construct the SQL query as a single string
    query = paste0("ALTER TABLE ", s, "_d150_npp_", v, " RENAME TO ", s, "_d150_", v)
    
    # Execute the query
    dbExecute(con, query)
  }
}
