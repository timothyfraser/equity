# make_emissions.R
# Run from the index/ directory:  cd index && Rscript make_emissions.R

library(dplyr)
library(purrr)
library(readr)
library(stringr)
library(tidyr)

# Load the CAT bulk Parquet loader
source("cat_bulk.R")

# Study counties and pollutants
geoids = read_rds("data/regions_ny_data.rds")$geoid
pollutants = c(98, 2, 3, 31, 33, 100, 106, 107, 110, 116, 117)

# Download each year once into a cache folder
cache_dir = file.path(tempdir(), "cat_bulk")
base = "https://api.cat-apps.com/objects"
manifest = cat_manifest_name(base)
stamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")

# Every available year 2020-2025 (62 counties each where present) feeds the per-county piecewise linear interpolation
YEARS = 2020:2025
main = retrieve_emissions_bulk(
  geoid = geoids, year = YEARS, pollutant = pollutants,
  base = base, cache_dir = cache_dir) |>
  arrange(year, pollutant, geoid)
write_csv(main, "test/emissions_all_pollutants.csv")
main |> mutate(geoid = str_pad(geoid, width = 5, side = "left", pad = "0")) |>
  saveRDS("test/emissions_all_pollutants.rds")

# Endpoints only (2020 and 2025): the earlier straight-line method, kept as the rerun_endpoints variant
main |> filter(year %in% c(2020, 2025)) |>
  mutate(geoid = str_pad(geoid, width = 5, side = "left", pad = "0")) |>
  saveRDS("test/emissions_2020_2025_endpoints.rds")

# Pollutant 98 (CO2e), 2020 and 2025 only: the small sample that make_data.R reads with glimpse()
main |> filter(pollutant == 98, year %in% c(2020, 2025)) |>
  mutate(geoid = str_pad(geoid, width = 5, side = "left", pad = "0")) |>
  saveRDS("test/emissions.rds")

# Year 2022 exactly as published (incomplete: some counties missing); used only for cross-checks
exact22 = retrieve_emissions_bulk(
  geoid = geoids, year = 2022, pollutant = pollutants,
  base = base, cache_dir = cache_dir) |>
  arrange(pollutant, geoid)
saveRDS(exact22, "test/emissions_2022_exact.rds")

# Provenance
counts = function(d) d |> count(year, pollutant) |> mutate(txt = paste0("  ", year, " pollutant ", pollutant, ": ", n, " rows")) |> pull(txt)
yrs110 = main |> filter(pollutant == 110) |> group_by(geoid) |>
  summarize(n_years = n(), years = paste(sort(year), collapse = ",")) |> arrange(geoid)
c("CAT bulk emissions provenance",
  paste("manifest:", manifest),
  paste("downloaded (UTC):", stamp),
  "object URLs:",
  paste0("  ", base, "/year/", c(YEARS, 2022), ".parquet") |> unique(),
  paste("test/emissions_all_pollutants.{csv,rds} (years 2020-2025, all available) rows:", nrow(main)),
  paste("test/emissions_2020_2025_endpoints.rds (2020 and 2025 only) rows:", sum(main$year %in% c(2020, 2025))),
  paste("test/emissions_2022_exact.rds rows:", nrow(exact22)),
  "rows per year x pollutant (all_pollutants):", counts(main),
  "rows per year x pollutant (2022 exact):", counts(exact22),
  "counties by number of years available (pollutant 110):", 
  paste0("  ", names(table(yrs110$n_years)), " years: ", as.integer(table(yrs110$n_years)), " counties"),
  "per-county years available, pollutant 110 (geoid: years):",
  paste0("  ", yrs110$geoid, ": ", yrs110$years)) |>
  writeLines("test/emissions_provenance.txt")

# ---- legacy (retired Cloud Run proxy) ----
# setwd(paste0(rstudioapi::getActiveProject(), "/index"))
# readRenviron("secret/.env")
# source("functions.R")
# read_rds("data/regions_ny_data.rds") %>%
#   with(geoid) %>%
#   retrieve_emissions(
#     geoid = ., year = c(2020, 2025),
#     pollutant = c(98, 2, 3, 31, 33, 100, 106, 107, 110, 116, 117), aggregation = 16,
#     var = "emissions") %>%
#   write_csv("test/emissions_all_pollutants.csv")
# read_csv("test/emissions_all_pollutants.csv") %>%
#   mutate(geoid = stringr::str_pad(geoid, width = 5, side = "left", pad = "0")) %>%
#   saveRDS("test/emissions_all_pollutants.rds")
