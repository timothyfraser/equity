# uncertainty_acs.R
# ---------------------------------------------------------------------------------------------
# Purpose
#   U-2: how much of an index could be ACS sampling error? The paper's group counts are ACS
#   2022 5-year tract estimates, each published with a 90% margin of error (MOE). This is a
#   parametric bootstrap: redraw every raw ACS cell from its own error distribution, rebuild the
#   group matrix N, and rescore the index with index_from_tracts() (uncertainty_core.R). County
#   rates are recomputed from each draw's tract totals, so the error travels through the whole
#   chain (rate -> group emissions -> shares -> index), not just the unit's own tracts.
#
# Inputs
#   acs_cells_for(inputs, type)
#     inputs  list from unit_inputs_mpo() / unit_inputs_ny() (uses rownames(inputs$N) = tract geoids)
#     type    race, income, edu or age
#   acs_interval(inputs, type, B = 500, seed, cells = NULL, return_draws = FALSE)
#     cells   optional output of acs_cells_for() (tests pass modified copies, e.g. all MOE = 0)
#   Raw cells come from cache/national/census_moe/<state_fips>.rds (E and M per cell, ACS 2022).
#
# Method (the same for every unit)
#   X = est                              if est == 0 (ND32: zero cells stay 0)
#   X = max(0, Normal(est, (MOE/1.645)^2))   otherwise  (1.645 turns a 90% MOE into a standard error)
#   Census sentinels (negative MOE, e.g. -555555555 = controlled / not applicable) count as MOE 0.
#   NA estimates are 0, as in the paper's na.rm = TRUE sums.
#   Cells are drawn INDEPENDENTLY, which is the Census Bureau's own approximation for sums of
#   estimates. ACS cells in one table are in fact correlated, and held-at-zero cells carry
#   MOEs of 14-20 people that this method ignores, so the intervals understate the true
#   uncertainty, most for the rarest groups. All rows (unit and non-unit tracts) are redrawn.
#
# Outputs
#   acs_interval() returns c(I_obs, lo95, hi95, width, B, seed); lo95 and hi95 are the 2.5th and
#   97.5th percentiles of the B redrawn indices. With return_draws = TRUE, a list(summary, I_b, N_b_check).
#
# How to run
#   From index/:  source("uncertainty_acs.R")
#                 acs_interval(unit_inputs_mpo("36197300", "race"), "race", seed = 1)
#   Tests: Rscript index/tests/test_uncertainty_acs.R
# ---------------------------------------------------------------------------------------------

source("uncertainty_core.R")

# ---- 1. Cell-to-group mapping: written once, mirrors retrieve_census2() in functions.R ---------
.cells = function(table, nums) sprintf("%s_%03d", table, nums)
ACS_GROUPS = list(
  race = list(   # B03002; group order = RACE_VARS
    White_alone_Not_Hispanic_or_Latino_Population = "B03002_003",
    Black_or_African_American_Not_Hispanic_or_Latino_Population = "B03002_004",
    American_Indian_and_Alaska_Not_Native_Hispanic_or_Latino_Population = "B03002_005",
    Asian_Not_Hispanic_or_Latino_Population = "B03002_006",
    Native_Hawaiian_and_Other_Pacific_Islander_Not_Latino_Population = "B03002_007",
    Asian_Hispanic_or_Latino_Population = "B03002_016",
    White_alone_Hispanic_or_Latino_Population = "B03002_013",
    Black_or_African_American_Hispanic_or_Latino_Population = "B03002_014",
    American_Indian_and_Alaska_Native_Hispanic_or_Latino_Population = "B03002_015",
    Native_Hawaiian_and_Other_Pacific_Islander_Latino_Population = "B03002_017",
    Some_other_race_Not_Hispanic_or_Latino_Population = "B03002_008",
    Two_or_more_races_Not_Hispanic_or_Latino_Population = "B03002_009",
    Some_other_race_Hispanic_or_Latino_Population = "B03002_018",
    Two_or_more_races_Hispanic_or_Latino_Population = "B03002_019"),
  income = list(
    income_0_24999 = .cells("B19001", 2:5),
    income_25000_49999 = .cells("B19001", 6:10),
    income_50000_74999 = .cells("B19001", 11:12),
    income_75000_99999 = .cells("B19001", 13),
    income_100000_124999 = .cells("B19001", 14),
    income_125000_149999 = .cells("B19001", 15),
    income_150000_199999 = .cells("B19001", 16),
    income_200000_or_more = .cells("B19001", 17)),
  age = list(    # B01001, men then women
    age_under_18 = .cells("B01001", c(3:6, 27:30)),
    age_18_34 = .cells("B01001", c(7:12, 31:36)),
    age_35_64 = .cells("B01001", c(13:19, 37:43)),
    age_65_and_over = .cells("B01001", c(20:25, 44:49))),
  edu = list(    # B15003
    edu_less_than_hs = .cells("B15003", 2:16),
    edu_hs_grad = .cells("B15003", 17:18),
    edu_some_college_or_more = .cells("B15003", 19:21),
    edu_postgrad = .cells("B15003", 22:25)))

