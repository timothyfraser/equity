# uncertainty_core.R
# ---------------------------------------------------------------------------------------------
# Purpose
#   One fast, matrix-based copy of the paper's estimator, so the permutation test (U-1, many
#   r2dtable() draws) and the ACS sampling-error bootstrap (U-2, many perturbed count matrices)
#   score every draw with exactly the estimator the paper reports. It reproduces, step by step,
#   national/pilot/pilot_functions.R::get_unit_group_values() + index/functions.R::
#   get_region_group_values() + get_indicator(), and calls the paper's own get_index().
#   It is called about a million times, so the hot function index_from_tracts() uses base R
#   matrix algebra only (no dplyr); the input builders below it use the tidyverse.
#
# Inputs
#   index_from_tracts(N, a, county, unit, emissions_county)
#     N                tracts x groups numeric matrix of residents (every tract of every member
#                      county; column names = group variable names). No NA: the builders set
#                      missing ACS cells to 0, which is what the paper's na.rm = TRUE sums do.
#     a                tract exposed share, area_roads / area_total (NA or non-finite -> 0)
#     county           tract county geoid (character; for Connecticut the old county, as in CAT)
#     unit             logical, TRUE for tracts inside the MPO or region
#     emissions_county named numeric vector of 2022 county emissions (names = county geoids)
#   unit_inputs_mpo(mpo_id, type)   reads the national engine's caches for one MPO
#   unit_inputs_ny(region, type)    reads the paper's New York inputs for one region
#   type is one of race, income, edu, age.
#
# Outputs
#   index_from_tracts() returns c(I = equal-group index (indicator2), I_pw = population-weighted
#   companion (indicator_pw), n_groups = groups present). Counties that cannot be scored (no 2022
#   emissions, or no exposed residents) are dropped, as in get_unit_group_values(), and their
#   geoids are attached as attr(, "dropped").
#   unit_inputs_*() return list(N, a, county, unit, emissions_county), ready for do.call().
#
# How to run
#   From index/ (the scripts setwd there, like every other index script):
#     source("uncertainty_core.R")
#     x = unit_inputs_mpo("36197300", "race")
#     do.call(index_from_tracts, x)
#   Tests: Rscript index/tests/test_uncertainty_core.R  (from the repo root)
#
# Numbers come from files, never from typing: every value this produces is computed from the
# cached inputs, and the tests check it against the committed national/out/<id>/indices.csv and
# paper_equity/.contract/r0/results.json.
# ---------------------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(purrr); library(sf); library(jsonlite)
})

# The paper's library. functions.R ends one definition with a stray top-level call that reads
# data at source time, so (as in tests/test_index.R) evaluate only its assignments.
if(!exists("get_index", mode = "function")){
  for(e in parse(file = "functions.R")){
    if(is.call(e) && as.character(e[[1]]) %in% c("=", "<-")) eval(e, envir = globalenv())
  }
}
# get_emissions_year() and DIMENSIONS (the national engine's group definitions)
if(!exists("get_emissions_year", mode = "function")) source("../national/pilot/pilot_functions.R")

# ---- 1. The estimator -----------------------------------------------------------------------

#' Equal-group index and population-weighted companion for one unit, from tract matrices.
index_from_tracts = function(N, a, county, unit, emissions_county){
  # Exposed residents per tract (all groups): rowSums(N) * a. Summed over the WHOLE county,
  # in or out of the unit, this is the denominator of the county rate (Eq. 7).
  exposed_tract = rowSums(N) * a
  exposed_county = rowsum(exposed_tract, county, reorder = FALSE)[, 1]
  counties = names(exposed_county)
  emis = unname(emissions_county[counties])      # NA when a county has no 2022 value
  rate_county = emis / exposed_county

  # A county with no emissions, or nobody exposed, cannot be scored: drop all its tracts
  bad = is.na(emis) | !(exposed_county > 0)
  rate_tract = rate_county[match(county, counties)]
  keep = unit & !bad[match(county, counties)]

  # Unit tracts only: group emissions = sum_t N_tg * a_t * rate_t; group population = sum_t N_tg
  Nu = N[keep, , drop = FALSE]
  emissions_g = drop(crossprod(Nu, a[keep] * rate_tract[keep]))
  pop_g = colSums(Nu)

  eshare = emissions_g / sum(emissions_g)
  pshare = pop_g / sum(pop_g)
  # Population-adjusted share (get_region_group_values): a group with nobody in the unit is
  # absent (NA, not scored); a group present with no emissions share keeps 0; then renormalise.
  epshare = eshare / pshare
  epshare[is.nan(epshare) | is.infinite(epshare)] = 0
  epshare[pshare == 0] = NA_real_
  epshare = epshare / sum(epshare, na.rm = TRUE)

  out = c(I = get_index(epshare),                                  # the paper's index (indicator2)
          I_pw = 1 - 0.5 * sum(abs(eshare - pshare), na.rm = TRUE), # 1 - Duncan dissimilarity (indicator_pw)
          n_groups = sum(!is.na(epshare)))
  attr(out, "dropped") = counties[bad]
  out
}

