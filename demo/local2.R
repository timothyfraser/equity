# local2.R

library(dplyr)
library(readr)
library(sf)
library(ggplot2)
library(tigris)
library(stringr)
library(purrr)

readRenviron(".env")
state = "NY"
myyear = 2022

source("demo/retrieve_census.R")
source("demo/retrieve_data.R")

geoids = c("Tompkins" = "36109", "Cortland" = "36023", "Broome" = "36007")

yearrange = c( floor(myyear / 10) * 10, floor(myyear / 10) * 10 + 5)

data = geoids %>%
  map_dfr(~retrieve_data(geoid = ., year = yearrange, var = "emissions", pollutant = 98, aggregation = 16))

data %>% saveRDS("demo/sample_emissions.rds")
remove(data)


retrieve_census(state_fips = str_sub(geoids, 1,2) %>% unique(), year = myyear, region = "tract:*") %>%
  saveRDS("demo/sample_census_tracts.rds")

retrieve_census(state_fips = str_sub(geoids, 1,2) %>% unique(), year = myyear, region = "county:*") %>%
  saveRDS("demo/sample_census_counties.rds")


# Get just the tract data for those counties
tracts_census = read_rds("demo/sample_census_tracts.rds") %>%
  filter(str_sub(geoid, 1,5) %in% geoids)
# Get just the county data for those counties
counties_census = read_rds("demo/sample_census_counties.rds") %>%
  filter(str_sub(geoid, 1,5) %in% geoids)
# Get the emissions data for those counties
counties_emissions = read_rds("demo/sample_emissions.rds") %>%
  filter(str_sub(geoid, 1,5) %in% geoids) %>%
  group_by(geoid, pollutant) %>%
  summarize(emissions = lm(formula = emissions ~ year) %>% predict(object = ., newdata = tibble(year = myyear)), .groups = "drop")
  


# Get all counties in new york
counties = tigris::counties(state = state, cb = TRUE, year = myyear) %>%
  select(geoid = GEOID, name = NAME, area_land = ALAND, geometry) %>%
  # Filter to just geoids for which you'll make a total equity measure
  filter(geoid %in% geoids)

# Get tracts from all new york counties
tracts = tigris::tracts(state = state, county = str_sub(counties$geoid, 3,5), cb = TRUE, year = myyear) %>%
  filter(ALAND > 0)  %>%
  select(geoid = GEOID, area_land = ALAND, geometry) %>%
  mutate(geoid_county = str_sub(geoid, 1,5))


# i = 1
# county = counties %>% slice(i)
# county_i = counties$geoid[i]

# st_crs(roads)
roads = tigris::primary_secondary_roads(state = state, year = myyear ) 

roads = roads %>% 
  # Get just the roads that overlap with these polygons
  st_intersection(y = counties %>% select(geoid, geometry)) %>%
  # For each county, create 1 set of mega lines
  group_by(geoid) %>%
  summarize(geometry = st_union(geometry) %>% st_make_valid(), .groups = "drop")

# Create road buffers
buffer = roads %>%
 # Create 1 km buffers around roads
 mutate(geometry = st_buffer(geometry, dist = 1000) %>% st_make_valid())  %>%
  # Join in the county geometry
  left_join(by = "geoid", y = counties %>% as_tibble() %>% select(geoid, county_geometry = geometry)) %>%
  # now clip road buffers to the extent of each county
  group_by(geoid) %>%
  mutate(geometry = st_intersection(x = geometry, y = county_geometry) %>% st_make_valid()) %>%
  ungroup() %>%
  select(-county_geometry)


# View road buffers vs counties
ggplot() +
  geom_sf(data = counties, fill = "white", color = "black") +
  geom_sf(data = roads, color = "red") +
  geom_sf(data = buffer, fill = "red", alpha = 0.5)


