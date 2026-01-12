# demo3.R

# Script to play around with 10 random counties' data from CATSERVER from 2 states
# New York and New Jersey

library(dplyr)
library(readr)
library(purrr)
library(ggplot2)


data = read_rds("demo/data.rds") %>%
  filter(year == 2020)

ggplot() +
  geom_point(data = data, mapping = aes(x = pop_black, y = emissions / pop))

data = data %>%
  mutate(
    emissions_black = (emissions / pop) * (pop_black * pop),
    emissions_asian = (emissions / pop) * (pop_asian * pop),
    emissions_hisplat = (emissions / pop) * (pop_hisplat * pop)
  ) %>%
  mutate(index = (emissions_black + emissions_asian + emissions_hisplat) / emissions / 3  )

d = data %>%
  tidyr::pivot_longer(cols = c(emissions_black, emissions_asian, emissions_hisplat ),
                      names_to = "type", values_to = "value")

ggplot() +
  geom_density(data = d,
               mapping = aes(x = value, fill = type), alpha = 0.5)



