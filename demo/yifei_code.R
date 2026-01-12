library(dplyr)
library(tidyr)

calculate_equity_indicator <- function(
    population_data,   # Includes population subgroup data
    emissions_data,    # Includes emissions data
    group_vars,        # Grouping variable column names (character vectors, such as c(“Black”, “Asian”, “Other”))
    total_pop_var = "Total"  # Total population listed
) {
  # Data preprocessing
  processed <- population_data %>%
    select(GEOID, State, all_of(c(total_pop_var, group_vars))) %>%
    inner_join(emissions_data, by = "GEOID") %>%
    pivot_longer(
      cols = all_of(group_vars),
      names_to = "group",
      values_to = "group_proportion"
    ) %>%
    mutate(
      group_pop = .data[[total_pop_var]] * group_proportion,
      emissions_allocated = (emissions / .data[[total_pop_var]]) * group_pop
    ) %>%
    group_by(State, group) %>%
    summarize(
      total_emissions = sum(emissions_allocated, na.rm = TRUE),
      total_group_pop = sum(group_pop, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Calculation of state summary indicators (from demo 4!)
  statewise <- processed %>%
    group_by(State) %>%
    mutate(
      state_total_emissions = sum(total_emissions),
      state_total_pop = sum(total_group_pop),
      emissions_share = total_emissions / state_total_emissions,
      population_share = total_group_pop / state_total_pop
    ) %>%
    ungroup()
  
  # Calculation of equity indicators
  equity_stats <- statewise %>%
    group_by(State) %>%
    summarize(
      chi_sq = sum((emissions_share - population_share)^2 / population_share),
      max_chi_sq = (1 - 1/n()) * (n() - 1),  # Theoretical maximum (assuming complete Terrable)
      equity_indicator = chi_sq / max_chi_sq,  # standerize to 1 to 0
      .groups = "drop"
    ) %>%
    select(State, equity_indicator, chi_sq)
  
  # Consolidation of detailed data
  list(
    indicator = equity_stats,
    detailed = statewise %>%
      select(State, group, emissions_share, population_share) %>%
      pivot_wider(
        names_from = group,
        values_from = c(emissions_share, population_share),
        names_glue = "{group}_{.value}"
      )
  )
}

# Assuming that population_data comes from the previous getting function
race_groups <- c("White", "Black", "Asian", "Native", "HIPI", "Other", "Multiple")

race_equity <- calculate_equity_indicator(
  population_data = ca_race_data,  # California Data Example
  emissions_data = ca_emissions,   # Emissions data to include GEOID and emissions columns
  group_vars = race_groups
)

# Another example: Income
income_groups <- c("LowIncome", "MiddleIncome", "HighIncome")

income_equity <- calculate_equity_indicator(
  population_data = income_pop_data,
  emissions_data = state_emissions,
  group_vars = income_groups
)