# make_results.R
# Compute every number the paper prints, under the published method and under the
# corrected index with new emissions (six variants), and write
#   paper_equity/.contract/r0/results.json
# plus the tidy numbers used by RERUN_DIFF.md (index/runs/summary_numbers.rds).
# Run headless from index/:   Rscript make_results.R
# Does not touch index/published/ or index/test/ (read-only inputs).

suppressMessages({
  library(dplyr); library(sf); library(purrr); library(readr); library(stringr)
  library(tidyr); library(ggplot2); library(viridis); library(jsonlite)
})
stopifnot(file.exists("functions.R"), dir.exists("published"), dir.exists("test"))
source("functions.R")

CONTRACT = "/home/user/paper_equity/.contract/r0"
MS_TEX   = "/home/user/paper_equity/manuscript_v2.tex"
DIST = 300; POLL = 110
TYPES = c("income", "race", "edu", "age")
VARIANTS = c("published", "fix_only", "rerun", "rerun_endpoints", "exact_2020", "exact_2025", "exact_2022_38")
regions_all = read_rds("data/regions_ny_data.rds")

# ---- 1. Runs --------------------------------------------------------------
dir.create("runs", showWarnings = FALSE)
cfg = list(
  rerun         = list(dir = "variant_A",  year = 2022, em = "test/emissions_all_pollutants.rds",       regions = regions_all),
  fix_only      = list(dir = "fix_only",   year = 2022, em = "published/emissions_all_pollutants.rds", regions = regions_all),
  rerun_endpoints = list(dir = "variant_A_endpoints", year = 2022, em = "test/emissions_2020_2025_endpoints.rds", regions = regions_all),
  exact_2020    = list(dir = "variant_B",  year = 2020, em = "test/emissions_2020_2025_endpoints.rds", regions = regions_all),
  exact_2025    = list(dir = "variant_C",  year = 2025, em = "test/emissions_2020_2025_endpoints.rds", regions = regions_all),
  exact_2022_38 = list(dir = "variant_D",  year = 2022, em = "test/emissions_2022_exact.rds",
                       regions = regions_all %>% filter(geoid %in% (read_rds("test/emissions_2022_exact.rds") %>%
                                                                      filter(pollutant == POLL) %>% pull(geoid))))
)
runs = list()
for(v in names(cfg)){
  k = cfg[[v]]; od = file.path("runs", k$dir); dir.create(od, showWarnings = FALSE, recursive = TRUE)
  message("== run ", v, " (year ", k$year, ", emissions ", k$em, ")")
  overall = get_overall(myyear = k$year, pollutant = POLL, dist = DIST, path_emissions = k$em,
                        outdir = od, myregions = k$regions)
  overall = overall %>% filter(!is.na(region))   # counties outside myregions (variant D) drop out
  saveRDS(overall, file.path(od, "stat_overall.rds"))
  lst = map(set_names(TYPES), ~read_rds(file.path(od, sprintf("stat_%s_%d_%d_%d.rds", .x, k$year, DIST, POLL))))
  runs[[v]] = list(overall = overall, lst = lst, cfg = k,
                   n_counties = k$regions %>% count(region, name = "n_counties"))
}
# published = the paper's own saved objects
pub_overall = read_rds("published/stat_overall.rds")
pub_lst = map(set_names(TYPES), ~read_rds(sprintf("published/stat_%s.rds", .x)))
runs$published = list(overall = pub_overall, lst = pub_lst, cfg = list(year = 2022, em = "published/emissions_all_pollutants.rds"),
                      n_counties = regions_all %>% count(region, name = "n_counties"))

# Check: legacy formula on published region_group_values reproduces stored published values
chk_legacy = map_dbl(TYPES, function(t){
  ind = get_indicator(pub_lst[[t]]$region_group_values, type = t)
  max(abs(ind$indicator_legacy[match(pub_lst[[t]]$indicators$region, ind$region)] - pub_lst[[t]]$indicators$indicator2))
}) %>% set_names(TYPES)
# Check: published table 2 reproduces stat_overall (printed table parsed from the manuscript)
tex = readLines(MS_TEX)[443:475]
rows = tex[str_detect(tex, "^\\s*\\d+\\s*&")]
printed_t2 = map_dfr(rows, function(l){
  p = str_trim(str_split(str_remove(l, "\\\\\\\\.*$"), "&")[[1]])
  tibble(region = p[2], total = as.numeric(p[3]), income = as.numeric(p[4]), race = as.numeric(p[5]),
         edu = as.numeric(p[6]), age = as.numeric(p[7]))
})
stopifnot(nrow(printed_t2) == 10)
chk_t2 = pub_overall %>% select(region, total, income, race, edu, age) %>%
  left_join(printed_t2, by = "region", suffix = c("", "_printed")) %>%
  summarize(max_abs_diff_vs_printed_rounded = max(abs(c(total - total_printed, income - income_printed, race - race_printed,
                                                         edu - edu_printed, age - age_printed))))
