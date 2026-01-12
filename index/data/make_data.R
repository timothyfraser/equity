# Set directory to index folder
setwd(paste0(rstudioapi::getActiveProject(), "/index"))


tigris::fips_codes %>%
  select(state, state_fips = state_code) %>%
  distinct() %>%
  saveRDS("data/states.rds")

# Load data
load("data/choices_geoid_counties.rda")

library(dplyr)
choices_geoid_counties %>%
  purrr::map_dfr(~tibble(geoid = ., name = names(.))) %>%
  mutate(state_fips = stringr::str_sub(geoid, 1,2)) %>%
  left_join(by = "state_fips", y = read_rds("data/states.rds")) %>%
  saveRDS("data/geoids.rds")


# Define the county FIPS codes as a named vector
county_fips <- c(
  "Albany" = "36001", "Allegany" = "36003", "Bronx" = "36005", "Broome" = "36007",
  "Cattaraugus" = "36009", "Cayuga" = "36011", "Chautauqua" = "36013", "Chemung" = "36015",
  "Chenango" = "36017", "Clinton" = "36019", "Columbia" = "36021", "Cortland" = "36023",
  "Delaware" = "36025", "Dutchess" = "36027", "Erie" = "36029", "Essex" = "36031",
  "Franklin" = "36033", "Fulton" = "36035", "Genesee" = "36037", "Greene" = "36039",
  "Hamilton" = "36041", "Herkimer" = "36043", "Jefferson" = "36045", "Kings" = "36047",
  "Lewis" = "36049", "Livingston" = "36051", "Madison" = "36053", "Monroe" = "36055",
  "Montgomery" = "36057", "Nassau" = "36059", "New York" = "36061", "Niagara" = "36063",
  "Oneida" = "36065", "Onondaga" = "36067", "Ontario" = "36069", "Orange" = "36071",
  "Orleans" = "36073", "Oswego" = "36075", "Otsego" = "36077", "Putnam" = "36079",
  "Queens" = "36081", "Rensselaer" = "36083", "Richmond" = "36085", "Rockland" = "36087",
  "St. Lawrence" = "36089", "Saratoga" = "36091", "Schenectady" = "36093", "Schoharie" = "36095",
  "Schuyler" = "36097", "Seneca" = "36099", "Steuben" = "36101", "Suffolk" = "36103",
  "Sullivan" = "36105", "Tioga" = "36107", "Tompkins" = "36109", "Ulster" = "36111",
  "Warren" = "36113", "Washington" = "36115", "Wayne" = "36117", "Westchester" = "36119",
  "Wyoming" = "36121", "Yates" = "36123"
)

# Define regions as a list of named vectors
regions_ny <- list(
  "Western New York" = county_fips[c("Niagara", "Erie", "Chautauqua", "Cattaraugus", "Allegany")],
  "Finger Lakes" = county_fips[c("Orleans", "Genesee", "Wyoming", "Monroe", "Livingston", "Wayne", "Ontario", "Yates", "Seneca")],
  "Southern Tier" = county_fips[c("Steuben", "Schuyler", "Chemung", "Tompkins", "Tioga", "Chenango", "Broome", "Delaware")],
  "Central New York" = county_fips[c("Cortland", "Cayuga", "Onondaga", "Oswego", "Madison")],
  "North Country" = county_fips[c("St. Lawrence", "Lewis", "Jefferson", "Hamilton", "Essex", "Clinton", "Franklin")],
  "Mohawk Valley" = county_fips[c("Oneida", "Herkimer", "Fulton", "Montgomery", "Otsego", "Schoharie")],
  "Capital District" = county_fips[c("Albany", "Columbia", "Greene", "Warren", "Washington", "Saratoga", "Schenectady", "Rensselaer")],
  "Hudson Valley" = county_fips[c("Sullivan", "Ulster", "Dutchess", "Orange", "Putnam", "Rockland", "Westchester")],
  "New York City" = county_fips[c("New York", "Bronx", "Queens", "Kings", "Richmond")],
  "Long Island" = county_fips[c("Nassau", "Suffolk")]
)

regions_ny %>% saveRDS("data/regions_ny.rds")

read_rds("data/regions_ny.rds") %>%
  purrr::map_dfr(~tibble(geoid = ., name = names(.)), .id = "region") %>%
  saveRDS("data/regions_ny_data.rds")


rm(list = ls())
