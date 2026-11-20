# pilot_functions.R
# Staged MPO pilot (PLAN_NATIONAL section 12). Functions that extend index/functions.R
# from "region = whole counties" to "unit = a set of tracts" (an MPO).
# Source index/functions.R and index/cat_bulk.R first.

library(dplyr)
library(tidyr)
library(stringr)
library(readr)
library(purrr)
library(sf)

NTAD_MPO_URL = "https://services.arcgis.com/xOi1kZaI0eWDREZv/arcgis/rest/services/NTAD_Metropolitan_Planning_Organizations/FeatureServer/0/query"

#' One MPO polygon from the BTS NTAD layer, cached as GeoJSON.
get_mpo_polygon = function(mpo_id, cache_dir = "cache/national/mpo"){
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  path = file.path(cache_dir, paste0(mpo_id, ".geojson"))
  if(!file.exists(path)){
    url = paste0(NTAD_MPO_URL, "?where=", utils::URLencode(paste0("MPO_ID='", mpo_id, "'"), reserved = TRUE),
                 "&outFields=OBJECTID,MPO_ID,MPO_NAME,STATE&outSR=4326&f=geojson")
    resp = httr::GET(url, httr::write_disk(path, overwrite = TRUE))
    httr::stop_for_status(resp)
  }
  mpo = sf::st_read(path, quiet = TRUE)
  stopifnot(nrow(mpo) == 1)
  mpo %>% select(mpo_id = MPO_ID, mpo_name = MPO_NAME, mpo_state = STATE, geometry)
}

#' Assign tracts to an MPO by interior point (EPSG:5070), and list member counties.
#' Returns every tract of every county that has at least one tract inside the MPO,
#' with in_unit = TRUE for the tracts inside. Uses the same tract files as the paper
#' (tigris cartographic boundary tracts, 2022, ALAND > 0).
get_mpo_tracts = function(mpo, year = 2022){
  # planar EPSG:5070 for the point-in-polygon test; restore the caller's s2 setting
  # (the paper's buffers are built with s2 on, so it must not leak)
  old_s2 = sf::sf_use_s2(); on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)
  suppressMessages(sf::sf_use_s2(FALSE))
  counties_all = tigris::counties(cb = TRUE, year = year) %>%
    select(geoid = GEOID, geometry)
  mpo_5070 = st_transform(mpo, 5070)
  cand = counties_all %>% st_transform(5070) %>%
    st_filter(mpo_5070, .predicate = st_intersects) %>% pull(geoid)
  tracts = map_dfr(unique(str_sub(cand, 1, 2)), function(st){
    tigris::tracts(state = st, cb = TRUE, year = year)
  }) %>%
    filter(ALAND > 0) %>%
    select(geoid = GEOID, area_land = ALAND, geometry) %>%
    mutate(geoid_county = str_sub(geoid, 1, 5)) %>%
    filter(geoid_county %in% cand)
  pts = tracts %>% st_transform(5070) %>% st_point_on_surface()
  inside = lengths(st_intersects(pts, mpo_5070)) > 0
  tracts$in_unit = inside
  members = unique(tracts$geoid_county[tracts$in_unit])
  tracts %>% filter(geoid_county %in% members)
}

