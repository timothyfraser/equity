# ND21 migration: raw county emissions are not stored in GitHub (they can be pulled from CAT public without a key).
# For every national/out/<id>/ and national/pilot/out/<id>/ whose members.csv still has emissions_county:
#   1. add emissions_mpo (sum of emissions_county * share_county_affected) and emissions_rate_mpo (= emissions_mpo / pop_in_mpo) to indices.csv
#   2. rewrite members.csv without emissions_county.
# Everything is read as text so existing values are written back unchanged (no re-rounding, no id or year mangling).
# Idempotent: folders whose members.csv has no emissions_county are skipped.
# Run from the repo root:  Rscript national/migrate_drop_county_emissions.R
library(dplyr); library(readr); library(stringr)

dirs = list.dirs(c("national/out", "national/pilot/out"), recursive = FALSE)
for(d in dirs){
  fm = file.path(d, "members.csv"); fi = file.path(d, "indices.csv")
  if(!file.exists(fm) || !file.exists(fi)) next
  mem = read_csv(fm, col_types = cols(.default = col_character()), show_col_types = FALSE)
  if(!"emissions_county" %in% names(mem)) next
  idx = read_csv(fi, col_types = cols(.default = col_character()), show_col_types = FALSE)
  emissions_mpo = sum(as.numeric(mem$emissions_county) * as.numeric(mem$share_county_affected), na.rm = TRUE)
  # national folders carry pop_in_mpo; pilot folders fall back to the member counties' in-MPO population (pop_total)
  pop = if("pop_in_mpo" %in% names(idx)) as.numeric(idx$pop_in_mpo[1]) else sum(as.numeric(mem$pop_total), na.rm = TRUE)
  idx$emissions_mpo = emissions_mpo
  idx$emissions_rate_mpo = emissions_mpo / pop
  write_csv(idx, fi)
  write_csv(mem %>% select(-emissions_county), fm)
  message("migrated ", d)
}
