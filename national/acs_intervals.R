# national/acs_intervals.R
# ---------------------------------------------------------------------------------------------
# Purpose   U-2: ACS sampling-error 95% intervals for the index of every finished MPO, four types.
# Inputs    national/LEDGER.csv (status == done), national/tables/mpo_wide.csv,
#           national/results_national.json (extremes), index/cache/national/census_moe/*.rds
# Outputs   national/tables/mpo_acs_intervals.csv, national/results_acs.json
# How to run  Rscript national/acs_intervals.R   (from the repo root; it setwd()s into index/)
# Method    index/uncertainty_acs.R (500 independent-cell draws, zero cells held at 0).
# ---------------------------------------------------------------------------------------------
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity")
setwd(file.path(root, "index"))
source("uncertainty_acs.R")
t0 = proc.time()[["elapsed"]]
B = 500
TYPES = c("race", "income", "edu", "age")

ledger = read_csv("../national/LEDGER.csv", col_types = cols(.default = "c")) |> filter(status == "done")
jobs = expand_grid(mpo_id = ledger$mpo_id, type = TYPES)
cat(sprintf("%d MPOs x %d types = %d jobs, B = %d\n", nrow(ledger), length(TYPES), nrow(jobs), B))

one = function(k){
  id = jobs$mpo_id[k]; type = jobs$type[k]
  r = tryCatch(acs_interval(unit_inputs_mpo(id, type), type, B = B, seed = acs_seed(id, type)),
               error = function(e) {message("FAILED ", id, " ", type, ": ", conditionMessage(e)); NULL})
  if(is.null(r)) return(NULL)
  tibble(mpo_id = id, type = type, I_obs = r[["I_obs"]], lo95 = r[["lo95"]], hi95 = r[["hi95"]],
         width = r[["width"]], B = B, seed = r[["seed"]])
}
res = parallel::mclapply(seq_len(nrow(jobs)), one, mc.cores = 3)
bad = sum(map_lgl(res, is.null))
iv = bind_rows(res)
write_csv(iv, "../national/tables/mpo_acs_intervals.csv")

# ---- summary leaves ---------------------------------------------------------------------------
wide = read_csv("../national/tables/mpo_wide.csv", col_types = cols(mpo_id = "c", .default = col_guess()))
ext = read_json("../national/results_national.json")$extremes$race
leaf = function(v, ev) list(value = v, status = "computed", evidence = ev)
src = "national/acs_intervals.R: "

by_type = map(set_names(TYPES), function(t){
  d = iv |> filter(type == t) |> left_join(select(wide, mpo_id, pop_in_mpo), by = "mpo_id")
  med = median(d$I_obs)
  list(n_mpos = leaf(nrow(d), paste0(src, "rows of mpo_acs_intervals.csv for ", t)),
       median_width = leaf(median(d$width), paste0(src, "median of hi95 - lo95 over MPOs")),
       median_I_obs = leaf(med, paste0(src, "median of I_obs over MPOs")),
       share_excluding_national_median = leaf(mean(d$lo95 > med | d$hi95 < med),
         paste0(src, "share of MPOs whose [lo95, hi95] excludes the median I_obs")),
       spearman_width_logpop = leaf(unname(cor(d$width, log(d$pop_in_mpo), method = "spearman")),
         paste0(src, "Spearman(width, log pop_in_mpo from mpo_wide.csv)")))
})
extreme = map(c(min = "min", max = "max"), function(w){
  id = ext[[w]]$mpo_id$value
  r = iv |> filter(mpo_id == id, type == "race")
  list(mpo_id = leaf(id, "national/results_national.json extremes.race"),
       mpo_name = leaf(ext[[w]]$mpo_name$value, "national/results_national.json extremes.race"),
       I_obs = leaf(r$I_obs, paste0(src, "race interval table")), lo95 = leaf(r$lo95, paste0(src, "race interval table")),
       hi95 = leaf(r$hi95, paste0(src, "race interval table")))
})
secs = proc.time()[["elapsed"]] - t0
out = list(
  `_meta` = list(schema = "results/v1", generator = "equity/national/acs_intervals.R",
                 purpose = "ACS sampling-error 95% intervals for the MPO indices (parametric bootstrap on tract MOEs).",
                 B = B, acs = "ACS 2022 5-year, tract, 90% MOE / 1.645",
                 caveat = "Cells drawn independently; zero-estimate cells held at 0 (ND32); understates uncertainty for rare groups."),
  failed_jobs = leaf(bad, paste0(src, "jobs that errored")),
  runtime_seconds = leaf(round(secs, 1), paste0(src, "wall time, 3 cores")),
  by_type = by_type, extremes_race = extreme)
write_json(out, "../national/results_acs.json", auto_unbox = TRUE, digits = NA, pretty = TRUE)
cat(sprintf("done: %d rows, %d failed, %.1f s (%.1f min)\n", nrow(iv), bad, secs, secs / 60))
