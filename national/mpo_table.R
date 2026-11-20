# V-1: one row per `done` MPO, wide index table. Reads LEDGER.csv and out/*/indices.csv only.
library(dplyr)
library(tidyr)
library(readr)

ledger = read_csv("national/LEDGER.csv", col_types = cols(.default = col_character())) |>
  filter(status == "done") |>
  transmute(mpo_id, mpo_name, state,
            n_counties = as.integer(n_counties), n_states = as.integer(n_states))

read_one = function(id) {
  read_csv(file.path("national/out", id, "indices.csv"),
           col_types = cols(.default = col_guess(), mpo_id = col_character()))
}

idx = purrr::map(ledger$mpo_id, read_one) |> bind_rows()

meta = idx |>
  summarise(.by = mpo_id, pop_in_mpo = first(pop_in_mpo),
            race_groups_lt_1000 = first(race_groups_lt_1000),
            emissions_mpo = first(emissions_mpo),
            emissions_rate_mpo = first(emissions_rate_mpo))

eq = idx |>
  filter(type %in% c("race", "income", "edu", "age", "overall")) |>
  select(mpo_id, type, indicator2) |>
  pivot_wider(names_from = type, values_from = indicator2)

pw = idx |>
  filter(type %in% c("race", "income")) |>
  select(mpo_id, type, indicator_pw) |>
  pivot_wider(names_from = type, values_from = indicator_pw, names_glue = "{type}_pw")

out = ledger |>
  left_join(meta, by = "mpo_id") |>
  left_join(eq, by = "mpo_id") |>
  left_join(pw, by = "mpo_id") |>
  select(mpo_id, mpo_name, state, n_counties, n_states, pop_in_mpo,
         race, income, edu, age, overall, race_pw, income_pw,
         race_groups_lt_1000, emissions_mpo, emissions_rate_mpo)

stopifnot(nrow(out) == nrow(ledger), !anyNA(out), n_distinct(out$mpo_id) == nrow(out))
write_csv(out, "national/tables/mpo_wide.csv")
cat("rows:", nrow(out), "\n")
