# P0: the unit function reproduces the paper's Capital District rerun values from cached NY inputs.
suppressPackageStartupMessages({library(dplyr); library(readr); library(jsonlite)})
setwd(file.path(Sys.getenv("EQUITY_ROOT", "/home/user/equity"), "index"))
source("functions.R"); source("../national/pilot/pilot_functions.R")
regions = read_rds("data/regions_ny_data.rds")
cd = regions %>% filter(region == "Capital District") %>% pull(geoid)
exposure = read_rds("test/area_roads300.rds") %>% filter(geoid_county %in% cd)
res = get_unit_indices("Capital District",
  exposure = exposure, census_tracts = read_rds("test/census_tracts.rds"),
  county_emissions = read_rds("test/emissions_all_pollutants.rds"),
  census_counties = read_rds("test/census_counties.rds"),
  unit_tracts = exposure$geoid, myyear = 2022, .pollutant = 110, pop_source = "counties")
rj = fromJSON(Sys.getenv("RESULTS_JSON", "/home/user/paper_equity/.contract/r0/results.json"), simplifyVector = FALSE)
ref = rj$table2$rerun[["Capital District"]]
cmp = res %>% transmute(type, new = indicator2, ref = sapply(type, function(t) ref[[t]]$value), diff = new - ref)
print(cmp, digits = 12)
cat("counties:", length(cd), " max |diff|:", max(abs(cmp$diff)), "\n")
cat("P0", if(max(abs(cmp$diff)) < 1e-9) "PASS" else "FAIL", "\n")
