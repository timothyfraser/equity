# cat_bulk.R
# Loader for the CAT bulk Parquet files (one file per year, every US county).
# Replaces retrieve_emissions() in functions.R, which called a retired
# Cloud Run proxy (/granddata-bulk-download). No key and no tunnel needed.

library(dplyr)
library(httr)

#' @name cat_manifest_name
#' @title Name of the current CAT object manifest, e.g. "MANIFEST-e2ccfae4.tsv"
#' @param base:[str] base URL of the CAT object store
cat_manifest_name = function(base = "https://api.cat-apps.com/objects"){
  resp = httr::GET(paste0(base, "/LATEST"))
  httr::stop_for_status(resp)
  httr::content(resp, as = "text", encoding = "UTF-8") |> trimws()
}

#' @name retrieve_emissions_bulk
#' @title Read county-total emissions from the CAT bulk Parquet files
#' @param geoid:[str] vector of 5-digit county FIPS codes
#' @param year:[int] vector of years
#' @param pollutant:[int] vector of EPA pollutant IDs
#' @param base:[str] base URL of the CAT object store
#' @param cache_dir:[str] folder where each year's file is downloaded once
#' @note Keeps `by == 16` (county total). Returns a tibble with geoid (chr), pollutant (int),
#'   year (int), emissions (num), the same shape as the old `retrieve_emissions()`.
#'   Counties absent from a year's file are simply absent from the output.
retrieve_emissions_bulk = function(geoid, year, pollutant,
                                   base = "https://api.cat-apps.com/objects",
                                   cache_dir = tempdir()){
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)
  geoid = stringr::str_pad(as.character(geoid), width = 5, side = "left", pad = "0")
  
  read_one_year = function(y){
    path = file.path(cache_dir, paste0(y, ".parquet"))
    if(!file.exists(path)){
      # atomic: download to a temporary file, then rename, so a reader never sees a half-written file
      tmp = tempfile(tmpdir = cache_dir, fileext = ".part")
      resp = httr::GET(
        url = paste0(base, "/year/", y, ".parquet"),
        httr::write_disk(tmp, overwrite = TRUE))
      httr::stop_for_status(resp)
      file.rename(tmp, path)
    }
    nanoparquet::read_parquet(path) |>
      as_tibble() |>
      filter(by == 16, geoid %in% !!geoid, pollutant %in% !!pollutant) |>
      transmute(
        geoid = stringr::str_pad(as.character(geoid), width = 5, side = "left", pad = "0"),
        pollutant = as.integer(pollutant),
        year = as.integer(year),
        emissions = as.numeric(emissions))
  }
  
  purrr::map(unique(year), read_one_year) |> bind_rows()
}
