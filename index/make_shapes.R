# make_shapes.R

# A workspace script for on the fly calculations

# Set directory to index folder
# Run from index/ (cd index && Rscript make_shapes.R); in RStudio, open equity.Rproj first.
if (interactive() && requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) { setwd(paste0(rstudioapi::getActiveProject(), "/index")) }

# Load environmental variables
# CENSUS_API_KEY comes from the environment; a local, gitignored secret/.env is read if present
if (file.exists("secret/.env")) { readRenviron("secret/.env") }

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


# Suppose we have a list of geoids that make up an MPO
# geoids = c("Tompkins" = "36109", "Cortland" = "36023", "Broome" = "36007")
# read_rds("data/geoids.rds") %>% filter(state == "NY") %>% select(geoid, name) %>% View()
myregions = read_rds("data/regions_ny_data.rds") 
geoids= myregions$geoid
myyear = 2022
pollutant = 98

mystate = get_state(geoids)
yearrange = get_yearrange(year = 2022)

# Make a few temporary files
path_emissions = tempfile(pattern = "emissions", fileext = ".rds")
path_census_tracts = tempfile(pattern = "census_tracts", fileext = ".rds")
path_census_counties = tempfile(pattern = "census_counties", fileext = ".rds")
path_shapes_counties = tempfile(pattern = "shapes_counties", fileext = ".rds")
path_shapes_tracts = tempfile(pattern = "shapes_tracts", fileext = ".rds")
path_shapes_roads = tempfile(pattern = "shapes_roads", fileext = ".rds")
path_shapes_buffers = tempfile(pattern = "shapes_buffers", fileext = ".rds")
path_shapes_tracts_exposure = tempfile(pattern = "shapes_tracts_exposure", fileext = ".rds")


# Query emissions data
cat("\n---downloading emissions---\n")
retrieve_emissions(
  geoid = geoids,
  year = yearrange, 
  pollutant = pollutant,
  var = "emissions", 
  aggregation = 16
) %>% 
  saveRDS(path_emissions)

# Query census data 
cat("\n---downloading census data---\n")
# for census tracts...
# using yuchen's adapted code
retrieve_census2(state_fips = mystate$state_fips, year = myyear, region = "tract:*") %>%
  saveRDS(path_census_tracts)
# for census counties...
retrieve_census2(state_fips = mystate$state_fips, year = myyear, region = "county:*") %>%
  saveRDS(path_census_counties)

# retrieve_census(state_fips = mystate$state_fips, year = myyear, region = "tract:*") %>%
#   saveRDS(path_census_tracts)
# retrieve_census(state_fips = mystate$state_fips, year = myyear, region = "county:*") %>%
#   saveRDS(path_census_counties)
# read_rds(path_census_counties) %>% glimpse()

cat("\n---downloading shapes---\n")
# Get county polygons
get_shapes_counties(geoids = geoids, year = myyear) %>% saveRDS(path_shapes_counties)
# Get census tract polygons
get_shapes_tracts(geoids = geoids, year = myyear) %>% saveRDS(path_shapes_tracts)
# Get road polygons
get_shapes_roads(counties = read_rds(path_shapes_counties), year = myyear) %>% saveRDS(path_shapes_roads)



# Sensitivity testing ################################################
cat("\n---mapping exposure zones---\n")

# For every tract, 
path_emissions = "test/emissions.rds"
path_census_tracts = 'test/census_tracts.rds'
path_census_counties = "test/census_counties.rds"
path_shapes_counties = "test/shapes_counties.rds"
path_shapes_tracts = "test/shapes_tracts.rds"
path_shapes_roads = "test/shapes_roads.rds"

library(dplyr)
library(readr)
library(sf)
# read_rds(path_emissions) %>% 
#   filter(geoid == "36109")

## 2000 meter buffer ###################################################

path_shapes_buffers2000 = "test/shapes_buffers2000.rds"
path_area_roads2000 = "test/area_roads2000.rds"

# Get road buffer polygons
get_shapes_buffers(
  roads = read_rds(path_shapes_roads), 
  counties = read_rds(path_shapes_counties),
  dist = 2000) %>%
  saveRDS(path_shapes_buffers2000)

