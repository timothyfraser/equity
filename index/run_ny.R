# run_ny.R
# Lead Developer: Tim Fraser

if (interactive() && requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) { setwd(paste0(rstudioapi::getActiveProject(), "/index")) }
# Load environmental variables
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

# Paths/Settings ##########################
# Here are our file paths
path_emissions = "test/emissions_all_pollutants.rds"
path_census_tracts = 'test/census_tracts.rds'
path_census_counties = "test/census_counties.rds"
path_shapes_counties = "test/shapes_counties.rds"
path_shapes_tracts = "test/shapes_tracts.rds"
path_shapes_roads = "test/shapes_roads.rds"
path_shapes_buffers = "test/shapes_buffers300.rds"
path_area_roads = "test/area_roads300.rds"

myyear = 2022
mypollutant = 110
mydist = 300

# Measure Indices #####################

# Generate statistics overall
get_overall(myyear = myyear, pollutant = mypollutant, dist = mydist) %>% saveRDS("test/stat_overall.rds")

get_all(
  myregions = read_rds("data/regions_ny_data.rds"),
  myyear = myyear,
  .pollutant = mypollutant,
  path_emissions = path_emissions,
  path_area_roads = path_area_roads,
  myvars =  c("age_under_18", "age_18_34", "age_35_64", "age_65_and_over")) %>%
  saveRDS("test/stat_age.rds")

get_all(
  myregions = read_rds("data/regions_ny_data.rds"),
  myyear = myyear,
  .pollutant = mypollutant,
  path_emissions = path_emissions,
  path_area_roads = path_area_roads,
  myvars =  c("income_0_24999", "income_25000_49999", "income_50000_74999", "income_75000_99999",
              "income_100000_124999", "income_125000_149999", "income_150000_199999", "income_200000_or_more" )) %>%
  saveRDS("test/stat_income.rds")

get_all(
  myregions = read_rds("data/regions_ny_data.rds"), 
  myyear = myyear,
  .pollutant = mypollutant,
  index = "edu",
  path_emissions = path_emissions,
  path_area_roads = path_area_roads,
  myvars =  c("edu_less_than_hs", "edu_hs_grad", "edu_some_college_or_more", "edu_postgrad")
) %>%
  saveRDS("test/stat_edu.rds")

get_all(
  myregions = read_rds("data/regions_ny_data.rds"), 
  myyear = myyear,
  .pollutant = mypollutant,
  index = "race",
  path_emissions = path_emissions,
  path_area_roads = path_area_roads,
  myvars = RACE_VARS
) %>% 
  saveRDS("test/stat_race.rds")





# Sensitivity ############################################
# 
# read_csv("test/emissions_all_pollutants.csv") %>%
#   select(pollutant) %>%
#   distinct()

# (sensitivity grid runs after the main figures; see below)

## POLLUTANT #################################


# data = read_rds("test/stat_overall_sensitivity.rds") %>% 
#   filter(dist == mydist) %>%
#   filter(pollutant %in% valid)

# read_rds("test/emissions_all_pollutants.rds") %>% 
#   filter(pollutant == 33)




# Bar Plots ###########################################

## Age ##########################################
gg = get_bars2(mylist = read_rds("test/stat_age.rds"), metric = "epshare", ylab = "Age Group", beta = TRUE, hjust = 1, verbose = TRUE)
ggsave(plot = gg, filename = "test/bars_age.png", dpi = 500, width = 10, height = 6)
if (interactive()) { browseURL("test/bars_age.png") }

## Income #######################################
gg = get_bars2(mylist = read_rds("test/stat_income.rds"), metric = "epshare", ylab = "Income Bracket", beta = TRUE, hjust = 1, verbose = TRUE)
ggsave(plot = gg, filename = "test/bars_income.png", dpi = 500, width = 10, height = 6)
if (interactive()) { browseURL("test/bars_income.png") }

## Education #######################################
gg = get_bars2(mylist = read_rds("test/stat_edu.rds"), metric = "epshare", ylab = "Education Level", beta = TRUE, hjust = 1, verbose = TRUE)
ggsave(plot = gg, filename = "test/bars_edu.png", dpi = 500, width = 10, height = 6)
if (interactive()) { browseURL("test/bars_edu.png") }

## Race/Ethnicity ##################################
gg = get_bars2(mylist = read_rds("test/stat_race.rds"), metric = "epshare", ylab = "Race/Ethnicity", beta = FALSE, hjust = 0.5, verbose = TRUE)
ggsave(plot = gg, filename = "test/bars_race.png", dpi = 500, width = 10, height = 6)
if (interactive()) { browseURL("test/bars_race.png") }


# Lines/Distributions ###########################

## Overall ##########################################
gg = get_lines(stat_overall = read_rds("test/stat_overall.rds"), .dist = mydist, .pollutant = mypollutant, .year = myyear)
ggsave(plot = gg, filename = "test/lines_overall.png", dpi = 500, width = 8, height = 6)
if (interactive()) { browseURL("test/lines_overall.png") }


# Slopes ###########################

gg = get_emissions_slopes(
  stat_overall = read_rds("test/stat_overall.rds"),
  stat_income = read_rds("test/stat_income.rds"))
ggsave(plot = gg, filename = "test/slopes_by_type.png", dpi = 500, width = 8.5, height = 6)
if (interactive()) { browseURL("test/slopes_by_type.png") }