# Calculate the area percentages
joined = tracts %>% 
  left_join(
    by = c("geoid_county" = "geoid"), 
    y = buffer %>% as_tibble() %>% select(geoid, buffer_geometry = geometry))   %>%
  # For each tract,
  # Get all the buffer areas within that tract's polygon, and
  # consolidate buffer regions in the same tract
  group_by(geoid, geoid_county) %>%
  reframe(
    # Get total tract area
    area_total = st_area(geometry) %>% as.numeric() %>% {./1e6},
    # Get total road buffer overlap
    geometry = st_intersection(x = geometry, y = buffer_geometry) %>% st_make_valid() %>% st_union(),
    # Get total road buffer area
    area_roads = st_area(geometry) %>% as.numeric() %>% {./1e6}
  ) 

# Create entire multi-county dataset
data = tracts %>%
  # Join in road area
  left_join(by = "geoid", y = joined %>% select(geoid, area_total, area_roads)) 

data

data = data %>%
  # Join in census traits
  left_join(
    by = "geoid", 
    y = tracts_census %>% select(geoid, pop, pop_white = white) %>%
      mutate(pop_nonwhite = 1 - pop_white)  ) %>%
  as_tibble() %>%
  # Estimate the total residents of group X that are in the buffer region in that tract
  mutate(
    affected_white = pop * pop_white * (area_roads / area_total),
    affected_nonwhite = pop * pop_nonwhite * (area_roads / area_total)
  ) %>%
  # Sum up the total folks in group X for that 
  group_by(geoid_county) %>%
  summarize(across(.cols = contains("affected_"), .fns = ~sum(.x, na.rm = TRUE)) ) %>%
  # Join in population
  left_join(by = c("geoid_county" = "geoid"),
            y = counties_census %>% select(geoid, pop, white)) %>%
  # Join in emissions
  left_join(by = c("geoid_county" = "geoid"),
            y = counties_emissions %>% select(geoid, emissions) %>% 
              mutate(geoid = str_pad(geoid, width = 5, side = "left", pad = "0")))  %>%
  # Calculate quantities of interest
  mutate(
    pop_white = pop * white,
    pop_nonwhite = pop * (1 - white),
    affected_total = affected_white + affected_nonwhite,
    emissions_rate = emissions / affected_total,
    emissions_white = emissions_rate * affected_white,
    emissions_nonwhite = emissions_rate * affected_nonwhite
  )


statewise = data %>%
  # suppose these are all part of the same group of municipalities...
  mutate(group = "A") %>%
  group_by(group) %>%
  summarize(
    # Calculate total share of emissions from group 1 vs. group 2 per state
    eshare_white = sum(emissions_white) / sum(emissions),
    eshare_nonwhite = sum(emissions_nonwhite) / sum(emissions),
    # Calculate share of actual population for each group per county
    pshare_white = sum(pop_white) / sum(pop),
    pshare_nonwhite = sum(pop_nonwhite) / sum(pop), 
    .groups = "drop"
  )


# Make a 0 to 1 indicator, where 0 is perfect equity and 1 is TERRIBLE
statewise %>%
  group_by(group) %>%
  summarize(
    diff_white = eshare_white - pshare_white,
    diff_nonwhite = eshare_nonwhite - pshare_nonwhite,
    diff_max = abs(0 - 1)
  ) %>%
  group_by(group) %>%
  summarize(
    indicator_race = (diff_white^2 + diff_nonwhite^2) / diff_max^2
  )





# tracts
# joined

joined

# View road buffers vs counties
ggplot() +
  geom_sf(data = counties, fill = "white", color = "black") +
  geom_sf(data = roads, color = "red") +
  geom_sf(data = tracts, color = 'grey', fill = NA) +
  geom_sf(data = st_as_sf(joined), fill = "red", alpha = 0.5, color = NA) +
  geom_sf(data = counties, fill = NA, color = "black", linewidth = 1.25)

tracts

tracts_census %>% glimpse()



# Last step



# Estimated # of people of group X living in
# the area immediately affected by on-road emissions in tract Z.
#   mutate(pop_affected = pop * area_roads / area )   





