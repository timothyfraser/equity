# tests/test_uncertainty_core.R -- U-0: the matrix estimator reproduces the paper's index exactly.
# Run from the repo root:  Rscript index/tests/test_uncertainty_core.R   (setwd()s into index/)
# Checks index_from_tracts() against
#   - national/out/<id>/indices.csv (indicator2, indicator_pw) for three national MPOs, four types
#   - paper_equity/.contract/r0/results.json (table2.rerun) for two New York regions, four types
#   - synthetic units (identical group mix -> 1; an empty group is absent)
# and reports the mean time of one call for NYMTC (race). Prints PASS/FAIL; exits 1 on any failure.
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity")
setwd(file.path(root, "index"))
source("uncertainty_core.R")

n_fail = 0
check = function(name, ok){
  ok = isTRUE(all(ok))
  cat(if(ok) "PASS" else "FAIL", " ", name, "\n", sep = "")
  if(!ok) n_fail <<- n_fail + 1
}
tol = 1e-10
TYPES = c("race", "income", "edu", "age")

# 1. National MPOs: equal to the national engine's committed indices.csv
for(id in c("36197300", "37198001", "21197300")){
  idx = read_csv(file.path("../national/out", id, "indices.csv"), show_col_types = FALSE)
  for(t in TYPES){
    got = do.call(index_from_tracts, unit_inputs_mpo(id, t))
    want = idx |> filter(type == t)
    check(sprintf("MPO %s %-6s I    %.12f vs indicator2   %.12f", id, t, got[["I"]], want$indicator2),
          abs(got[["I"]] - want$indicator2) < tol)
    check(sprintf("MPO %s %-6s I_pw %.12f vs indicator_pw %.12f", id, t, got[["I_pw"]], want$indicator_pw),
          abs(got[["I_pw"]] - want$indicator_pw) < tol)
    check(sprintf("MPO %s %-6s n_groups %d == %d", id, t, got[["n_groups"]], want$n_groups),
          got[["n_groups"]] == want$n_groups)
  }
}

# 2. New York regions: equal to the paper's results contract (variant rerun)
res = read_json("/home/user/paper_equity/.contract/r0/results.json")$table2$rerun
for(r in c("Capital District", "Mohawk Valley")){
  for(t in TYPES){
    got = do.call(index_from_tracts, unit_inputs_ny(r, t))
    w_i = res[[r]][[t]]$value; w_pw = res[[r]][[paste0(t, "_pw")]]$value
    check(sprintf("NY %-16s %-6s I    %.12f vs %.12f", r, t, got[["I"]], w_i), abs(got[["I"]] - w_i) < tol)
    check(sprintf("NY %-16s %-6s I_pw %.12f vs %.12f", r, t, got[["I_pw"]], w_pw), abs(got[["I_pw"]] - w_pw) < tol)
  }
}

# 3. Synthetic units
# Three tracts in two counties, every tract with the same group mix (different sizes and exposure):
# every group gets the same emissions per resident, so both indices are exactly 1.
mix = c(g1 = 0.5, g2 = 0.3, g3 = 0.2)
N = outer(c(100, 250, 40), mix); colnames(N) = names(mix)
syn = list(N = N, a = c(0.2, 0.7, 0.5), county = c("00001", "00001", "00002"), unit = rep(TRUE, 3),
           emissions_county = c("00001" = 10, "00002" = 3))
s = do.call(index_from_tracts, syn)
check(sprintf("synthetic identical mix -> I = 1 (got %.15f)", s[["I"]]), abs(s[["I"]] - 1) < 1e-12)
check(sprintf("synthetic identical mix -> I_pw = 1 (got %.15f)", s[["I_pw"]]), abs(s[["I_pw"]] - 1) < 1e-12)
check("synthetic identical mix -> n_groups = 3", s[["n_groups"]] == 3)

# A group with nobody in the unit is absent: n_groups excludes it, and I equals the paper's
# get_region_group_values() + get_indicator() on the same numbers.
N2 = cbind(N, g4 = 0); N2[2, "g1"] = 400        # uneven, plus an empty group
syn2 = modifyList(syn, list(N = N2))
s2 = do.call(index_from_tracts, syn2)
cgv = tibble(geoid_county = rep(syn$county, each = 4), group = rep(colnames(N2), 3), value = as.vector(t(N2)),
             a = rep(syn$a, each = 4)) |>
  mutate(affected = value * a) |>
  group_by(geoid_county) |> mutate(affected_total = sum(affected)) |> ungroup() |>
  mutate(emissions = syn$emissions_county[geoid_county]) |>
  group_by(geoid_county, group) |>
  summarize(affected = sum(affected), pop = sum(value), affected_total = first(affected_total),
            emissions = first(emissions), .groups = "drop") |>
  group_by(geoid_county) |> mutate(pop_total = sum(pop)) |> ungroup() |>
  mutate(emissions_group = affected * emissions / affected_total, region = "u")
rgv = get_region_group_values(cgv, myvars = colnames(N2))
ind = get_indicator(rgv)
check(sprintf("synthetic empty group -> n_groups = 3 (got %d; paper %d)", s2[["n_groups"]], sum(!is.na(rgv$epshare))),
      s2[["n_groups"]] == 3 && sum(!is.na(rgv$epshare)) == 3)
check(sprintf("synthetic empty group -> I %.12f == paper %.12f", s2[["I"]], ind$indicator2), abs(s2[["I"]] - ind$indicator2) < 1e-12)
check(sprintf("synthetic empty group -> I_pw %.12f == paper %.12f", s2[["I_pw"]], ind$indicator_pw),
      abs(s2[["I_pw"]] - ind$indicator_pw) < 1e-12)

# A county with no emissions is dropped and named
syn3 = modifyList(syn, list(emissions_county = c("00001" = 10)))
s3 = do.call(index_from_tracts, syn3)
check("county with no emissions is dropped and named", identical(attr(s3, "dropped"), "00002"))

# 4. Timing: NYMTC (36198201), race, 100 calls
x = unit_inputs_mpo("36198201", "race")
invisible(do.call(index_from_tracts, x))   # warm up
t0 = proc.time()[["elapsed"]]
for(i in 1:100) invisible(do.call(index_from_tracts, x))
ms = (proc.time()[["elapsed"]] - t0) / 100 * 1000
cat(sprintf("TIMING NYMTC race: %d tracts x %d groups, mean %.2f ms per call (100 calls)\n", nrow(x$N), ncol(x$N), ms))
check(sprintf("NYMTC race one call < 10 ms (%.2f ms)", ms), ms < 10)

cat(sprintf("\n%d failure(s)\n", n_fail))
quit(status = if(n_fail > 0) 1 else 0)