# Two-Bars #########################
gg = get_twobars(data_regions = read_rds("data/regions_ny_data.rds"),
                 data_emissions = read_csv("test/emissions_all_pollutants.csv"),
                 data_equity = read_rds("test/stat_overall.rds"),
                 myyear = myyear,
                 .pollutant = mypollutant)
ggsave(gg, filename = "test/twoway_bars.png", dpi = 500, width = 8, height = 6)
if (interactive()) { browseURL("test/twoway_bars.png") }




# Maps ################################

## OVERALL MAP #######################
# Visualize
gg = get_viz_buffers(
  counties = read_rds(path_shapes_counties),
  roads = read_rds(path_shapes_roads),
  tracts = read_rds(path_shapes_tracts),
  buffers = read_rds(path_shapes_buffers)
)
ggsave(gg, filename = "test/plot.png", dpi = 300, width =10, height = 10)
if (interactive()) { browseURL("test/plot.png") }


## ALBANY MAP #######################
gg = get_map(path_shapes_counties = path_shapes_counties, 
        path_shapes_roads = path_shapes_roads,
        path_shapes_tracts = path_shapes_tracts,
        path_shapes_buffers = path_shapes_buffers, 
        path_area_roads = path_area_roads)
ggsave(plot = gg, filename = "test/map.png", width = 10, height = 5, dpi = 300)

if (interactive()) { browseURL("test/map.png") }


# Sensitivity grid and figures (last) ############
# Measure sensitivity across distance and pollutant
sens_grid = tidyr::expand_grid(
  pollutant = c(98, 2, 3, 31, 33, 100, 106, 107, 110, 116, 117),
  dist = c(100, 300, 500, 1000, 2000),
  year = 2022
) %>%
  mutate(id = 1:n())
sens = sens_grid %>%
  split(.$id) %>%
  purrr::map_dfr(
    .f = possibly(.f = ~get_overall(myyear = .$year, pollutant = .$pollutant, dist = .$dist), otherwise = NULL), 
    .id = "id")
# A cell whose emissions cannot be computed (for example, a pollutant with too few CAT years) is dropped; say how many
message("sensitivity grid: ", dplyr::n_distinct(sens$id), " of ", nrow(sens_grid), " pollutant x distance cells computed")
saveRDS(sens, "test/stat_overall_sensitivity.rds")

## DISTANCE #################################
# Review data
read_rds("test/stat_overall_sensitivity.rds")

gg = get_sensitivity_distance1(sensitivity_data = read_rds("test/stat_overall_sensitivity.rds"), .pollutant = mypollutant, .year = myyear)
ggsave(plot = gg, filename = "test/sensitivity_distance.png", dpi = 500, width = 6, height = 6)
if (interactive()) { browseURL("test/sensitivity_distance.png") }


gg = get_sensitivity_distance2(sensitivity_data = read_rds("test/stat_overall_sensitivity.rds"), .pollutant = mypollutant, .year = myyear)
ggsave(gg, filename = "test/sensitivity_scatterplot.png", dpi = 500, width= 6, height =6)
if (interactive()) { browseURL("test/sensitivity_scatterplot.png") }

gg = get_sensitivity_distance3(sensitivity_data = read_rds("test/stat_overall_sensitivity.rds"), .pollutant = mypollutant, .year = myyear)
ggsave(plot = gg, filename = "test/sensitivity_distance_pollutant.png", dpi = 500, width = 6, height = 6)
if (interactive()) { browseURL("test/sensitivity_distance_pollutant.png") }



# Stats ###########################

read_rds("test/stat_overall.rds") %>%
  reframe(
    r1 = cor(x = total, y = income),
    r2 = cor(x = total, y = race),
    r3 = cor(x = race, y = income),
    r4 = cor(x = income, y = edu)
  )


read_rds("test/stat_overall.rds") %>%
  summarize(
    mean = mean(total, na.rm = TRUE),
    se = sd(total, na.rm = TRUE) / sqrt(n()),
    min = min(total, na.rm = TRUE),
    max = max(total, na.rm = TRUE)
  )



read_rds("test/stat_overall.rds") %>%
  summarize(
    min = min(race, na.rm = TRUE),
    max = max(race, na.rm = TRUE),
    gap = max - min
  )

bind_rows(
  read_rds("test/stat_overall.rds") %>%
    select(region, total, income, race, edu, age) %>%
    arrange(desc(total)),
  read_rds("test/stat_overall.rds") %>%
    select(region, total, income, race, edu, age) %>%
    summarize(region = "mean", across(total:age, .f = ~mean(.x))),
  
  read_rds("test/stat_overall.rds") %>%
    select(region, total, income, race, edu, age) %>%
    summarize(region = "se", across(total:age, .f = ~round(sd(.x) / sqrt(n()), 3) )),
  
  read_rds("test/stat_overall.rds") %>%
    select(region, total, income, race, edu, age) %>%
    summarize(region = "sd", across(total:age, .f = ~round(sd(.x), 3))),
  read_rds("test/stat_overall.rds") %>%
    select(region, total, income, race, edu, age) %>%
    summarize(region = "min", across(total:age, .f = ~min(.x))),
  read_rds("test/stat_overall.rds") %>%
    select(region, total, income, race, edu, age) %>%
    summarize(region = "max", across(total:age, .f = ~max(.x)))
)