#' 0/1 matrix, raw cells x groups: X %*% G sums the drawn cells into the groups.
acs_map = function(type){
  type = match.arg(type, c("race", "income", "edu", "age"))
  grp = ACS_GROUPS[[type]][group_vars(type)]         # the input builder's column order
  cells = unlist(grp, use.names = FALSE)
  stopifnot(!anyDuplicated(cells))
  G = matrix(0, length(cells), length(grp), dimnames = list(cells, names(grp)))
  for(g in names(grp)) G[grp[[g]], g] = 1
  G
}

# ---- 2. Raw cells aligned to the input rows ---------------------------------------------------
.moe_cache = new.env()
.moe_state = function(st, root){
  if(is.null(.moe_cache[[st]])) .moe_cache[[st]] = read_rds(file.path(root, paste0(st, ".rds")))
  .moe_cache[[st]]
}

#' Raw ACS estimates (E) and standard errors (SE = MOE / 1.645) for the rows of inputs$N.
acs_cells_for = function(inputs, type, root = "cache/national/census_moe"){
  G = acs_map(type)
  cells = rownames(G)
  geoid = rownames(inputs$N)
  states = sort(unique(str_sub(geoid, 1, 2)))
  raw = map_dfr(states, ~.moe_state(.x, root))
  i = match(geoid, raw$geoid)                        # tracts missing from the pull: all cells 0
  pick = function(suffix){
    m = as.matrix(raw[i, paste0(cells, suffix), drop = FALSE])
    storage.mode(m) = "double"; dimnames(m) = list(geoid, cells); m
  }
  E = pick("E"); M = pick("M")
  E[is.na(E)] = 0
  M[is.na(M) | M < 0] = 0                            # NA and Census sentinels (-555555555 etc.)
  list(E = E, SE = M / 1.645, G = G)
}

# ---- 3. The bootstrap -------------------------------------------------------------------------

#' One draw of every raw cell: zero cells stay 0, others Normal truncated at 0 (independent cells).
acs_draw = function(E, SE, positive){
  X = E
  X[positive] = pmax(0, E[positive] + rnorm(sum(positive)) * SE[positive])
  X
}

acs_interval = function(inputs, type, B = 500, seed, cells = NULL, return_draws = FALSE){
  if(is.null(cells)) cells = acs_cells_for(inputs, type)
  I_obs = index_from_tracts(inputs$N, inputs$a, inputs$county, inputs$unit, inputs$emissions_county)[["I"]]
  positive = cells$E > 0                             # ND32: est == 0 never gets a draw
  set.seed(seed)
  I_b = numeric(B)
  for(b in seq_len(B)){
    N_b = acs_draw(cells$E, cells$SE, positive) %*% cells$G   # tracts x groups, all rows
    dimnames(N_b) = dimnames(inputs$N)
    I_b[b] = index_from_tracts(N_b, inputs$a, inputs$county, inputs$unit, inputs$emissions_county)[["I"]]
  }
  q = quantile(I_b, c(0.025, 0.975), na.rm = TRUE, names = FALSE)
  out = c(I_obs = I_obs, lo95 = q[1], hi95 = q[2], width = q[2] - q[1], B = B, seed = seed)
  if(return_draws) list(summary = out, I_b = I_b) else out
}

#' Deterministic seed per unit and type.
acs_seed = function(unit_id, type) sum(utf8ToInt(paste(unit_id, type, "acs"))) * 1000 + nchar(unit_id)
