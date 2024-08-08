library(duckdb)
library(tidyverse)

setwd("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper")

con = dbConnect(duckdb(), dbdir = "wednesdayLSAI.duckdb", read_only = FALSE) #create the database
dbListTables(con)

recdad_write_dataset_var = function(configuration, run) {
  print(paste(configuration, "run", run))
  df = read.table(paste0("data/", configuration, "/run", run, "/vegstruct_patch.out"), header = T) %>%
    filter(!is.na(Year))
  
  dbWriteTable(con, paste0(configuration), df, append = T) 
  
  return("sucessful")
  
}

poss_read_write = possibly(.f = read_write_dataset_var, otherwise = "Error")

s = c("ssp126")
d = c("150")

configurations = expand.grid(s, d) %>%
  mutate(c = paste0(Var1, "_d", Var2)) %>%
  select(c)

purrr::map2(rep(configurations$c, each = 48), rep(seq(113, 160), times = 1*1), ~poss_read_write(.x, .y))


df = dbGetQuery(con, paste0("SELECT * FROM 'ssp126_d150' WHERE Year = 2100 AND PFT = 'BNE'"))
write_csv(df, "ssp370_d0.003333333_patches.csv")


dbExecute(con, "EXPORT DATABASE 'export'")

con_new <- dbConnect(duckdb::duckdb(), dbname = "new_database.db")
dbExecute(con_new, "IMPORT DATABASE 'wednesdayLSAI.dump'")

dbListTables(con_new)

df = dbGetQuery(con_new, paste0("SELECT Year FROM 'ssp370_d0.003333333'"))