# fix_only edu/age vs published edu/age
chk_fix = full_join(pub_overall %>% select(region, edu, age), runs$fix_only$overall %>% select(region, edu, age),
                    by = "region", suffix = c("_pub", "_fix")) %>%
  summarize(max_abs_diff = max(abs(c(edu_pub - edu_fix, age_pub - age_fix))))

# ---- 2. Numbers per variant ------------------------------------------------
# Table 2 per variant: published = legacy values (as stored); others = corrected equal-group
t2_tbl = function(v){
  o = runs[[v]]$overall
  if(v == "published"){
    o = o %>% mutate(race_pw = NA_real_, income_pw = NA_real_, edu_pw = NA_real_, age_pw = NA_real_, total_pw = NA_real_)
  }
  o %>% select(region, overall = total, income, race, edu, age, race_pw, income_pw, edu_pw, age_pw, total_pw) %>%
    left_join(runs[[v]]$n_counties, by = "region")
}
T2 = map(set_names(VARIANTS), t2_tbl)

summ = function(x){ x = x[!is.na(x)]; list(mean = mean(x), se = sd(x)/sqrt(length(x)), sd = sd(x), min = min(x), max = max(x), n = length(x)) }
SUMM = map(T2, function(d) map(set_names(c("overall","income","race","edu","age")), ~summ(d[[.x]])))

# regional emissions (as get_all's `joined`: interpolated to the year, summed within region) for each variant
reg_em = function(v){
  runs[[v]]$lst$income$joined %>% filter(!is.na(region)) %>% select(region, emissions)
}
CORR = map(set_names(VARIANTS), function(v){
  d = runs[[v]]$overall
  e = reg_em(v)
  d = d %>% left_join(e, by = "region")
  cf = function(a, b){ ok = complete.cases(a, b); list(r = cor(a[ok], b[ok]), n = sum(ok)) }
  list(r_race_income = cf(d$race, d$income), r_total_race = cf(d$total, d$race),
       r_total_income = cf(d$total, d$income), r_income_edu = cf(d$income, d$edu),
       r_emissions_race = cf(d$emissions, d$race))
})
# get_corr-form (lm emissions~year across the CSV years, predicted at the year) for the two year-2022 runs with 2020/2025 data
CORR_getcorr = list(
  rerun    = get_corr(data_regions = regions_all, data_emissions = read_csv("test/emissions_all_pollutants.csv", show_col_types = FALSE),
                      data_equity = runs$rerun$overall, myyear = 2022, .pollutant = POLL) %>% summarize(r = cor(emissions, race)) %>% pull(r),
  rerun_endpoints = get_corr(data_regions = regions_all, data_emissions = read_rds("test/emissions_2020_2025_endpoints.rds"),
                      data_equity = runs$rerun_endpoints$overall, myyear = 2022, .pollutant = POLL) %>% summarize(r = cor(emissions, race)) %>% pull(r),
  fix_only = get_corr(data_regions = regions_all, data_emissions = read_csv("published/emissions_all_pollutants.csv", show_col_types = FALSE),
                      data_equity = runs$fix_only$overall, myyear = 2022, .pollutant = POLL) %>% summarize(r = cor(emissions, race)) %>% pull(r),
  published = get_corr(data_regions = regions_all, data_emissions = read_csv("published/emissions_all_pollutants.csv", show_col_types = FALSE),
                       data_equity = pub_overall, myyear = 2022, .pollutant = POLL) %>% summarize(r = cor(emissions, race)) %>% pull(r)
)

