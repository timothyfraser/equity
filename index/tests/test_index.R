# tests/test_index.R -- T-003: corrected equity index normaliser, absent groups, companion scores.
# Run from the index directory:  Rscript tests/test_index.R
# Base R + dplyr only. Prints PASS/FAIL per check; exits 1 on any failure.
suppressPackageStartupMessages(library(dplyr))
# functions.R ends one definition with a stray top-level call, `get_corr(.pollutant = 110) %>% summarize(...)`,
# which reads data files at source time (outside this unit's write boundary). Evaluate only the
# assignments (function definitions) so the tests do not depend on those files.
for(e in parse(file = "functions.R")){
  if(is.call(e) && as.character(e[[1]]) %in% c("=", "<-")) eval(e, envir = globalenv())
}

n_fail = 0
check = function(name, ok){
  ok = isTRUE(all(ok))
  cat(if(ok) "PASS" else "FAIL", " ", name, "\n", sep = "")
  if(!ok) n_fail <<- n_fail + 1
}
tol = 1e-12

# 1. Bounds at the extremes: equal shares -> 1, one group holds everything -> 0
for(n in c(2, 3, 4, 5, 8, 10)){
  check(sprintf("n=%d equal shares -> 1", n), abs(get_index(rep(1/n, n)) - 1) < tol)
  check(sprintf("n=%d corner -> 0", n), abs(get_index(c(1, rep(0, n - 1))) - 0) < tol)
}

# 2. 10,000 Dirichlet(1,...,1) draws (normalised rexp) stay in [0, 1]
set.seed(20261119)
for(n in c(4, 8, 10)){
  vals = vapply(1:10000, function(i){ x = rexp(n); get_index(x / sum(x)) }, numeric(1))
  check(sprintf("n=%d 10,000 Dirichlet draws in [0,1] (min %.4f, max %.4f)", n, min(vals), max(vals)),
        all(vals >= -tol & vals <= 1 + tol))
}

# 3. At n = 4 the new normaliser equals the old one (both 2/3, Moro et al. 2021)
eq4 = vapply(1:1000, function(i){ x = rexp(4); x = x / sum(x); abs(get_index(x) - get_index_legacy(x)) }, numeric(1))
check("n=4 get_index == get_index_legacy (1,000 draws + corners)",
      all(eq4 < tol) && abs(get_index(c(1,0,0,0)) - get_index_legacy(c(1,0,0,0))) < tol)

# 4. NA (absent group) is dropped
x = rexp(6); x = x / sum(x)
check("get_index(c(x, NA)) == get_index(x)", abs(get_index(c(x, NA)) - get_index(x)) < tol)
check("fewer than 2 groups -> NA_real_", is.na(get_index(c(1, NA))) && is.na(get_index(numeric(0))))

# 5. Regression on the saved (published) results
types = c("age", "income", "edu", "race")
pub = lapply(setNames(types, types), function(t) readRDS(file.path("published", paste0("stat_", t, ".rds"))))
overall = readRDS("published/stat_overall.rds")
ind = lapply(setNames(types, types), function(t) get_indicator(pub[[t]]$region_group_values, type = t))

for(t in types){
  cmp = ind[[t]] %>% select(region, indicator_legacy) %>%
    inner_join(overall %>% select(region, pub = all_of(t)), by = "region")
  check(sprintf("%s: indicator_legacy reproduces published stat_overall (%d regions, max |d| %.2e)",
                t, nrow(cmp), max(abs(cmp$indicator_legacy - cmp$pub))),
        nrow(cmp) == nrow(overall) && all(abs(cmp$indicator_legacy - cmp$pub) < 1e-6))
}
for(t in c("edu", "age")){
  check(sprintf("%s: corrected == legacy (n = 4) to 1e-9", t),
        all(abs(ind[[t]]$indicator2 - ind[[t]]$indicator_legacy) < 1e-9))
}
race = ind$race %>% filter(region == "Mohawk Valley")
check(sprintf("race Mohawk Valley corrected rounds to 0.821 (got %.4f)", race$indicator2),
      round(race$indicator2, 3) == 0.821)

# Published inputs still score the absent North Country group as 0: corrected value 0.865 with it.
nc_kept = ind$race %>% filter(region == "North Country") %>% pull(indicator2)
check(sprintf("race North Country corrected, absent group kept as 0 -> 0.865 (got %.4f)", nc_kept),
      round(nc_kept, 3) == 0.865)
