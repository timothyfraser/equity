# demo2.R

# Script to download 10 random counties' data from CATSERVER from 2 states
# New York and New Jersey

library(dplyr)
library(readr)
library(purrr)
library(ggplot2)
library(sf)

source("demo/retrieve_data.R")

fips = tigris::fips_codes %>%
  filter(state_code %in% c("36",  "34"))  %>%
  mutate(geoid = paste0(state_code, county_code)) %>%
  select(geoid, county) %>%
  sample_n(size = 10)

fips %>%
  split(.$geoid) %>%
  map_dfr(~retrieve_data(
  geoid = .$geoid, year = c(2020, 2025, 2030),
  var = "emissions", covvar = c("pop", "pop_black", "pop_asian", "pop_hisplat"),
  pollutant = 98, aggregation = 16)) %>%
  saveRDS("demo/data.rds")

