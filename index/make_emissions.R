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

# Years 2020 and 2025 (all 62 counties) feed the interpolation
main = retrieve_emissions_bulk(
  geoid = geoids, year = c(2020, 2025), pollutant = pollutants,
  base = base, cache_dir = cache_dir) |>
  arrange(year, pollutant, geoid)
write_csv(main, "test/emissions_all_pollutants.csv")
main |> mutate(geoid = str_pad(geoid, width = 5, side = "left", pad = "0")) |>
  saveRDS("test/emissions_all_pollutants.rds")

# Year 2022 exactly as published (incomplete: some counties missing); used only for cross-checks
exact22 = retrieve_emissions_bulk(
  geoid = geoids, year = 2022, pollutant = pollutants,
  base = base, cache_dir = cache_dir) |>
  arrange(pollutant, geoid)
saveRDS(exact22, "test/emissions_2022_exact.rds")

# Provenance
counts = function(d) d |> count(year, pollutant) |> mutate(txt = paste0("  ", year, " pollutant ", pollutant, ": ", n, " rows")) |> pull(txt)
c("CAT bulk emissions provenance",
  paste("manifest:", manifest),
  paste("downloaded (UTC):", stamp),
  "object URLs:",
  paste0("  ", base, "/year/", c(2020, 2025, 2022), ".parquet"),
  paste("test/emissions_all_pollutants.{csv,rds} rows:", nrow(main)),
  paste("test/emissions_2022_exact.rds rows:", nrow(exact22)),
  "rows per year x pollutant (all_pollutants):", counts(main),
  "rows per year x pollutant (2022 exact):", counts(exact22)) |>
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