# Apply the new get_region_group_values rule (pshare == 0 -> NA). The absent group had epshare 0,
# so the renormalising sum is unchanged and setting NA is the whole change.
race_fixed = pub$race$region_group_values %>%
  mutate(epshare = if_else(pshare == 0, NA_real_, epshare)) %>%
  group_by(region) %>% mutate(epshare = epshare / sum(epshare, na.rm = TRUE)) %>% ungroup()
ind_race_fixed = get_indicator(race_fixed, type = "race")
nc = ind_race_fixed %>% filter(region == "North Country") %>% pull(indicator2)
check(sprintf("race North Country corrected, absent group dropped -> 0.937 (got %.4f)", nc), round(nc, 3) == 0.937)
li = ind_race_fixed %>% filter(region == "Long Island") %>% pull(indicator2)
check(sprintf("race Long Island corrected -> 0.969 (got %.4f)", li), round(li, 3) == 0.969)
check("absent-group rule changes only North Country race",
      all(abs((ind_race_fixed$indicator2 - ind$race$indicator2)[ind$race$region != "North Country"]) < 1e-12))
check("indicator_legacy unchanged by absent-group rule (NA -> 0 restores published)",
      all(abs(ind_race_fixed$indicator_legacy - ind$race$indicator_legacy) < 1e-12))
for(t in types){
  pw = ind[[t]]$indicator_pw
  check(sprintf("%s: indicator_pw in [0,1]", t), all(pw >= 0 & pw <= 1))
}

# 5b. get_region_group_values: absent group (pop 0) -> NA; present group with 0 emissions -> 0
cgv = data.frame(region = "R", group = c("a", "b", "c"),
                 emissions_group = c(6, 0, 0), emissions = 6,
                 pop = c(50, 50, 0), pop_total = 100, affected = c(5, 0, 0), affected_total = 5)
rgv = get_region_group_values(cgv, myvars = c("a", "b", "c"))
check("get_region_group_values: pshare == 0 -> epshare NA", is.na(rgv$epshare[rgv$group == "c"]))
check("get_region_group_values: present group with eshare 0 keeps epshare 0", rgv$epshare[rgv$group == "b"] == 0)
check("get_region_group_values: epshare renormalised over present groups", abs(sum(rgv$epshare, na.rm = TRUE) - 1) < tol)
check("get_region_group_values: eshare/pshare/ashare unchanged",
      all(rgv$eshare == c(1, 0, 0), rgv$pshare == c(0.5, 0.5, 0), rgv$ashare == c(1, 0, 0)))

# 6. get_overall wiring: mock get_all with the saved region_group_values, write to a temp outdir
get_all = function(myregions, myyear, .pollutant, path_emissions, path_area_roads, index, myvars){
  list(region_group_values = pub[[index]]$region_group_values,
       indicators = get_indicator(pub[[index]]$region_group_values, type = index))
}
tmp = tempfile("t003_"); dir.create(tmp)
ov = get_overall(myyear = 2022, pollutant = 110, dist = 300, path_emissions = "unused.rds",
                 outdir = tmp, myregions = data.frame(region = character(0), geoid = character(0)))
want = c("year", "pollutant", "dist", "region", "age", "income", "edu", "race", "total",
         paste0(c(types, "total"), "_legacy"), paste0(c(types, "total"), "_pw"))
check("get_overall keeps existing columns and adds <type>_legacy / <type>_pw", setequal(names(ov), want))
check("get_overall existing column order unchanged", identical(names(ov)[1:9], names(overall)))
j = ov %>% inner_join(overall, by = "region", suffix = c("", ".pub"))
check("get_overall *_legacy (incl. total_legacy) reproduce published stat_overall to 1e-6",
      all(abs(j$age_legacy - j$age.pub) < 1e-6, abs(j$income_legacy - j$income.pub) < 1e-6,
          abs(j$edu_legacy - j$edu.pub) < 1e-6, abs(j$race_legacy - j$race.pub) < 1e-6,
          abs(j$total_legacy - j$total.pub) < 1e-6))
check("get_overall total_pw = mean of the four *_pw",
      all(abs(ov$total_pw - rowMeans(ov[, paste0(types, "_pw")])) < 1e-12))
check("get_overall writes to outdir", length(list.files(tmp, pattern = "^stat_(age|income|edu|race)_2022_300_110\\.rds$")) == 4)
unlink(tmp, recursive = TRUE)

cat(sprintf("\n%d failure(s)\n", n_fail))
quit(status = if(n_fail > 0) 1 else 0)