# Emissions slopes: lm(index ~ log(emissions)) across regions, emissions = joined$emissions from the income run
# (exactly what get_emissions_slopes uses: xtype "Emissions", x = regional summed emissions in tons)
SLOPES = map(set_names(VARIANTS), function(v){
  d = runs[[v]]$overall %>% left_join(reg_em(v), by = "region")
  map(set_names(c("total", "income", "race")), function(y){
    m = lm(d[[y]] ~ log(d$emissions)) %>% broom::tidy() %>% filter(term == "log(d$emissions)")
    list(beta = m$estimate, se = m$std.error, p = m$p.value, n = sum(complete.cases(d[[y]], d$emissions)))
  })
})

# ANOVA: aov(epshare ~ group + region) per type (the model at get_bars2). Row 1 = group, row 2 = region.
ANOVA = map(set_names(VARIANTS), function(v){
  map(set_names(TYPES), function(t){
    m = aov(epshare ~ group + region, data = (runs[[v]]$lst[[t]]$region_group_values %>% filter(!is.na(region)))) %>% broom::tidy()
    ex = function(term){ r = m[m$term == term, ]; list(F = r$statistic, df1 = r$df, df2 = m$df[m$term == "Residuals"], p = r$p.value) }
    list(group = ex("group"), region = ex("region"))
  })
})

# Per-region slopes: lm(epshare ~ as.numeric(group)) as in get_bars2
RSLOPES = map(set_names(VARIANTS), function(v){
  map(set_names(TYPES), function(t){
    (runs[[v]]$lst[[t]]$region_group_values %>% filter(!is.na(region))) %>% group_by(region) %>%
      reframe(lm(epshare ~ as.numeric(group)) %>% broom::tidy()) %>%
      filter(term == "as.numeric(group)") %>% select(region, beta = estimate, p = p.value)
  })
})

# Sensitivity: lm(total ~ log(dist/1000)) for pollutant 110, year 2022 (get_sensitivity_distance2)
sens_fit = function(path){
  d = read_rds(path) %>% filter(pollutant == POLL, year == 2022)
  m = lm(total ~ log(dist/1000), data = d)
  list(intercept = unname(coef(m)[1]), slope_log_km = unname(coef(m)[2]), sigma = sigma(m), n = nrow(d), r2 = summary(m)$r.squared)
}
SENS_PUB = sens_fit("published/stat_overall_sensitivity.rds")
sens_mtime = file.info("test/stat_overall_sensitivity.rds")$mtime
# Rerun fit only if the sensitivity grid has been regenerated (content differs from the as-published snapshot).
sens_regenerated = file.exists("test/stat_overall_sensitivity.rds") && unname(tools::md5sum("test/stat_overall_sensitivity.rds")) != unname(tools::md5sum("published/stat_overall_sensitivity.rds"))
SENS_RERUN = if(sens_regenerated) sens_fit("test/stat_overall_sensitivity.rds") else NULL

# Descriptives (tab_descriptives2.tex): mean and sd of county shares, in percent.
cc = read_rds("test/census_counties.rds")
share_of = function(vars, denom) cc[vars] %>% mutate(across(everything(), ~ .x / denom))
inc = names(cc)[str_detect(names(cc), "^income_")]; edu = names(cc)[str_detect(names(cc), "^edu_")]
age = names(cc)[str_detect(names(cc), "^age_")]
race = names(cc)[str_detect(names(cc), "Population$") & !str_detect(names(cc), "^(Not_)?Hispanic|^total")]
DESC = bind_rows(
  tibble(group = "Population", variable = "total_population", share = cc$total_population / sum(cc$total_population)),
  map_dfr(inc,  ~tibble(group = "Income", variable = .x, share = cc[[.x]] / rowSums(cc[inc]))),
  map_dfr(race, ~tibble(group = "Race/Ethnicity", variable = .x, share = cc[[.x]] / cc$total_population)),
  map_dfr(edu,  ~tibble(group = "Education", variable = .x, share = cc[[.x]] / rowSums(cc[edu]))),
  map_dfr(age,  ~tibble(group = "Age", variable = .x, share = cc[[.x]] / rowSums(cc[age])))
) %>% group_by(group, variable) %>% summarize(mean_pct = 100*mean(share), sd_pct = 100*sd(share), .groups = "drop")
# Printed values, in table order, to mark matches
printed_desc = tibble(variable = c("total_population", inc, race[c(1,2,3,4,5,6,7,8,9,10)][0], edu, age),
                      mean_pct = NA_real_, sd_pct = NA_real_)
