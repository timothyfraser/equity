# Synthetic tests for the pilot unit function: drop-and-flag behaviour.
suppressPackageStartupMessages({library(dplyr); library(readr)})
root = Sys.getenv("EQUITY_ROOT", normalizePath(if (file.exists("index/functions.R")) "." else "..")); setwd(file.path(root, "index"))
source("functions.R"); source("../national/pilot/pilot_functions.R")
regions = read_rds("data/regions_ny_data.rds"); cd = regions %>% filter(region == "Capital District") %>% pull(geoid)
ex = read_rds("test/area_roads300.rds") %>% filter(geoid_county %in% cd); tr = read_rds("test/census_tracts.rds")
em = read_rds("test/emissions_all_pollutants.rds")
ok = 0; fail = 0; t = function(name, cond){ if(isTRUE(cond)) ok <<- ok + 1 else { fail <<- fail + 1; cat("FAIL:", name, "\n") } }
base = get_unit_indices("u", exposure = ex, census_tracts = tr, county_emissions = em, unit_tracts = ex$geoid, pop_source = "tracts")
# 1. a county with no exposed residents is dropped, not NaN
z = cd[1]; ex0 = ex %>% mutate(area_roads = if_else(geoid_county == z, 0, area_roads))
u0 = get_unit_group_values(exposure = ex0, census_tracts = tr, county_emissions = em, unit_tracts = ex0$geoid, vars = DIMENSIONS$race)
t("zero-exposed county flagged", identical(attr(u0, "dropped")$reason, "no_exposed_residents"))
t("zero-exposed county removed", !z %in% u0$geoid_county)
i0 = get_unit_indices("u", exposure = ex0, census_tracts = tr, county_emissions = em, unit_tracts = ex0$geoid)
t("indices finite after drop", all(is.finite(i0$indicator2)))
# 2. a county with only a 2020 run: dropped under "none", carried under "nearest"
em1 = em %>% filter(!(geoid == z & year > 2020))
u1 = get_unit_group_values(exposure = ex, census_tracts = tr, county_emissions = em1, unit_tracts = ex$geoid, vars = DIMENSIONS$race)
t("2020-only county dropped under none", identical(attr(u1, "dropped")$reason, "no_emissions_for_year"))
u2 = get_unit_group_values(exposure = ex, census_tracts = tr, county_emissions = em1, unit_tracts = ex$geoid, vars = DIMENSIONS$race, extrapolate = "nearest")
m2 = attr(u2, "emissions_method")
t("2020-only county kept under nearest", nrow(attr(u2, "dropped")) == 0 && m2$method[m2$geoid == z] == "nearest")
t("nearest uses the 2020 value", isTRUE(all.equal(m2$emissions[m2$geoid == z], em1 %>% filter(geoid == z, year == 2020, pollutant == 110) %>% pull(emissions))))
# 3. shares still sum to 1 after a drop
r = get_region_group_values(u1 %>% mutate(region = "u"), myvars = DIMENSIONS$race)
t("eshare sums to 1 after drop", abs(sum(r$eshare) - 1) < 1e-9); t("pshare sums to 1 after drop", abs(sum(r$pshare) - 1) < 1e-9)
cat(ok, "passed,", fail, "failed\n"); if(fail > 0) quit(status = 1)