# ---- 2. Input builders ----------------------------------------------------------------------

#' Group columns for a dimension, as the national engine and the paper define them.
group_vars = function(type){
  type = match.arg(type, c("race", "income", "edu", "age"))
  if(type == "race") RACE_VARS else DIMENSIONS[[type]]
}

#' Tract table + census table -> the matrix inputs. `tr` has geoid, county, a, unit.
build_inputs = function(tr, census, vars, emissions_county){
  N = census[match(tr$geoid, census$geoid), vars, drop = FALSE] |> as.matrix()
  N[is.na(N)] = 0                                   # paper: sum(..., na.rm = TRUE)
  storage.mode(N) = "double"
  rownames(N) = tr$geoid
  a = tr$a; a[!is.finite(a)] = 0                    # paper: NA area -> affected NA -> dropped by na.rm
  list(N = N, a = a, county = tr$county, unit = tr$unit, emissions_county = emissions_county)
}

#' Inputs for one national MPO, from the caches national/run_mpo.R wrote.
unit_inputs_mpo = function(mpo_id, type, cache_root = "cache/national", out_root = "../national/out"){
  vars = group_vars(type)
  work = file.path(cache_root, "mpo_work", mpo_id)
  tracts = read_rds(file.path(work, "tracts.rds")) |> st_drop_geometry()
  exposure = read_rds(file.path(work, "area_roads300.rds")) |> st_drop_geometry()
  # Connecticut: tracts.rds carries the old-county geoid_county (CAT's counties); use it, not the
  # tract geoid prefix (a planning region). The exposure table inherits it; check they agree.
  county = tracts$geoid_county[match(exposure$geoid, tracts$geoid)]
  stopifnot(!anyNA(county), identical(county, exposure$geoid_county))
  states = sort(unique(str_sub(tracts$geoid_county, 1, 2)))
  census = map_dfr(states, ~read_rds(file.path(cache_root, "census", paste0(.x, "_tract.rds"))))
  manifest = read_json(file.path(out_root, mpo_id, "status.json"))$manifest |> sub(pattern = "\\.tsv$", replacement = "")
  em = read_rds(file.path(work, paste0("emissions_", manifest, ".rds"))) |>
    get_emissions_year(2022, 110, "none")
  tr = tibble(geoid = exposure$geoid, county = county,
              a = exposure$area_roads / exposure$area_total,
              unit = exposure$geoid %in% tracts$geoid[tracts$in_unit])
  build_inputs(tr, census, vars, set_names(em$emissions, em$geoid))
}

#' Inputs for one New York region of the paper (variant rerun: 2022 interpolated, PM2.5, 300 m).
#' Every tract of the region's counties is in the unit. Rows are all ACS tracts of those counties,
#' so tracts without land area (not in the exposure file, a = 0) still count toward population,
#' exactly as the paper's county ACS totals do.
unit_inputs_ny = function(region, type){
  vars = group_vars(type)
  members = read_rds("data/regions_ny_data.rds") |> filter(region == !!region) |> pull(geoid)
  stopifnot(length(members) > 0)
  census = read_rds("test/census_tracts.rds") |> mutate(county = str_sub(geoid, 1, 5)) |> filter(county %in% members)
  exposure = read_rds("test/area_roads300.rds") |> st_drop_geometry()
  em = read_rds("test/emissions_all_pollutants.rds") |> filter(pollutant == 110) |>
    get_emissions_interpolated(year = 2022) |> mutate(geoid = str_pad(geoid, 5, "left", "0"))
  # the whole county's tracts set the rate, and every one of them is in the unit
  ex = exposure[match(census$geoid, exposure$geoid), ]
  tr = tibble(geoid = census$geoid, county = census$county,
              a = ex$area_roads / ex$area_total, unit = TRUE)
  build_inputs(tr, census, vars, set_names(em$emissions, em$geoid))
}

# Test helpers. The national geometry and emissions caches (cache/national/mpo_work/<id>/) are written by
# national/run_mpo.R and are gitignored, because they hold raw CAT emissions (ND21). Tests that need them print SKIP,
# not FAIL, in a fresh clone; `bash replicate.sh national` creates them.
have_mpo_cache = function(id, cache_root = "cache/national") file.exists(file.path(cache_root, "mpo_work", id, "tracts.rds"))
have_ny_emissions = function() file.exists("test/emissions_all_pollutants.rds")   # written by make_emissions.R
skip = function(name) cat("SKIP ", name, "\n", sep = "")