#' Group values for a unit of tracts (an MPO), extending get_county_group_values().
#' The emissions rate per exposed resident is computed over the WHOLE county (Eq. 7).
#' Only in-unit tracts add exposed residents, emissions and population to the unit.
#' pop_source = "counties" uses county ACS tables (only valid when every member county
#' is wholly inside the unit; reproduces get_county_group_values exactly).
#' pop_source = "tracts" sums ACS tract values over in-unit tracts.
#' Output columns match get_county_group_values(), so get_region_group_values() works unchanged:
#' for a partial county, `emissions`, `affected_total` and `pop_total` are the in-unit amounts.
get_unit_group_values = function(exposure, census_tracts, county_emissions, census_counties = NULL,
                                 unit_tracts, vars, myyear = 2022, .pollutant = 110,
                                 pop_source = c("tracts", "counties")){
  pop_source = match.arg(pop_source)
  county_emissions = county_emissions %>% filter(pollutant == .pollutant) %>%
    get_emissions_interpolated(year = myyear) %>%
    mutate(geoid = str_pad(geoid, width = 5, side = "left", pad = "0"))

  data = census_tracts %>% select(any_of(c("geoid", vars)))
  tracts2 = exposure %>% as_tibble() %>%
    select(geoid, geoid_county, area_total, area_roads) %>%
    left_join(by = "geoid", y = data) %>%
    pivot_longer(cols = any_of(vars), names_to = "group", values_to = "value") %>%
    mutate(affected = value * area_roads / area_total,
           in_unit = geoid %in% unit_tracts)

  # Whole-county rate (Eq. 7)
  rate = tracts2 %>%
    group_by(geoid_county) %>%
    summarize(affected_county = sum(affected, na.rm = TRUE), .groups = "drop") %>%
    left_join(by = c("geoid_county" = "geoid"), y = county_emissions %>% select(geoid, emissions_county = emissions)) %>%
    mutate(emissions_rate = emissions_county / affected_county)

  unit = tracts2 %>% filter(in_unit)
  affected_g = unit %>% group_by(geoid_county, group) %>%
    summarize(affected = sum(affected, na.rm = TRUE), .groups = "drop")
  affected_t = unit %>% group_by(geoid_county) %>%
    summarize(affected_total = sum(affected, na.rm = TRUE), .groups = "drop")

  if(pop_source == "counties"){
    pop = census_counties %>% select(any_of(c("geoid", vars))) %>%
      pivot_longer(cols = any_of(vars), names_to = "group", values_to = "pop") %>%
      rename(geoid_county = geoid)
  }else{
    pop = unit %>% group_by(geoid_county, group) %>%
      summarize(pop = sum(value, na.rm = TRUE), .groups = "drop")
  }
  pop = pop %>% group_by(geoid_county) %>% mutate(pop_total = sum(pop, na.rm = TRUE)) %>% ungroup()

  affected_g %>%
    left_join(by = "geoid_county", y = rate %>% select(geoid_county, emissions_county, emissions_rate, affected_county)) %>%
    left_join(by = "geoid_county", y = affected_t) %>%
    mutate(emissions_group = affected * emissions_rate,
           # in-unit emissions: equals emissions_county when the whole county is in the unit
           emissions = affected_total * emissions_rate,
           share_county_affected = affected_total / affected_county) %>%
    left_join(by = c("geoid_county", "group"), y = pop) %>%
    select(geoid_county, emissions, emissions_rate, affected_total, pop_total, group, affected,
           emissions_group, pop, emissions_county, affected_county, share_county_affected)
}

DIMENSIONS = list(
  age = c("age_under_18", "age_18_34", "age_35_64", "age_65_and_over"),
  income = c("income_0_24999", "income_25000_49999", "income_50000_74999", "income_75000_99999",
             "income_100000_124999", "income_125000_149999", "income_150000_199999", "income_200000_or_more"),
  edu = c("edu_less_than_hs", "edu_hs_grad", "edu_some_college_or_more", "edu_postgrad"),
  race = c("White_alone_Not_Hispanic_or_Latino_Population",
           "Black_or_African_American_Not_Hispanic_or_Latino_Population",
           "American_Indian_and_Alaska_Not_Native_Hispanic_or_Latino_Population",
           "Asian_Not_Hispanic_or_Latino_Population",
           "Native_Hawaiian_and_Other_Pacific_Islander_Not_Latino_Population",
           "Asian_Hispanic_or_Latino_Population",
           "White_alone_Hispanic_or_Latino_Population",
           "Black_or_African_American_Hispanic_or_Latino_Population",
           "American_Indian_and_Alaska_Native_Hispanic_or_Latino_Population",
           "Native_Hawaiian_and_Other_Pacific_Islander_Latino_Population"))

#' All four dimensions plus overall (mean of the four), for one unit.
get_unit_indices = function(unit_name, ...){
  out = imap_dfr(DIMENSIONS, function(v, type){
    ugv = get_unit_group_values(vars = v, ...) %>% mutate(region = unit_name)
    rgv = get_region_group_values(ugv, myvars = v, region = "region")
    get_indicator(rgv, type = type) %>%
      mutate(n_groups = sum(!is.na(rgv$epshare)),
             eshare_sum = sum(rgv$eshare), pshare_sum = sum(rgv$pshare))
  })
  bind_rows(out, out %>% group_by(region) %>%
              summarize(across(c(indicator2, indicator_legacy, indicator_pw), ~mean(.x, na.rm = TRUE)), .groups = "drop") %>%
              mutate(type = "overall"))
}
