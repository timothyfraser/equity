# tests/test_uncertainty_acs.R -- U-2: the ACS bootstrap is wired correctly.
# Run from the repo root:  Rscript index/tests/test_uncertainty_acs.R
#  (a) aggregating the raw ESTIMATES reproduces the input builder's matrix N (one MPO, four types)
#  (b) with every MOE = 0, every draw equals I_obs exactly
#  (c) cells with est 0 are 0 in every draw
#  (d) same seed -> identical output
#  (e) a tiny synthetic unit gives an interval that contains I_obs
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity")
setwd(file.path(root, "index"))
source("uncertainty_acs.R")
n_fail = 0
check = function(name, ok){
  ok = isTRUE(all(ok)); cat(if(ok) "PASS" else "FAIL", " ", name, "\n", sep = "")
  if(!ok) n_fail <<- n_fail + 1
}
TYPES = c("race", "income", "edu", "age")
id = "36197300"

for(t in TYPES){
  x = unit_inputs_mpo(id, t); cl = acs_cells_for(x, t)
  Nhat = cl$E %*% cl$G
  check(sprintf("(a) %s: sum of estimates == N (%d tracts, max |diff| %g)", t, nrow(Nhat), max(abs(Nhat - x$N))),
        identical(dim(Nhat), dim(x$N)) && identical(colnames(Nhat), colnames(x$N)) && max(abs(Nhat - x$N)) == 0)
}

x = unit_inputs_mpo(id, "income"); cl = acs_cells_for(x, "income")
I_obs = do.call(index_from_tracts, x)[["I"]]
r0 = acs_interval(x, "income", B = 20, seed = 7, cells = modifyList(cl, list(SE = cl$SE * 0)), return_draws = TRUE)
check("(b) all MOE = 0: every draw == I_obs exactly", all(r0$I_b == I_obs))
check("(b) all MOE = 0: width 0", r0$summary[["width"]] == 0)

set.seed(3); pos = cl$E > 0
d = replicate(25, acs_draw(cl$E, cl$SE, pos), simplify = FALSE)
check(sprintf("(c) est 0 cells (%d) are 0 in all 25 draws", sum(!pos)), all(map_lgl(d, ~all(.x[!pos] == 0))))
check("(c) draws are never negative", all(map_lgl(d, ~all(.x >= 0))))
check("(c) positive cells do move", any(d[[1]][pos] != cl$E[pos]))

a1 = acs_interval(x, "income", B = 30, seed = 11); a2 = acs_interval(x, "income", B = 30, seed = 11)
a3 = acs_interval(x, "income", B = 30, seed = 12)
check("(d) same seed -> identical output", identical(a1, a2))
check("(d) different seed -> different output", !identical(a1, a3))
check("(d) acs_seed is deterministic", acs_seed("36197300", "race") == acs_seed("36197300", "race"))

# (e) synthetic: 6 tracts, 2 counties, 4 age cells x ... use the age map with 48 cells filled in
set.seed(5)
geoid = sprintf("99001%06d", 1:6)
G = acs_map("age"); E = matrix(rpois(6 * nrow(G), 40), 6, nrow(G), dimnames = list(geoid, rownames(G)))
SE = E * 0.3
N = E %*% G
syn = list(N = N, a = c(.2, .7, .5, .4, .6, .3), county = rep(c("99001", "99002"), each = 3),
           unit = c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE), emissions_county = c("99001" = 10, "99002" = 4))
rs = acs_interval(syn, "age", B = 300, seed = 1, cells = list(E = E, SE = SE, G = G))
check(sprintf("(e) synthetic interval [%.4f, %.4f] contains I_obs %.4f and has width > 0", rs[["lo95"]], rs[["hi95"]], rs[["I_obs"]]),
      rs[["lo95"]] <= rs[["I_obs"]] && rs[["I_obs"]] <= rs[["hi95"]] && rs[["width"]] > 0)

cat(sprintf("\n%d failure(s)\n", n_fail))
quit(status = if(n_fail > 0) 1 else 0)
