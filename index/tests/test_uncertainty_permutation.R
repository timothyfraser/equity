# tests/test_uncertainty_permutation.R -- U-1: the permutation test.
# Run from the repo root:  Rscript index/tests/test_uncertainty_permutation.R   (setwd()s into index/)
# Checks: margins preserved; mixed unit -> I=1,p0=1,I*=1; segregated unit -> p0 = 1/(B+1);
# same seed -> identical output; MPO 36197300 race I_obs == indicator2. Exits 1 on any failure.
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity")
setwd(file.path(root, "index"))
source("uncertainty_core.R"); source("uncertainty_permutation.R")
n_fail = 0
check = function(name, ok){
  ok = isTRUE(all(ok)); cat(if(ok) "PASS" else "FAIL", " ", name, "\n", sep = "")
  if(!ok) n_fail <<- n_fail + 1
}
B = 200L
# Synthetic unit: 6 tracts in 2 counties, 2 groups
tot = c(100, 250, 40, 80, 120, 60); a = c(0.8, 0.7, 0.6, 0.1, 0.05, 0.1)
cty = c(rep("00001", 3), rep("00002", 3)); em = c("00001" = 10, "00002" = 4)
mk = function(N) list(N = N, a = a, county = cty, unit = rep(TRUE, 6), emissions_county = em)

# (a) margins
set.seed(1)
N = cbind(g1 = round(tot * c(.5,.2,.9,.1,.4,.3)), g2 = tot - round(tot * c(.5,.2,.9,.1,.4,.3)))
tabs = r2dtable(50, rowSums(N), colSums(N))
check("every permuted table keeps both margins",
      all(vapply(tabs, function(t) all(rowSums(t) == rowSums(N)) && all(colSums(t) == colSums(N)), TRUE)))

# (b) mixed unit
Nm = outer(tot, c(g1 = .5, g2 = .5)); r = permute_index(mk(Nm), B, 7)
check(sprintf("mixed: I_obs = 1 (%.12f)", r$I_obs), abs(r$I_obs - 1) < 1e-12)
check(sprintf("mixed: p0 = 1 (%.4f)", r$p0), r$p0 == 1)
check(sprintf("mixed: I_star = 1 (%.12f)", r$I_star), abs(r$I_star - 1) < 1e-12)

# (c) segregated: g1 only in exposed tracts 1-3, g2 only in tracts 4-6
Ns = cbind(g1 = c(tot[1:3], 0, 0, 0), g2 = c(0, 0, 0, tot[4:6]))
r = permute_index(mk(Ns), B, 7)
check(sprintf("segregated: p0 = 1/(B+1) (%.6f vs %.6f)", r$p0, 1/(B+1)), abs(r$p0 - 1/(B+1)) < 1e-12)

# (d) reproducibility
check("same seed gives identical output", identical(permute_index(mk(Ns), B, 99), permute_index(mk(Ns), B, 99)))

# (e) MPO 36197300 race equals indicator2
idx = read_csv("../national/out/36197300/indices.csv", show_col_types = FALSE) |> filter(type == "race")
r = permute_index(unit_inputs_mpo("36197300", "race"), 50, unit_seed("36197300", "race"))
check(sprintf("MPO 36197300 race I_obs %.12f == indicator2 %.12f", r$I_obs, idx$indicator2), abs(r$I_obs - idx$indicator2) < 1e-10)

cat(sprintf("\n%d failure(s)\n", n_fail)); quit(status = if(n_fail > 0) 1 else 0)
