#' @name demo.R
#' @author Tim Fraser
#' @description
#' A trial run at constructing some emissions-equity measures of interest,
#' using the CAT API.


# Load Packages ###################################
library(dplyr) # for data wrangling
library(readr) # for reading/writing data
library(ggplot2) # for visualization
library(httr) # for API calls
library(jsonlite) # for extracting data from API calls


# Query API ######################################

# Load the retrieve_data function I wrote...
source("demo/retrieve_data.R")

# Query API
data = retrieve_data(
  geoid = c("36109"), year = 2020, var = c("emissions"),
  pollutant = 98, # CO2 equivalent emission 
  # Specify covariates
  covvar = c("pop", "pop_black", "pop_asian","pop_natam", "pop_white", "pop_hisplat", "pop_white"))

data
retrieve_data(geoid = "36109", var = "emissions", covvar = "pop")

# View it
data
# Glimpse the variables
data %>% glimpse()

# pop, pop_women, pop_age_65_plus,
# pop_white, pop_black, pop_natam, pop_asian, pop_pacific,
# pop_hisplat, median_income, median_monthly_housing_cost


# Population-Based Exposure ###################################################

# Calculate...
data %>%
  mutate(
    # rate of emissions per capita
    rate_pop = emissions / pop,
    # Expected emissions exposure for Black Residents, based on population alone
    em_black = rate_pop * (pop * pop_black),
    # Expected emissions exposure for Hispanic/Latino Residents, based on population alone
    em_hisplat = rate_pop * (pop * pop_hisplat),
    # Expected emissions exposure for Asian Residents, based on population alone
    em_asian = rate_pop * (pop * pop_asian),
    # Expected emissions exposure for White Residents, based on population alone
    em_white = rate_pop * (pop * pop_white)
    ) %>%
  glimpse()


# 
# 
# # Other forms of aggregation #####################################
# retrieve_data(
#   geoid = c("36109"), year = 2020, var = c("emissions"),
#   # Specify covariates
#   covvar = c("pop", "pop_black", "pop_asian", "pop_hisplat", "pop_white"),
#   # 16 = overall
#   # 15 = by road type
#   # 14 = by fueltype
#   # 8 = by sourcetype
#   # 12 = by regulatory class
#   aggregation = 12
#   )
# 
# 
# # Social Vulnerability
# 
# # Burden Index
# # em_black (expected emissions for black residents)
# # ....
# # em_elders (expected emissions for elders residents)
# # ....
# # rescale them 0 to 1 across the US
# # average
# 
# 
# 
# # Equity
# # balance vs. burden
# # -- Is the burden level equal?
# # -- HOW burdened is each section of population in county
# 
# # County X has HIGH emissions burden
# # BUT
# # the burden is equally distributed across population groups
# 
# 
# # $ em_black    <dbl> 15921.58 = 4% * 388954.6
# # $ em_hisplat  <dbl> 20327.12
# # $ em_asian    <dbl> 36724.28
# # $ em_white    <dbl> 309559.6
# 
# 
# 
# 
# data = retrieve_data(
#   geoid = c("36109"), year = 2020, var = c("emissions"),
#   # Specify covariates
#   covvar = c("pop", "pop_black", "pop_asian", "pop_hisplat", "pop_white"),
#   # 16 = overall
#   # 15 = by road type
#   # 14 = by fueltype
#   # 8 = by sourcetype
#   # 12 = by regulatory class
#   aggregation = 15
# )
# 
# data
# # urban unrestricted access roads
# # urban restricted access roads
# # rural unresticted access roads
# # rural restricted access roads
# 
# # TIGRIS
# roads = tigris::roads(state = "36", county = "109", year = 2020)
# roads
# # County, State, Interstates, Common Roads
# 
# 
# # This tract is this far away from this road,
# # which makes this much emissions...
# 
# # County
# # Link by Link
# 
# # Openstreetmap data and getting broken by roadtype.
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# retrieve_data(
#   geoid = c("36109"), year = 2020, var = c("emissions"),
#   # Specify covariates
#   covvar = c("pop", "pop_black", "pop_asian", "pop_hisplat", "pop_white",
#              "median_income"),
#   # 16 = overall
#   # 15 = by road type
#   # 14 = by fueltype
#   # 8 = by sourcetype
#   # 12 = by regulatory class
#   aggregation = 16
# )







# Trying to figure out what we can do with this...

# What if we said...

# In this county, here's the distribution of emissions by roadtype...
# Here are each roadtype by TIGRIS mapping...
#
# data = retrieve_data(
#   geoid = "36109", year = 2020, var = c("emissions", "vmt"),
#   aggregation = 15,
#   covvar = c("pop", "pop_black")
# )
#
# data
# roads = tigris::roads(state = "36", county = "109", year = 2020)
# roads
#

# Cleanup
rm(list = ls())