dl = readLines("/home/user/paper_equity/blocks/tab_descriptives2.tex")
dl = dl[str_detect(dl, "\\\\% & .*\\\\% \\\\\\\\")]
pr = map_dfr(dl, function(l){
  p = str_trim(str_split(str_remove(l, "\\\\\\\\.*$"), "&")[[1]])
  tibble(group = p[1], label = p[2], mean_pct = as.numeric(str_remove(p[4], "\\\\%")), sd_pct = as.numeric(str_remove(p[5], "\\\\%")))
})
# Map printed rows to DESC rows by table order (same order as the constructed DESC for Income, Edu, Age; Race by label)
race_label = c(White_alone_Not_Hispanic_or_Latino_Population = "White", Black_or_African_American_Not_Hispanic_or_Latino_Population = "Black",
               American_Indian_and_Alaska_Not_Native_Hispanic_or_Latino_Population = "Nat. Am.", Asian_Not_Hispanic_or_Latino_Population = "Asian",
               Native_Hawaiian_and_Other_Pacific_Islander_Not_Latino_Population = "Pacific", White_alone_Hispanic_or_Latino_Population = "White Latinx",
               Black_or_African_American_Hispanic_or_Latino_Population = "Black Latinx", American_Indian_and_Alaska_Native_Hispanic_or_Latino_Population = "Nat. Am. Latinx",
               Asian_Hispanic_or_Latino_Population = "Asian Latinx", Native_Hawaiian_and_Other_Pacific_Islander_Latino_Population = "Pacific Latinx")
DESC = DESC %>% mutate(label = ifelse(group == "Race/Ethnicity", race_label[variable], NA_character_))
DESC_nonrace = DESC %>% filter(group != "Race/Ethnicity")
pr_nonrace = pr %>% filter(group != "Race/Ethnicity")
DESC$printed_mean = NA_real_; DESC$printed_sd = NA_real_
if(nrow(pr_nonrace) == nrow(DESC_nonrace)){
  # DESC is sorted alphabetically by group/variable in summarize; rebuild table order
  ord = c("total_population", inc, edu, age)
  DN = DESC_nonrace[match(ord, DESC_nonrace$variable), ]
  # printed order in the table: Population, Income x8, Education x4, Age x4 (race rows are separate)
  P = pr_nonrace %>% mutate(grp_order = match(group, c("Population", "Income", "Education", "Age")))
  P = P[order(P$grp_order), ]
  DN$printed_mean = P$mean_pct; DN$printed_sd = P$sd_pct
  DESC$printed_mean[match(DN$variable, DESC$variable)] = DN$printed_mean
  DESC$printed_sd[match(DN$variable, DESC$variable)] = DN$printed_sd
}
pr_race = pr %>% filter(group == "Race/Ethnicity")
DESC$printed_mean[!is.na(DESC$label)] = pr_race$mean_pct[match(DESC$label[!is.na(DESC$label)], pr_race$label)]
DESC$printed_sd[!is.na(DESC$label)]   = pr_race$sd_pct[match(DESC$label[!is.na(DESC$label)], pr_race$label)]
DESC = DESC %>% mutate(match_printed = abs(mean_pct - printed_mean) <= 0.0501 & abs(sd_pct - printed_sd) <= 0.0501)

# ---- 3. Save tidy numbers for RERUN_DIFF ------------------------------------
saveRDS(list(T2 = T2, SUMM = SUMM, CORR = CORR, CORR_getcorr = CORR_getcorr, SLOPES = SLOPES, ANOVA = ANOVA, RSLOPES = RSLOPES,
             SENS_PUB = SENS_PUB, SENS_RERUN = SENS_RERUN, DESC = DESC, chk_legacy = chk_legacy, chk_t2 = chk_t2, chk_fix = chk_fix,
             printed_t2 = printed_t2),
        "runs/summary_numbers.rds")

# ---- 4. results.json ---------------------------------------------------------
prov = readLines("test/emissions_provenance.txt")
em_all = read_rds("test/emissions_all_pollutants.rds") %>% filter(pollutant == POLL)
n_years_tab = em_all %>% count(geoid) %>% count(n, name = "counties") %>% { setNames(.$counties, paste0(.$n, "_years")) }
n_exact22 = em_all %>% filter(year == 2022) %>% pull(geoid) %>% n_distinct()
urls = str_trim(prov[str_detect(prov, "^\\s+https://")])
manifest = str_trim(str_remove(prov[str_detect(prov, "^manifest:")], "manifest:"))
dl_time = str_trim(str_remove(prov[str_detect(prov, "^downloaded")], "downloaded \\(UTC\\):"))
sha = system2("git", c("-C", "/home/user/equity", "rev-parse", "HEAD"), stdout = TRUE)

