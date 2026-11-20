# run_pilot_mpo.R: the full chain for one MPO (PLAN_NATIONAL section 12).
# Usage (from repo root): Rscript national/pilot/run_pilot_mpo.R <MPO_ID>
# Writes national/pilot/out/<MPO_ID>/{indices.csv,checks.csv,timing.csv,members.csv}; downloads go to index/cache/.
suppressPackageStartupMessages({library(dplyr); library(readr); library(sf); library(purrr); library(stringr); library(tidyr)})
args = commandArgs(trailingOnly = TRUE); mpo_id = args[1]
extrap = if(length(args) > 1) args[2] else "none"   # none | nearest (counties with no CAT year on one side of 2022)
tag = if(extrap == "none") mpo_id else paste0(mpo_id, "_", extrap)
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity")
setwd(file.path(root, "index"))
source("functions.R"); source("cat_bulk.R"); source("../national/pilot/pilot_functions.R")
options(tigris_use_cache = TRUE)
out = file.path(root, "national/pilot/out", tag); dir.create(out, recursive = TRUE, showWarnings = FALSE)
cache = file.path("cache/national/pilot", mpo_id); dir.create(cache, recursive = TRUE, showWarnings = FALSE)
path_shapes_buffers = tempfile(fileext = ".rds")   # get_shapes_buffers() writes to this global
timing = tibble(stage = character(), seconds = numeric())
stage = function(name, expr){ t0 = Sys.time(); v = force(expr)
  timing <<- bind_rows(timing, tibble(stage = name, seconds = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  message("--- ", name, " ", round(tail(timing$seconds, 1), 1), " s"); v }
cached = function(name, expr){ p = file.path(cache, paste0(name, ".rds"))
  if(file.exists(p)) return(read_rds(p)); v = force(expr); saveRDS(v, p); v }

mpo = stage("mpo_polygon", get_mpo_polygon(mpo_id))
tracts = stage("tracts_assign", cached("tracts", get_mpo_tracts(mpo)))
members = sort(unique(tracts$geoid_county)); states = sort(unique(str_sub(members, 1, 2)))
message(mpo$mpo_name, ": ", length(members), " member counties in ", length(states), " state(s)")

census_tracts = stage("census_tracts", cached("census_tracts", map_dfr(states, ~retrieve_census2(.x, 2022, "tract:*"))))
census_counties = stage("census_counties", cached("census_counties", map_dfr(states, ~retrieve_census2(.x, 2022, "county:*"))))
counties = stage("shapes_counties", cached("counties", map_dfr(states, ~get_shapes_counties(members[str_sub(members,1,2) == .x], if(.x == "09") 2020 else 2022))))   # CT: old counties (CAT geography)
roads = stage("shapes_roads", cached("roads", map_dfr(states, ~get_shapes_roads(counties %>% filter(str_sub(geoid,1,2) == .x), 2022))))
buffers = stage("buffers_300", cached("buffers300", get_shapes_buffers(roads, counties, dist = 300)))
exposure = stage("area_roads_300", cached("area_roads300", get_area_roads(tracts = tracts %>% select(geoid, area_land, geometry, geoid_county), buffers = buffers)))
emissions = stage("emissions", cached("emissions", retrieve_emissions_bulk(members, 2020:2025, 110, cache_dir = "cache/cat_year")))

unit_tracts = tracts$geoid[tracts$in_unit]
idx = stage("indices", get_unit_indices(mpo$mpo_name, exposure = exposure, census_tracts = census_tracts,
  county_emissions = emissions, census_counties = census_counties, unit_tracts = unit_tracts,
  myyear = 2022, .pollutant = 110, pop_source = "tracts", extrapolate = extrap))

# members and partial-county diagnostics (race dimension)
ugv = get_unit_group_values(exposure = exposure, census_tracts = census_tracts, county_emissions = emissions,
  unit_tracts = unit_tracts, vars = DIMENSIONS$race, myyear = 2022, .pollutant = 110, pop_source = "tracts", extrapolate = extrap)
dropped = attr(ugv, "dropped"); em_method = get_emissions_year(emissions, 2022, 110, extrap)
mem = tracts %>% st_drop_geometry() %>% group_by(geoid_county) %>%
  summarize(n_tracts = n(), n_in = sum(in_unit), .groups = "drop") %>%
  left_join(ugv %>% distinct(geoid_county, emissions_county, affected_county, share_county_affected, pop_total), by = "geoid_county") %>%
  left_join(census_counties %>% select(geoid, total_population), by = c("geoid_county" = "geoid")) %>%
  left_join(em_method %>% select(geoid, years, emis_method = method), by = c("geoid_county" = "geoid")) %>%
  left_join(dropped, by = "geoid_county")

checks = tibble(
  check = c("one_polygon", "member_counties", "partial_counties", "tracts_in_unit", "no_member_dropped",
            "affected_le_pop", "eshare_sum_1", "pshare_sum_1", "indices_in_0_1"),
  value = c(nrow(mpo), length(members), sum(mem$n_in < mem$n_tracts), length(unit_tracts),
            nrow(dropped) == 0,
            all(mem$affected_county <= mem$total_population + 1e-6, na.rm = TRUE),
            all(abs(idx$eshare_sum[idx$type != "overall"] - 1) < 1e-9),
            all(abs(idx$pshare_sum[idx$type != "overall"] - 1) < 1e-9),
            all(idx$indicator2 >= 0 & idx$indicator2 <= 1)))
write_csv(idx %>% mutate(mpo_id = mpo_id), file.path(out, "indices.csv"))
write_csv(checks, file.path(out, "checks.csv")); write_csv(timing, file.path(out, "timing.csv")); write_csv(mem, file.path(out, "members.csv"))
print(idx %>% select(type, indicator2, indicator_pw, n_groups), digits = 4); print(checks); print(mem, width = 200)
cat("total seconds:", round(sum(timing$seconds)), " per member county:", round(sum(timing$seconds)/length(members), 1), "\n")
