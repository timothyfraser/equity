# V-4: index ~ log(emissions_rate_mpo) across MPOs; writes results_national.json
library(dplyr)
library(readr)
library(sandwich)
library(lmtest)
library(jsonlite)

d = read_csv("national/tables/mpo_wide.csv", col_types = cols(mpo_id = col_character(), .default = col_guess()))
ledger = read_csv("national/LEDGER.csv", col_types = cols(.default = col_character()))
stopifnot(all(d$emissions_rate_mpo > 0))

leaf = function(x, ev) list(value = unname(x), status = "computed", evidence = ev)
indices = c("race", "income", "edu", "age", "overall")

fit_one = function(ix) {
  m = lm(reformulate("log(emissions_rate_mpo)", ix), data = d)
  term = "log(emissions_rate_mpo)"
  ct = coeftest(m)
  ct3 = coeftest(m, vcov. = vcovHC(m, type = "HC3"))
  ctc = coeftest(m, vcov. = vcovCL(m, cluster = d$state))
  ev = function(s) sprintf("national/models.R: lm(%s ~ log(emissions_rate_mpo)), %s", ix, s)
  mn = d[which.min(d[[ix]]), ]; mx = d[which.max(d[[ix]]), ]
  ext = function(r) list(mpo_id = leaf(r$mpo_id, ev("extreme MPO id")),
                         mpo_name = leaf(r$mpo_name, ev("extreme MPO name")),
                         state = leaf(r$state, ev("extreme MPO state")),
                         value = leaf(r[[ix]], ev("extreme index value")))
  list(beta = leaf(ct[term, 1], ev("classical OLS coefficient")),
       se = leaf(ct[term, 2], ev("classical SE")),
       p = leaf(ct[term, 4], ev("classical p")),
       ci_low = leaf(confint(m, level = 0.95)[term, 1], ev("classical 95% CI, lower (confint)")),
       ci_high = leaf(confint(m, level = 0.95)[term, 2], ev("classical 95% CI, upper (confint)")),
       r2 = leaf(summary(m)$r.squared, ev("R-squared")),
       n = leaf(nobs(m), ev("MPOs in fit")),
       se_hc3 = leaf(ct3[term, 2], ev("HC3 SE, sandwich::vcovHC")),
       p_hc3 = leaf(ct3[term, 4], ev("HC3 p, sandwich::vcovHC")),
       se_cluster_state = leaf(ctc[term, 2], ev("state-clustered SE, sandwich::vcovCL")),
       p_cluster_state = leaf(ctc[term, 4], ev("state-clustered p, sandwich::vcovCL")),
       min = ext(mn), max = ext(mx))
}

fits = lapply(indices, fit_one) |> setNames(indices)
models = lapply(fits, \(f) f[c("beta","se","p","ci_low","ci_high","r2","n","se_hc3","p_hc3","se_cluster_state","p_cluster_state")])
extremes = lapply(fits, \(f) f[c("min", "max")])

cnt = \(s) sum(ledger$status == s)
cov_ev = "national/models.R: count of status in national/LEDGER.csv"
# done MPOs only: single_county MPOs are never rerun, so they keep the manifest of their first run
manifest = unique(ledger$manifest[ledger$status == "done" & !is.na(ledger$manifest) & ledger$manifest != "NA"])
stopifnot(length(manifest) == 1)

res = list(
  `_meta` = list(schema = "results/v1", generator = "equity/national/models.R",
                 purpose = "National MPO scatter models: index ~ log(emissions per resident); extremes; ledger coverage."),
  generated_utc = leaf(format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "national/models.R: Sys.time()"),
  n_mpos = leaf(nrow(d), "national/models.R: rows of national/tables/mpo_wide.csv"),
  cat_manifest = leaf(manifest, "national/models.R: manifest field of national/LEDGER.csv, done MPOs"),
  coverage = list(done = leaf(cnt("done"), cov_ev), single_county = leaf(cnt("single_county"), cov_ev),
                  blocked_cat = leaf(cnt("blocked_cat"), cov_ev), pending = leaf(cnt("pending"), cov_ev)),
  models = models,
  extremes = extremes
)
write_json(res, "national/results_national.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)
for (ix in indices) with(models[[ix]], cat(sprintf("%-8s beta=%.5f se=%.5f p=%.3g | hc3 %.5f %.3g | cl %.5f %.3g | r2=%.3f n=%d\n",
  ix, beta$value, se$value, p$value, se_hc3$value, p_hc3$value, se_cluster_state$value, p_cluster_state$value, r2$value, n$value)))