EV = c(published = "index/published/stat_*.rds (as-published snapshot); legacy index, old emissions",
       fix_only = "index/runs/fix_only (corrected index, published emissions; make_results.R)",
       rerun = "index/runs/variant_A (corrected index, 2022 interpolated per county, piecewise linear over all available years 2020-2025; make_results.R)",
       rerun_endpoints = "index/runs/variant_A_endpoints (corrected index, 2022 from straight line between 2020 and 2025 only; make_results.R)",
       exact_2020 = "index/runs/variant_B (exact 2020 emissions; make_results.R)",
       exact_2025 = "index/runs/variant_C (exact 2025 emissions; make_results.R)",
       exact_2022_38 = "index/runs/variant_D (exact 2022 emissions, 38 of 62 counties; make_results.R)")
leaf = function(value, v, status = NULL, note = NULL){
  if(is.null(status)) status = if(v == "published") "reported_in_manuscript" else "recomputed"
  out = list(value = value, status = status, evidence = EV[[v]])
  if(!is.null(note)) out$note = note
  out
}
# published leaves: compare to printed Table 2 where one exists
pub_leaf_t2 = function(region, idx, val){
  col = c(overall = "total", income = "income", race = "race", edu = "edu", age = "age")[[idx]]
  pr_val = printed_t2[[col]][printed_t2$region == region]
  if(isTRUE(round(val, 3) == pr_val)) leaf(val, "published") else
    leaf(val, "published", status = "not_reproduced", note = sprintf("printed Table 2 value is %s", pr_val))
}
J = list()
J[["_meta"]] = list(
  schema = "results/v1", paper = "paper_equity", updated = "2026-11-20",
  purpose = "Single source of truth for every quantitative claim in the equity-index paper; produced by equity/index/make_results.R (run headless from index/).",
  generator = "equity/index/make_results.R",
  equity_git_sha = sha,
  emissions = list(
    interpolation = "per county and pollutant, piecewise linear (stats::approx) between the nearest available years 2020-2025; exact where 2022 exists",
    counties_by_n_years_available_pm25 = as.list(n_years_tab),
    counties_using_exact_2022_pm25 = n_exact22,
    manifest = manifest, downloaded_utc = dl_time, urls = as.list(urls), provenance_file = "equity/index/test/emissions_provenance.txt"),
  census = "ACS 2022 5-year, cached in test/census_*.rds; not refetched",
  pollutant = POLL, dist_m = DIST,
  variants = list(published = "as printed: legacy normaliser (n-2)/3, absent groups scored 0, old emissions",
                  fix_only = "corrected index n/(2(n-1)), absent groups not scored, published emissions",
                  rerun = "variant A (HEADLINE): corrected index, 2022 interpolated per county, piecewise linear (approx) between the nearest available CAT years 2020-2025 (62 counties); exact where 2022 exists",
                  rerun_endpoints = "variant A-endpoints: corrected index, 2022 from the straight line between 2020 and 2025 only (the earlier method)",
                  exact_2020 = "variant B: corrected index, exact 2020 emissions (62)",
                  exact_2025 = "variant C: corrected index, exact 2025 emissions (62)",
                  exact_2022_38 = "variant D: corrected index, exact 2022 emissions, 38 of 62 counties (check only)"),
  status_vocab = list(
    reported_in_manuscript = "value currently printed in the submitted manuscript; recomputed here and equal after rounding",
    confirmed_by_tim = "Tim has confirmed this value is correct",
    recomputed = "recomputed from the underlying data this revision (evidence pointer says how)",
    `TODO-tim` = "value needed from Tim before it can be stated in the manuscript",
    `TODO-recompute` = "must be recomputed from the underlying data this revision",
    not_reproduced = "the published method and data do not reproduce the printed value; printed value in note"),
  checks = list(
    legacy_formula_on_published_region_group_values_max_abs_diff = as.list(chk_legacy),
    published_stat_overall_vs_printed_table2_max_abs_diff = chk_t2$max_abs_diff_vs_printed_rounded,
    published_vs_fix_only_edu_age_max_abs_diff = chk_fix$max_abs_diff)
)

