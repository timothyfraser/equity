# local1.R

# An R script to test out 
# measuring the approximate number of people living in road-affected areas
# in each tract
library(dplyr)
library(readr)
library(sf)
library(ggplot2)

lines = read_csv("demo/lines.csv") %>%
  with(geometry) %>%
  st_as_sfc() %>%
  tibble(geometry = .)

tracts = read_csv("demo/polygons.csv") %>%
  with(geometry)  %>%
  st_as_sfc() %>%
  tibble(geometry = .) %>%
  mutate(pop = c(100, 200, 300, 400),
         area = st_area(geometry),
         density = pop / area)

county = tracts %>% 
  summarize(geometry = st_union(geometry),
            pop = sum(pop),
            area = st_area(geometry),
            density = pop / area,
            emissions = 200)

tracts$geometry %>% plot()
# number of kilometers around the road
dist = 1

# Make a buffer polygon surrounding all the lines
buffers = lines %>% 
  mutate(geometry = st_buffer(geometry, dist = 1)) %>%
  summarize(geometry = st_union(geometry))

trimmed = tracts %>%
  mutate(
    geometry = st_intersection(x = geometry, y = buffers$geometry),
    area_roads = st_area(geometry),
    percent = area_roads / area
  ) %>%
  # Estimated # of people of group X living in
  # the area immediately affected by on-road emissions in tract Z.
  mutate(pop_affected = pop * area_roads / area )   

ggplot() +
  geom_sf(data = tracts, mapping = aes(geometry = geometry), fill = NA) +
  geom_sf(data = lines, mapping = aes(geometry = geometry), color = "red")  +
  geom_sf(data = buffers, mapping = aes(geometry = geometry), fill = "red", alpha = 0.5)


# What percentage of group X lives in that area, then?
# trimmed %>% 
#   mutate(total = sum(pop_affected),
#             percent = pop_affected / total) %>%
#   glimpse()


trimmed %>% 
  summarize(
    group = "X",
    pop_affected = sum(pop * area_roads / area),
    emissions = county$emissions    
    )

county



