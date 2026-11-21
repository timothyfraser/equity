# make_census_moe.R: pull raw ACS 2022 5-year tract cells, estimates (E) and margins of error (M), for the ACS
# interval check (index/uncertainty_acs.R). One file per state: index/cache/national/census_moe/<state_fips>.rds,
# with columns geoid, <cell>E, <cell>M. The cache is gitignored; New York's copy ships in index/test/census_moe/36.rds
# so the New York replication needs no API key.
#
# Usage, from the repo root (needs CENSUS_API_KEY in the environment):
#   Rscript index/make_census_moe.R            # New York plus every state a computed MPO touches
#   Rscript index/make_census_moe.R 36 09      # just these states
# Skips states already cached. Writes atomically, so an interrupted pull never leaves a half-written file.
suppressMessages({library(dplyr); library(purrr); library(readr); library(censusapi)})
root = Sys.getenv("EQUITY_ROOT", normalizePath(if (file.exists("index/functions.R")) "." else ".."))
setwd(root)
if (!nzchar(Sys.getenv("CENSUS_API_KEY"))) stop("Set CENSUS_API_KEY (free: https://api.census.gov/data/key_signup.html)")

# The cells every index dimension is built from (see ACS_GROUPS in index/uncertainty_acs.R):
# race and ethnicity B03002, household income B19001, age B01001 (both sexes), education B15003.
cells = c(sprintf("B03002_%03d", c(3:9, 13:19)), sprintf("B19001_%03d", 2:17),
          sprintf("B01001_%03d", c(3:25, 27:49)), sprintf("B15003_%03d", 2:25))
vars = c(paste0(cells, "E"), paste0(cells, "M"))

st = commandArgs(trailingOnly = TRUE)
if (length(st) == 0) {
  mem = list.files("national/out", pattern = "^members.csv$", recursive = TRUE, full.names = TRUE)
  st = mem |> map(~read_csv(.x, show_col_types = FALSE, col_types = cols(.default = "c"))$geoid_county) |>
    unlist() |> substr(1, 2) |> unique()
  st = sort(unique(c(st, "36")))
}
out_dir = "index/cache/national/census_moe"; dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
message(length(st), " state(s); ", length(vars), " variables")
for (s in st) {
  p = file.path(out_dir, paste0(s, ".rds")); if (file.exists(p)) next
  chunks = split(vars, ceiling(seq_along(vars) / 45))   # the Census API takes at most 50 variables per call
  d = map(chunks, ~getCensus(name = "acs/acs5", vintage = 2022, vars = .x, region = "tract:*",
                             regionin = paste0("state:", s), key = Sys.getenv("CENSUS_API_KEY")) |>
            mutate(geoid = paste0(state, county, tract)) |> select(geoid, all_of(.x))) |>
    reduce(left_join, by = "geoid")
  tmp = paste0(p, ".part"); saveRDS(d, tmp); file.rename(tmp, p)
  message(s, ": ", nrow(d), " tracts")
}