J$table2 = map(set_names(VARIANTS), function(v){
  d = T2[[v]]
  map(set_names(d$region), function(rg){
    r = d[d$region == rg, ]
    out = list()
    for(idx in c("overall", "income", "race", "edu", "age")){
      out[[idx]] = if(v == "published") pub_leaf_t2(rg, idx, r[[idx]]) else leaf(r[[idx]], v)
    }
    for(idx in c("race", "income", "edu", "age")){
      nm = paste0(idx, "_pw")
      out[[nm]] = if(v == "published") list(value = NULL, status = "TODO-recompute", evidence = "population-weighted column did not exist in the published run") else leaf(r[[nm]], v)
    }
    out$total_pw = if(v == "published") list(value = NULL, status = "TODO-recompute", evidence = "population-weighted column did not exist in the published run") else leaf(r$total_pw, v)
    out$n_counties = leaf(r$n_counties, v)
    out
  })
})
J$summary = map(set_names(VARIANTS), function(v) map(SUMM[[v]], function(s){
  map(s, function(x) leaf(x, v, status = if(v == "published") "reported_in_manuscript" else "recomputed"))
}))
J$correlations = map(set_names(VARIANTS), function(v) {
  out = map(CORR[[v]], function(x) c(leaf(x$r, v), list(n = x$n)))
  if(v %in% names(CORR_getcorr)) out$r_emissions_race_getcorr_form = leaf(CORR_getcorr[[v]], v,
        note = "get_corr form: each county interpolated to 2022 (approx over the years in the emissions file), then summed to region")
  out
})
J$emissions_slopes = map(set_names(VARIANTS), function(v) map(SLOPES[[v]], function(x)
  list(beta = leaf(x$beta, v), se = leaf(x$se, v), p = leaf(x$p, v), n = x$n)))
J$anova = map(set_names(VARIANTS), function(v) map(ANOVA[[v]], function(t) map(t, function(term)
  map(term, function(x) leaf(x, v)))))
J$region_slopes = map(set_names(VARIANTS), function(v) map(RSLOPES[[v]], function(d)
  map(set_names(d$region), function(rg) list(beta = leaf(d$beta[d$region == rg], v), p = leaf(d$p[d$region == rg], v)))))
J$sensitivity = list(
  published = map(SENS_PUB, function(x) leaf(x, "published", status = "recomputed")),
  rerun = if(!is.null(SENS_RERUN)) map(SENS_RERUN, function(x) leaf(x, "rerun")) else
    list(status = "TODO-recompute", note = "test/stat_overall_sensitivity.rds is identical to the published snapshot; run run_ny.R first.")
)
J$sensitivity$`_note` = "lm(total ~ log(dist/1000)) over regions x {100,300,500,1000,2000} m, pollutant 110, year 2022 (get_sensitivity_distance2). Paper prints equity = 0.03 x log(km) + 0.91, sigma 0.05."
J$descriptives = list(
  `_note` = "ACS 2022 5-year, cached; not refetched. Mean and SD across 62 counties of each county's share (percent): population = county / state total; income = bracket / sum of brackets; race = group / total_population; education and age = group / sum of its groups.",
  rows = pmap(DESC, function(group, variable, mean_pct, sd_pct, label, printed_mean, printed_sd, match_printed)
    list(group = group, variable = variable, label = label, mean_pct = mean_pct, sd_pct = sd_pct, printed_mean_pct = printed_mean,
         printed_sd_pct = printed_sd, status = if(isTRUE(match_printed)) "reported_in_manuscript" else "not_reproduced",
         evidence = "index/test/census_counties.rds via make_results.R")))

write(toJSON(J, pretty = TRUE, auto_unbox = TRUE, digits = NA, na = "null", null = "null"), file.path(CONTRACT, "results.json"))
cat("\nWrote", file.path(CONTRACT, "results.json"), "\n")
cat("legacy-formula check (max abs diff vs stored published):\n"); print(chk_legacy)
cat("published table2 vs printed (3dp) max abs diff:\n"); print(chk_t2)
cat("published vs fix_only edu/age max abs diff:\n"); print(chk_fix)
