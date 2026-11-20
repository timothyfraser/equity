# make_census.R: rebuild the New York ACS 2022 5-year caches (tracts and counties) with retrieve_census2().
# Run headless from index/:  Rscript make_census.R   (needs CENSUS_API_KEY in the environment)
# Refuses to overwrite unless every column already in the old cache is unchanged.
suppressMessages({library(dplyr); library(readr)})
source("functions.R")
for(level in c("tract", "county")){
  path = sprintf("test/census_%ss.rds", if(level == "tract") "tract" else "countie")
  new = retrieve_census2(state_fips = "36", year = 2022, region = paste0(level, ":*"))
  if(file.exists(path)){
    old = read_rds(path)
    keep = intersect(names(old), names(new))
    a = old %>% select(all_of(keep)) %>% arrange(geoid) %>% as.data.frame()
    b = new %>% select(all_of(keep)) %>% arrange(geoid) %>% as.data.frame()
    same = isTRUE(all.equal(a, b, check.attributes = FALSE))
    message(level, ": ", nrow(new), " rows; old columns unchanged: ", same, "; added: ", paste(setdiff(names(new), names(old)), collapse = ", "))
    if(!same) stop("Existing columns changed in ", path, "; not overwriting.")
  }
  saveRDS(new, path)
}
