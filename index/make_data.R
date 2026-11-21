# make_data.R

# Set directory to index folder
# Run from index/ (cd index && Rscript make_data.R); in RStudio, open equity.Rproj first.
if (interactive() && requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) { setwd(paste0(rstudioapi::getActiveProject(), "/index")) }
getwd()

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
# myregions = read_rds("data/regions_ny_data.rds") 
# myregions
# geoids= myregions$geoid
# myyear = 2022
# pollutant = 98
# 
# mystate = get_state(geoids)
# yearrange = get_yearrange(year = 2022)


# Explore our data ##########################
# Here are our file paths
path_emissions = "test/emissions.rds"
path_census_tracts = 'test/census_tracts.rds'
path_census_counties = "test/census_counties.rds"
path_shapes_counties = "test/shapes_counties.rds"
path_shapes_tracts = "test/shapes_tracts.rds"
path_shapes_roads = "test/shapes_roads.rds"
path_shapes_buffers = "test/shapes_buffers.rds"
path_area_roads = "test/area_roads.rds"

# Here is a data.frame where for each census tract we know the area of exposure. (area_roads)
# the percentage of area exposed to treansportation emissions would be area_roads / area_total
# Don't need to interact with this.
read_rds(path_area_roads)

# Total emissions per pollutant per year per geoid.
read_rds(path_emissions) %>% glimpse()



# Review our census variables for every census tract
# read_rds(path_census_tracts) %>% glimpse()
# read_rds(path_census_tracts)$edu_postgrad %>% summary()

# Select your **indicators**
# myvars =  c("age_under_18", "age_18_34", "age_35_64", "age_65_and_over")

# Run this script!
data = get_all(
  myregions = read_rds("data/regions_ny_data.rds"), 
  myyear = 2022,
  myvars =  c("age_under_18", "age_18_34", "age_35_64", "age_65_and_over"))

# visualize differences
get_bars(region_group_values = data$region_group_values, metric = "epshare")

data = get_all(
  myregions = read_rds("data/regions_ny_data.rds"), 
  myyear = 2022,
  myvars =  c("income_0_24999", "income_25000_49999", "income_50000_74999", "income_75000_99999",
              "income_100000_124999", "income_125000_149999", "income_150000_199999", "income_200000_or_more" ))


data
get_bars(region_group_values = data$region_group_values, metric = "epshare")



# One type of analysis - slope
data$region_group_values %>%
  group_by(region) %>%
  reframe(lm(formula = epshare ~ as.numeric(group)) %>% broom::tidy() ) %>%
  filter(term != "(Intercept)") %>%
  ggplot(mapping = aes(x = reorder(region, -estimate), y = estimate)) +
  geom_col() + 
  coord_flip() + 
  labs(y = "As group changes from lowest to highest bracket,\nhow much does the Share of Emissions Exposure increase?")

# In New York City, income doesn't really have a linear trend.
# In Southern Tier, etc. income bracket \
# map 
# https://www.google.com/url?sa=i&url=https%3A%2F%2Fwww.democratandchronicle.com%2Fstory%2Fnews%2Fpolitics%2Falbany%2F2020%2F05%2F13%2Fnew-york-coronavirus-reopening-which-regions-can-start-reopen-may-15%2F5182327002%2F&psig=AOvVaw0mwixehVvz5QdcmucDy11l&ust=1743271157329000&source=images&cd=vfe&opi=89978449&ved=0CBEQjRxqFwoTCIjc4qOtrYwDFQAAAAAdAAAAABAs
# https://acecny.org/resource/resmgr/images/regionalmap2015.png


# What's the correlation between emissions and the indicator?

cor(data$joined$indicator2, data$joined$emissions)

ggplot() +
  geom_point(data = data$joined,
             mapping = aes(x = emissions, y = indicator2)) +
  geom_smooth(data = data$joined,
              mapping = aes(x = emissions, y = indicator2),
              method = "lm")



# HYPOTHESES #########################################

# Develop several descriptive, bivariate hypotheses 

# How does income equity change by population? by emissions?
# what do you expect? What do you see?


# Question 1:
# Do the highest emitters see better or worse equity? In terms of age? income? race? overall?
# -- as emissions increase, equity increase
# -- If as emissions increase, equity decreases ---> that's bad!

# Question 2: 
# As income bracket increases, how does share of emissions exposure change?
# In what regions is that slope highest?
# Ideally, we want the slope to be low. This is a way to identify problem regions. 
# If slope is negative, that's bad!!!

# Question 3:
# ???




# Steps:
# -- get results
# -- write results
# -- visualize results 
# -- finalizing




# How does overall equity change?
get_overall()




