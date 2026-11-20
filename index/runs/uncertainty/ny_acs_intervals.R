# index/runs/uncertainty/ny_acs_intervals.R
# ---------------------------------------------------------------------------------------------
# Purpose   U-2 for New York: ACS sampling-error 95% intervals for the ten regions x four types
#           (variant rerun inputs via unit_inputs_ny()).
# Outputs   index/runs/uncertainty/ny_acs_intervals.csv  (region, type, I_obs, lo95, hi95, width, B, seed)
# How to run  Rscript index/runs/uncertainty/ny_acs_intervals.R   (from the repo root)
# ---------------------------------------------------------------------------------------------
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity")
setwd(file.path(root, "index"))
source("uncertainty_acs.R")
B = 500
regions = read_rds("data/regions_ny_data.rds") |> distinct(region) |> pull(region)
jobs = expand_grid(region = regions, type = c("race", "income", "edu", "age"))
res = parallel::mclapply(seq_len(nrow(jobs)), function(k){
  r = acs_interval(unit_inputs_ny(jobs$region[k], jobs$type[k]), jobs$type[k], B = B,
                   seed = acs_seed(jobs$region[k], jobs$type[k]))
  tibble(region = jobs$region[k], type = jobs$type[k], I_obs = r[["I_obs"]], lo95 = r[["lo95"]],
         hi95 = r[["hi95"]], width = r[["width"]], B = B, seed = r[["seed"]])
}, mc.cores = 3)
out = bind_rows(res)
write_csv(out, "runs/uncertainty/ny_acs_intervals.csv")
cat(sprintf("%d rows\n", nrow(out)))
