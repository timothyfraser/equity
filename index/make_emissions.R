# make_emissions.R

# Set directory to index folder
setwd(paste0(rstudioapi::getActiveProject(), "/index"))

# Load environmental variables
readRenviron("secret/.env") 

library(dplyr)
library(sf)
library(purrr)
library(readr)
library(stringr)
library(tidyr)
library(censusapi)
library(ggplot2)
library(viridis)

# Load functions
source("functions.R")

read_rds("data/regions_ny_data.rds") %>%
  with(geoid) %>%
  retrieve_emissions(
    geoid = ., year = c(2020, 2025), 
    pollutant = c(98, 2, 3, 31, 33, 100, 106, 107, 110, 116, 117), aggregation = 16, 
    var = "emissions") %>%
  write_csv("test/emissions_all_pollutants.csv")

read_csv("test/emissions_all_pollutants.csv") %>%
  mutate(geoid = stringr::str_pad(geoid, width = 5, side = "left", pad = "0")) %>%
  saveRDS("test/emissions_all_pollutants.rds")