get_area_roads(
  tracts = path_shapes_tracts %>% read_rds(), 
  buffers = path_shapes_buffers2000 %>% read_rds()) %>% 
  saveRDS(path_area_roads2000)


## 1000 meter buffer ###################################################

path_shapes_buffers = "test/shapes_buffers.rds"
path_area_roads = "test/area_roads.rds"

# Get road buffer polygons
get_shapes_buffers(
  roads = read_rds(path_shapes_roads), 
  counties = read_rds(path_shapes_counties),
  dist = 1000) %>%
  saveRDS(path_shapes_buffers)

get_area_roads(
  tracts = path_shapes_tracts %>% read_rds(), 
  buffers = path_shapes_buffers %>% read_rds()) %>% 
  saveRDS(path_area_roads)

## 500 meter buffer ###################################################

path_shapes_buffers500 = "test/shapes_buffers500.rds"
path_area_roads500 = "test/area_roads500.rds"

# Get road buffer polygons
get_shapes_buffers(
  roads = read_rds(path_shapes_roads), 
  counties = read_rds(path_shapes_counties),
  dist = 500) %>%
  saveRDS(path_shapes_buffers500)

get_area_roads(
  tracts = path_shapes_tracts %>% read_rds(), 
  buffers = path_shapes_buffers500 %>% read_rds()) %>% 
  saveRDS(path_area_roads500)

# 300 meter buffer ###################################################

path_shapes_buffers300 = "test/shapes_buffers300.rds"
path_area_roads300 = "test/area_roads300.rds"

# Get road buffer polygons
get_shapes_buffers(
  roads = read_rds(path_shapes_roads), 
  counties = read_rds(path_shapes_counties),
  dist = 300) %>%
  saveRDS(path_shapes_buffers300)

get_area_roads(
  tracts = path_shapes_tracts %>% read_rds(), 
  buffers = path_shapes_buffers300 %>% read_rds()) %>% 
  saveRDS(path_area_roads300)


# 100 meter buffer ###################################################

path_shapes_buffers100 = "test/shapes_buffers100.rds"
path_area_roads100 = "test/area_roads100.rds"

# Get road buffer polygons
get_shapes_buffers(
  roads = read_rds(path_shapes_roads), 
  counties = read_rds(path_shapes_counties),
  dist = 100) %>%
  saveRDS(path_shapes_buffers100)

get_area_roads(
  tracts = path_shapes_tracts %>% read_rds(), 
  buffers = path_shapes_buffers100 %>% read_rds()) %>% 
  saveRDS(path_area_roads100)


# area_roads = read_rds(path_area_roads)


# Get tracts by exposure level (area)
# takes too long. Better to go county by county.
# get_shapes_tracts_by_exposure(tracts = read_rds(path_shapes_tracts), buffer = read_rds(path_shapes_buffers)) %>% saveRDS(path_shapes_tracts_exposure)
# get_shapes_tracts_by_exposure_loop(
#   tracts = read_rds(path_shapes_tracts),
#   buffer = read_rds(path_shapes_buffers)) %>% 
#   saveRDS(path_shapes_tracts_exposure)

# Create a test folder to hold the results
dir.create("test")
path_emissions %>% read_rds() %>% saveRDS("test/emissions.rds")
path_census_tracts %>% read_rds()%>% saveRDS("test/census_tracts.rds")
path_census_counties %>% read_rds()%>% saveRDS("test/census_counties.rds")
path_shapes_counties %>% read_rds()%>% saveRDS("test/shapes_counties.rds")
path_shapes_tracts%>% read_rds() %>% saveRDS("test/shapes_tracts.rds")
path_shapes_roads %>% read_rds()%>% saveRDS("test/shapes_roads.rds")
path_shapes_buffers %>% read_rds()%>% saveRDS("test/shapes_buffers.rds")
path_shapes_tracts_exposure%>% read_rds() %>% saveRDS("test/shapes_tracts_exposure.rds")


# # Visualize
# gg = get_viz_buffers(
#   counties = read_rds(path_shapes_counties),
#   roads = read_rds(path_shapes_roads),
#   tracts = read_rds(path_shapes_tracts),
#   buffers = read_rds(path_shapes_buffers)
# )
# ggsave(gg, filename = "test/plot.png", dpi = 300, width =10, height = 10)
# browseURL("test/plot.png")
# 




