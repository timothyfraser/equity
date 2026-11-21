# uncertainty_permutation.R
# ---------------------------------------------------------------------------------------------
# Purpose
#   Exact permutation test for the equal-group index (U-1, ND27). Question: is a unit (an MPO or
#   a New York region) more uneven in its emissions burden across groups than chance? The null
#   world shuffles group labels among the unit's residents, holding fixed (i) each tract's
#   resident total and (ii) each group's total in the unit. Tract exposure and county emissions
#   stay as observed, so only who lives where changes. Each shuffled world is scored with the
#   paper's own estimator (index_from_tracts() in uncertainty_core.R).
#
# Inputs
#   permute_index(inputs, B = 1000, seed)
#     inputs  list(N, a, county, unit, emissions_county) from unit_inputs_mpo() / unit_inputs_ny()
#     B       number of shuffled tables (1000)
#     seed    integer; set.seed(seed) is called immediately before the draws
#   unit_seed(unit_id, type) gives the deterministic seed (depends only on the id and type, so
#   results do not depend on run order or worker count).
#
# Outputs
#   One-row tibble: I_obs; E0 (mean of the null index); q025, q975 (null 2.5/97.5 percentiles);
#   mc_se = sd(I_b) / sqrt(B) (Monte Carlo standard error of E0); p0 = (1 + #{I_b <= I_obs}) / (B + 1)
#   (one-sided: more uneven than chance); I_star = 1 - max(0, (U_obs - E0U) / (1 - E0U)) with
#   U = 1 - I (the chance-adjusted index); n_groups, B, seed.
#   Raw p0 only: no multiplicity adjustment (ND31).
#
# How to run
#   From index/:  source("uncertainty_permutation.R")
#     x = unit_inputs_mpo("36197300", "race"); permute_index(x, 1000, unit_seed("36197300", "race"))
#   National loop: Rscript national/permutation.R (repo root). Tests: Rscript index/tests/test_uncertainty_permutation.R
# ---------------------------------------------------------------------------------------------

if(!exists("index_from_tracts", mode = "function")) source("uncertainty_core.R")

#' Deterministic seed from a unit id and dimension.
unit_seed = function(unit_id, type){
  as.integer(sum(utf8ToInt(paste(unit_id, type))) * 1000 + nchar(unit_id))
}

#' Draw B margin-preserving tables and return the null summary for one unit and dimension.
permute_index = function(inputs, B = 1000, seed){
  N = inputs$N; U = inputs$unit
  obs = do.call(index_from_tracts, inputs)
  # Integer counts for r2dtable (ACS counts are whole numbers; rounding is a no-op there)
  Nu = N[U, , drop = FALSE]
  Nu = matrix(as.integer(round(Nu)), nrow(Nu), ncol(Nu))
  set.seed(seed)
  tabs = r2dtable(B, rowSums(Nu), colSums(Nu))   # tract totals and group totals fixed
  Ib = numeric(B)
  Nb = N                                         # rows outside the unit stay as observed
  for(b in seq_len(B)){
    Nb[U, ] = tabs[[b]]
    Ib[b] = index_from_tracts(Nb, inputs$a, inputs$county, U, inputs$emissions_county)[["I"]]
  }
  I_obs = obs[["I"]]
  E0 = mean(Ib)
  U_obs = 1 - I_obs; E0U = mean(1 - Ib)
  tibble::tibble(
    I_obs = I_obs, E0 = E0,
    q025 = unname(quantile(Ib, 0.025)), q975 = unname(quantile(Ib, 0.975)),
    mc_se = sd(Ib) / sqrt(B),
    p0 = (1 + sum(Ib <= I_obs)) / (B + 1),
    I_star = 1 - max(0, (U_obs - E0U) / (1 - E0U)),
    n_groups = obs[["n_groups"]], B = B, seed = seed
  )
}
