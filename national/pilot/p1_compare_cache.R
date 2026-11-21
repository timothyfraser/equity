# P1 check: fresh downloads for the MPO's member counties equal the paper's cached NY inputs,
# and the whole-county index from fresh data equals the index from cached data.
suppressPackageStartupMessages({library(dplyr); library(readr); library(sf); library(tidyr)})
mpo_id = commandArgs(trailingOnly = TRUE)[1]
root = Sys.getenv("EQUITY_ROOT", normalizePath(if (file.exists("index/functions.R")) "." else "..")); setwd(file.path(root, "index"))
source("functions.R"); source("../national/pilot/pilot_functions.R")
c_ = function(n) read_rds(file.path("cache/national/pilot", mpo_id, paste0(n, ".rds")))
fresh_tr = c_("census_tracts"); fresh_co = c_("census_counties"); fresh_ex = c_("area_roads300"); fresh_em = c_("emissions")
members = sort(unique(fresh_ex$geoid_county))
old_tr = read_rds("test/census_tracts.rds"); old_co = read_rds("test/census_counties.rds")
old_ex = read_rds("test/area_roads300.rds") %>% filter(geoid_county %in% members)
old_em = read_rds("test/emissions_all_pollutants.rds") %>% filter(pollutant == 110, geoid %in% members)
cols = intersect(names(old_tr), names(fresh_tr))
num = function(d) d %>% select(all_of(cols)) %>% arrange(geoid) %>% as.data.frame()
tr_ids = fresh_ex$geoid
a = num(fresh_tr %>% filter(geoid %in% tr_ids)); b = num(old_tr %>% filter(geoid %in% tr_ids))
ex = fresh_ex %>% st_drop_geometry() %>% transmute(geoid, s_new = coalesce(area_roads, 0)/area_total) %>%
  full_join(old_ex %>% st_drop_geometry() %>% transmute(geoid, s_old = coalesce(area_roads, 0)/area_total), by = "geoid")
em = fresh_em %>% filter(pollutant == 110) %>% select(geoid, year, e_new = emissions) %>%
  full_join(old_em %>% select(geoid, year, e_old = emissions), by = c("geoid", "year"))
cat("member counties:", paste(members, collapse = " "), "\n")
cat("census tracts: rows", nrow(a), "vs", nrow(b), "| identical:", isTRUE(all.equal(a, b, check.attributes = FALSE)), "\n")
cat("census counties identical:", isTRUE(all.equal(num(fresh_co %>% filter(geoid %in% members)), num(old_co %>% filter(geoid %in% members)), check.attributes = FALSE)), "\n")
cat("exposure tracts: fresh", sum(!is.na(ex$s_new)), "cached", sum(!is.na(ex$s_old)),
    "| max |share diff|:", signif(max(abs(ex$s_new - ex$s_old), na.rm = TRUE), 3),
    "| share agreeing within 0.005:", round(mean(abs(ex$s_new - ex$s_old) < 0.005, na.rm = TRUE), 4), "\n")
cat("emissions rows:", nrow(em), "| missing either side:", sum(is.na(em$e_new) | is.na(em$e_old)),
    "| max rel diff:", signif(max(abs(em$e_new/em$e_old - 1), na.rm = TRUE), 3), "\n")
whole = function(ex, tr, co, em) get_unit_indices("u", exposure = ex, census_tracts = tr, county_emissions = em,
  census_counties = co, unit_tracts = ex$geoid, myyear = 2022, .pollutant = 110, pop_source = "counties")
i_new = whole(fresh_ex, fresh_tr, fresh_co, fresh_em); i_old = whole(old_ex, old_tr, old_co, read_rds("test/emissions_all_pollutants.rds"))
cmp = tibble(type = i_new$type, fresh = i_new$indicator2, cached = i_old$indicator2, diff = fresh - cached)
print(cmp, digits = 10)
cat("P1 cache check", if(max(abs(cmp$diff)) < 1e-6) "PASS" else "FAIL", "(whole-county index, fresh vs cached, tol 1e-6)\n")
