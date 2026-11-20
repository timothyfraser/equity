# run_mpo.R: the national engine for one MPO (same chain as national/pilot/run_pilot_mpo.R).
# Usage (from repo root): Rscript national/run_mpo.R <MPO_ID>
# Writes national/out/<MPO_ID>/status.json always, plus indices.csv, checks.csv, members.csv, timing.csv
# when the MPO is computed. Status values:
#   done          computed
#   single_county all tracts in one county (not on the national chart, ND5)
#   blocked_cat   a member county has no CAT value for 2022 (no CAT data, or no year on one side of 2022);
#                 rerun after new CAT runs are published (national/run_national.sh does this)
#   error         anything else; message in status.json
# Downloads and geometry are cached under index/cache/ (census by state; emissions by CAT manifest).
suppressPackageStartupMessages({library(dplyr); library(readr); library(sf); library(purrr); library(stringr); library(tidyr); library(jsonlite)})
mpo_id = commandArgs(trailingOnly = TRUE)[1]
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity")
setwd(file.path(root, "index"))
source("functions.R"); source("cat_bulk.R"); source("../national/pilot/pilot_functions.R")
options(tigris_use_cache = TRUE)
out = file.path(root, "national/out", mpo_id); dir.create(out, recursive = TRUE, showWarnings = FALSE)
cache = file.path("cache/national/mpo_work", mpo_id); dir.create(cache, recursive = TRUE, showWarnings = FALSE)
census_cache = "cache/national/census"; dir.create(census_cache, recursive = TRUE, showWarnings = FALSE)
path_shapes_buffers = tempfile(fileext = ".rds")   # get_shapes_buffers() writes to this global
t_start = Sys.time()
timing = tibble(stage = character(), seconds = numeric())
stage = function(name, expr){ t0 = Sys.time(); v = force(expr)
  timing <<- bind_rows(timing, tibble(stage = name, seconds = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  message("--- ", name, " ", round(tail(timing$seconds, 1), 1), " s"); v }
cached = function(name, expr){ p = file.path(cache, paste0(name, ".rds"))
  if(file.exists(p)) return(read_rds(p)); v = force(expr); saveRDS(v, p); v }
census_state = function(st, level){ p = file.path(census_cache, sprintf("%s_%s.rds", st, level))
  if(file.exists(p)) return(read_rds(p)); v = retrieve_census2(st, 2022, paste0(level, ":*"))
  # atomic write: parallel workers share this cache, so never expose a half-written file
  tmp = tempfile(tmpdir = census_cache, fileext = ".tmp"); saveRDS(v, tmp); file.rename(tmp, p); v }
manifest = cat_manifest_name()
status = list(mpo_id = mpo_id, mpo_name = NA, status = "error", n_counties = NA, n_states = NA, n_tracts_in = NA,
              blocking = list(), dropped = list(), manifest = manifest, message = NA,
              finished_utc = NA, seconds = NA)
write_status = function(){
  status$finished_utc <<- format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC")
  status$seconds <<- round(as.numeric(difftime(Sys.time(), t_start, units = "secs")), 1)
  write_json(status, file.path(out, "status.json"), auto_unbox = TRUE, pretty = TRUE, na = "null")
}

res = tryCatch({
  mpo = stage("mpo_polygon", get_mpo_polygon(mpo_id) %>% st_make_valid())
  status$mpo_name = mpo$mpo_name
  tracts = stage("tracts_assign", cached("tracts", get_mpo_tracts(mpo)))
  members = sort(unique(tracts$geoid_county)); states = sort(unique(str_sub(members, 1, 2)))
  status$n_counties = length(members); status$n_states = length(states); status$n_tracts_in = sum(tracts$in_unit)
  message(mpo$mpo_name, ": ", length(members), " member counties in ", length(states), " state(s)")
  if(length(members) < 2){ status$status = "single_county"; "stop" } else {

  # Emissions first (cheap): stop before the geometry if any member county has no 2022 value
  emissions = stage("emissions", cached(paste0("emissions_", sub("\\.tsv$", "", manifest)),
                    retrieve_emissions_bulk(members, 2020:2025, 110, cache_dir = file.path("cache/cat_year", sub("\\.tsv$", "", manifest)))))
  em = get_emissions_year(emissions, 2022, 110, "none")
  miss = tibble(geoid = members) %>% left_join(em, by = "geoid") %>% filter(is.na(emissions)) %>%
    mutate(reason = if_else(is.na(years), "no_cat_data", paste0("no_bracketing_years (", years, ")")))
  if(nrow(miss) > 0){
    status$status = "blocked_cat"
    status$blocking = map2(miss$geoid, miss$reason, ~list(geoid = .x, reason = .y))
    "stop"
  } else {

  census_tracts = stage("census_tracts", map_dfr(states, census_state, level = "tract"))
  census_counties = stage("census_counties", map_dfr(states, census_state, level = "county"))
  counties = stage("shapes_counties", cached("counties", map_dfr(states, ~get_shapes_counties(members[str_sub(members,1,2) == .x], if(.x == "09") 2020 else 2022))))
  roads = stage("shapes_roads", cached("roads", map_dfr(states, ~get_shapes_roads(counties %>% filter(str_sub(geoid,1,2) == .x), 2022))))
  buffers = stage("buffers_300", cached("buffers300", get_shapes_buffers(roads, counties, dist = 300)))
  exposure = stage("area_roads_300", cached("area_roads300", get_area_roads(tracts = tracts %>% select(geoid, area_land, geometry, geoid_county), buffers = buffers)))

  unit_tracts = tracts$geoid[tracts$in_unit]
  idx = stage("indices", get_unit_indices(mpo$mpo_name, exposure = exposure, census_tracts = census_tracts,
    county_emissions = emissions, census_counties = census_counties, unit_tracts = unit_tracts,
    myyear = 2022, .pollutant = 110, pop_source = "tracts"))
  ugv = get_unit_group_values(exposure = exposure, census_tracts = census_tracts, county_emissions = emissions,
    unit_tracts = unit_tracts, vars = DIMENSIONS$race, myyear = 2022, .pollutant = 110, pop_source = "tracts")
  dropped = attr(ugv, "dropped")
  # race groups present and under 1,000 residents in the MPO (ND10 marker)
  race_pop = census_tracts %>% filter(geoid %in% unit_tracts) %>% summarize(across(all_of(DIMENSIONS$race), ~sum(.x, na.rm = TRUE))) %>%
    pivot_longer(everything(), names_to = "group", values_to = "pop")
  mem = tracts %>% st_drop_geometry() %>% group_by(geoid_county) %>%
    summarize(n_tracts = n(), n_in = sum(in_unit), .groups = "drop") %>%
    left_join(ugv %>% distinct(geoid_county, emissions_county, affected_county, share_county_affected, pop_total), by = "geoid_county") %>%
    left_join(em %>% select(geoid, years, emis_method = method), by = c("geoid_county" = "geoid")) %>%
    left_join(dropped, by = "geoid_county")
  checks = tibble(
    check = c("one_polygon", "no_member_dropped", "eshare_sum_1", "pshare_sum_1", "indices_in_0_1"),
    pass = c(nrow(mpo) == 1, nrow(dropped) == 0,
             all(abs(idx$eshare_sum[idx$type != "overall"] - 1) < 1e-9),
             all(abs(idx$pshare_sum[idx$type != "overall"] - 1) < 1e-9),
             all(idx$indicator2 >= 0 & idx$indicator2 <= 1)))
  write_csv(idx %>% mutate(mpo_id = mpo_id, mpo_name = mpo$mpo_name,
                           race_groups_lt_1000 = sum(race_pop$pop > 0 & race_pop$pop < 1000),
                           pop_in_mpo = sum(race_pop$pop)), file.path(out, "indices.csv"))
  write_csv(checks, file.path(out, "checks.csv")); write_csv(timing, file.path(out, "timing.csv")); write_csv(mem, file.path(out, "members.csv"))
  status$dropped = map2(dropped$geoid_county, dropped$reason, ~list(geoid = .x, reason = .y))
  status$status = if(all(checks$pass)) "done" else "error"
  if(!all(checks$pass)) status$message = paste("failed checks:", paste(checks$check[!checks$pass], collapse = ", "))
  "ok"
  }}
}, error = function(e){ status$status <<- "error"; status$message <<- conditionMessage(e); "error" })
write_status()
cat(mpo_id, status$status, "\n")
