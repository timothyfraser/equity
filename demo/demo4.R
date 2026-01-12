# demo4.R

# Script to play around with 10 random counties' data from CATSERVER from 2 states
# New York and New Jersey

library(dplyr)
library(readr)
library(purrr)
library(tidyr)
library(ggplot2)

data = read_rds("demo/data.rds") %>%
  filter(year == 2020) %>%
  # Randomly assign them to groups, as if states
  mutate(state = sample(x = c("a", "b"), size = n(), replace = TRUE))

data %>%
  select(geoid, state)

data = data %>%
  mutate(
    emissions_rate = emissions / pop,
    num_black = pop * pop_black,
    emissions_black = emissions_rate * num_black,
    
    num_asian = pop * pop_asian,
    emissions_asian = emissions_rate * num_asian,
    
    num_other = (1 - pop_black - pop_asian) * pop,
    emissions_other = emissions_rate * num_other
  )

# Get some stats per group
# statewise = data %>%
#   group_by(state) %>%
#   summarize(
#     num_black = sum(num_black),
#     num_nonblack = sum(num_nonblack),
#     emissions_black = sum( emissions_black ),
#     emissions_nonblack = sum( emissions_nonblack ),
#     emissions_total = sum(emissions),
#     pop_total = sum(pop),
#     rate_black = emissions_black / num_black,
#     rate_nonblack = emissions_nonblack / num_nonblack,
#     rate_total = emissions_total / pop_total
#   )

# What if we calculated...
# Chi-squared statistic.
# Rate total is the expected
# 
# testdata = statewise %>%
#   select(state, rate_black, rate_nonblack, exp = rate_total) %>%
#   pivot_longer(
#     cols = c(rate_black, rate_nonblack),
#     names_to = "group",
#     values_to = "obs"
#   )
# 
# # Calculate stat
# stat = testdata  %>%
#   group_by(state) %>%
#   summarize(
#     chisq = sum( (obs - exp)^2 / exp ),
#     df = n() - length(unique(group)) - 1,
#     #f = pchisq(q = chisq, df = df)
#   )
# # hmm... something's wrong here.
# stat


# Calculate total share of emissions from group 1 vs. group 2 per state
statewise = data %>%
  group_by(state) %>%
  summarize(
    eshare_black = sum(emissions_black) / sum(emissions),
    eshare_asian = sum(emissions_asian) / sum(emissions),
    eshare_other = sum(emissions_other) / sum(emissions),
    # Just verify to make sure this isn't just replicating population... it's not!
    pshare_black = sum(num_black) / sum(pop),
    pshare_asian = sum(num_asian) / sum(pop),
    pshare_other = sum(num_other) / sum(pop)
  )

statewise %>%
  select(state, contains("eshare"),
         contains("pshare"))

statewise %>%
  select(state, eshare_black, pshare_black)

# For state "a",
# the share of total emissions experienced by black residents is 8%
# the share of total population made up by black residnets is 9%

# For state "b",
# repeat....

 
totals =statewise %>%
  group_by(state) %>%
  summarize(
    diff_black = eshare_black - pshare_black,
    diff_asian = eshare_asian - pshare_asian,
    diff_other = eshare_other - pshare_other,
    diff_max = abs(0 - 1)
  )


totals

# Make a 0 to 1 indicator, where 0 is perfect equity and 1 is TERRIBLE
totals %>%
  group_by(state) %>%
  summarize(
    indicator_race = (diff_black^2 + diff_asian^2 + diff_other^2) / diff_max^2
  )

# How about a gini coefficient instead?


