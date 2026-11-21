# index/runs/uncertainty/ny_permutation.R
# ---------------------------------------------------------------------------------------------
# Purpose   Exact permutation test (U-1, Q5) for the ten New York regions x four dimensions, on the
#           paper's variant-rerun inputs (2022 interpolated, PM2.5, 300 m). Raw p0 (ND31).
# Inputs    index/data/regions_ny_data.rds, index/test/*.rds via unit_inputs_ny()
# Outputs   index/runs/uncertainty/ny_permutation.csv (region, type, I_obs, E0, q025, q975, mc_se,
#           p0, I_star, n_groups, B, seed)
# How to run  From the repo root:  Rscript index/runs/uncertainty/ny_permutation.R
# ---------------------------------------------------------------------------------------------
root = Sys.getenv("EQUITY_ROOT", normalizePath(if (file.exists("index/functions.R")) "." else ".."))
setwd(file.path(root, "index"))
source("uncertainty_core.R"); source("uncertainty_permutation.R")
regions = read_rds("data/regions_ny_data.rds") |> distinct(region) |> pull(region)
jobs = expand.grid(region = regions, type = c("race", "income", "edu", "age"), stringsAsFactors = FALSE) |> as_tibble()
out = pmap_dfr(jobs, function(region, type){
  bind_cols(tibble(region = region, type = type),
            permute_index(unit_inputs_ny(region, type), 1000L, unit_seed(region, type)))
})
write_csv(out, "runs/uncertainty/ny_permutation.csv")
cat(sprintf("%d rows written\n", nrow(out)))
print(out |> select(region, type, I_obs, E0, p0, I_star), n = 40)
