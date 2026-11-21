# P4: compare the pilot MPOs and test the two choices the national run depends on.
#   A  whole member counties, county ACS population (the paper's method applied to the MPO's counties)
#   B  whole member counties, tract-sum population   (isolates ACS tract-vs-county tables)
#   C  MPO tracts only, tract-sum population          (the pilot method; C - B isolates partial counties)
suppressPackageStartupMessages({library(dplyr); library(readr); library(sf); library(tidyr); library(purrr)})
root = Sys.getenv("EQUITY_ROOT", normalizePath(if (file.exists("index/functions.R")) "." else "..")); setwd(file.path(root, "index"))
source("functions.R"); source("../national/pilot/pilot_functions.R")
ids = c("36197300", "37198001", "21197300")
run = function(id){
  c_ = function(n) read_rds(file.path("cache/national/pilot", id, paste0(n, ".rds")))
  tr = c_("tracts"); ex = c_("area_roads300"); ct = c_("census_tracts"); cc = c_("census_counties"); em = c_("emissions")
  name = read_csv(file.path(root, "national/pilot/out", id, "indices.csv"), show_col_types = FALSE)$region[1]
  f = function(units, src) get_unit_indices(name, exposure = ex, census_tracts = ct, county_emissions = em,
        census_counties = cc, unit_tracts = units, myyear = 2022, .pollutant = 110, pop_source = src)
  A = f(ex$geoid, "counties"); B = f(ex$geoid, "tracts"); C = f(tr$geoid[tr$in_unit], "tracts")
  # small groups: race groups in the MPO under 1,000 residents (tract sums)
  small = ct %>% filter(geoid %in% tr$geoid[tr$in_unit]) %>% summarize(across(all_of(DIMENSIONS$race), ~sum(.x, na.rm = TRUE))) %>%
    pivot_longer(everything()) %>% summarize(n_lt_1000 = sum(value > 0 & value < 1000), n_zero = sum(value == 0),
                                             smallest = paste0(sub("_Population$", "", name[which.min(replace(value, value == 0, Inf))]), " (", min(value[value > 0]), ")"))
  tibble(mpo_id = id, mpo = name, type = C$type, A_whole_county = A$indicator2, B_whole_tractpop = B$indicator2,
         C_mpo = C$indicator2, C_pw = C$indicator_pw, n_groups = C$n_groups) %>%
    mutate(partial_effect = C_mpo - B_whole_tractpop, tractpop_effect = B_whole_tractpop - A_whole_county) %>%
    left_join(small %>% mutate(type = "race"), by = "type")
}
res = map_dfr(ids, run)
write_csv(res, file.path(root, "national/pilot/out/p4_compare.csv"))
options(width = 200); print(res %>% mutate(across(where(is.double), ~round(.x, 4))), n = Inf)
