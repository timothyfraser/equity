# national/permutation.R
# ---------------------------------------------------------------------------------------------
# Purpose   Exact permutation test (U-1) for every `done` MPO x four dimensions (race, income,
#           edu, age): is the MPO more uneven than random allocation of group labels (tract totals
#           and group totals fixed)? Raw p0, no multiplicity adjustment (ND31).
# Inputs    national/LEDGER.csv; national/tables/mpo_wide.csv (pop_in_mpo); national/results_national.json
#           (extremes, cat_manifest); index/uncertainty_core.R, index/uncertainty_permutation.R
# Outputs   national/tables/mpo_permutation.csv; national/results_permutation.json (results/v1)
# How to run  From the repo root:  Rscript national/permutation.R   (3 workers; B = 1000)
# Every number in the JSON is computed here from files, never typed.
# ---------------------------------------------------------------------------------------------
suppressPackageStartupMessages({library(dplyr); library(readr); library(purrr); library(jsonlite); library(parallel)})
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity")
setwd(file.path(root, "index"))
source("uncertainty_core.R"); source("uncertainty_permutation.R")
B = 1000L; TYPES = c("race", "income", "edu", "age")
t0 = proc.time()[["elapsed"]]

ledger = read_csv("../national/LEDGER.csv", col_types = cols(.default = "c")) |> filter(status == "done")
jobs = expand.grid(mpo_id = ledger$mpo_id, type = TYPES, stringsAsFactors = FALSE) |> as_tibble()
cat(sprintf("%d MPOs x %d types = %d jobs\n", nrow(ledger), length(TYPES), nrow(jobs)))

one = function(i){
  id = jobs$mpo_id[i]; ty = jobs$type[i]
  res = tryCatch(permute_index(unit_inputs_mpo(id, ty), B, unit_seed(id, ty)), error = function(e) e)
  if(inherits(res, "error")){ message("FAIL ", id, " ", ty, ": ", conditionMessage(res)); return(NULL) }
  bind_cols(tibble(mpo_id = id, type = ty), res)
}
out = mclapply(seq_len(nrow(jobs)), one, mc.cores = 3) |> compact() |> bind_rows() |>
  arrange(mpo_id, factor(type, TYPES))
stopifnot(nrow(out) == nrow(jobs))
write_csv(out, "../national/tables/mpo_permutation.csv")

wide = read_csv("../national/tables/mpo_wide.csv", col_types = cols(mpo_id = "c", .default = col_guess()))
d = out |> left_join(select(wide, mpo_id, pop_in_mpo), by = "mpo_id")
rn = read_json("../national/results_national.json")
leaf = function(v, ev) list(value = v, status = "computed", evidence = paste0("national/permutation.R: ", ev))
res = list(`_meta` = list(schema = "results/v1", generator = "equity/national/permutation.R",
  purpose = "Exact permutation test per MPO and dimension: raw p0 (no multiplicity adjustment), chance-adjusted index.",
  B = B, cat_manifest = rn$cat_manifest$value))
for(ty in TYPES){
  x = filter(d, type == ty)
  res[[ty]] = list(
    n_mpos = leaf(nrow(x), "rows of mpo_permutation.csv for this type"),
    n_sig_05 = leaf(sum(x$p0 < 0.05), "count of p0 < 0.05 (raw)"),
    share_sig_05 = leaf(mean(x$p0 < 0.05), "share of MPOs with p0 < 0.05 (raw)"),
    spearman_Iobs_logpop = leaf(cor(x$I_obs, log(x$pop_in_mpo), method = "spearman"), "Spearman(I_obs, log pop_in_mpo)"),
    spearman_Istar_logpop = leaf(cor(x$I_star, log(x$pop_in_mpo), method = "spearman"), "Spearman(I_star, log pop_in_mpo)"))
}
for(k in c("min", "max")){
  id = rn$extremes$race[[k]]$mpo_id$value
  r = filter(out, mpo_id == id, type == "race")
  res$extremes_race[[k]] = list(mpo_id = leaf(id, "results_national.json extremes.race"),
    p0 = leaf(r$p0, "p0 of this MPO, race"), E0 = leaf(r$E0, "E0 of this MPO, race"))
}
write_json(res, "../national/results_permutation.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)
mins = (proc.time()[["elapsed"]] - t0) / 60
cat(sprintf("RUNTIME %.1f min; rows %d; max mc_se %.5f\n", mins, nrow(out), max(out$mc_se)))
print(out |> group_by(type) |> summarize(n = n(), sig = sum(p0 < 0.05)))
