# Plan: "Scaling up" (national figure refinement, permutation test, ACS intervals, paper section)

Status: **proposed 2026-11-20; nothing implemented. Wait for Tim.**
Repos: `timothyfraser/equity` (branch `dev`) and `timothyfraser/paper_equity` (branch `claude/paper-equity-r0-resubmission`).
Builds on `PLAN_VIZ_AND_CAT.md` (Revision 2 and R2.2) and `CONTRACT.yaml` (ND12-ND23). Rules in PLAN_NATIONAL section 4 apply: disjoint `owns`, receipts in `.contract/national/receipts/<id>.md`, parse check after every R edit, no hand-typed number, orchestrator commits, 15-minute box per unit.

## 0. Rulings recorded (Tim, 2026-11-20)

- **ND24. Map layout.** State abbreviations back on every tile (each tile is still one MPO; the label is its primary state). The maps are the most important panels: give them about two thirds of the page height. Extremes labels go above or below the map, not to the sides, so the maps can widen.
- **ND25. Scale.** Scatter y-axes use the data's own extent (drop the fixed 0.70 floor). The maps keep the shared 0.70-1.00 colour scale they have now (Tim: "match the extent of the data, which you've done nicely in the map"). See Q1.
- **ND26. Ordinary standard errors, reported as 95% confidence intervals** (done 2026-11-20).
- **ND27. Run the permutation test** (exact random allocation of group labels) and report it as: "x of 224 MPOs are significantly more uneven in emissions burden by race than we would expect by chance."
- **ND28. Run the ACS sampling-error intervals** (parametric bootstrap on tract margins of error).
- **ND29. Write the national section now** ("Scaling up"), with the clarifications for the permutation test and the ACS intervals. All analysis reproducible, commented, human-facing, in Tim's style, and tested.

## 1. Current state, measured

| Item | Finding |
|---|---|
| National data | 224 multi-county MPOs `done` under `MANIFEST-59ea1fac.tsv`; only Puerto Rico blocked (`national/LEDGER.md`) |
| Figure | `national/fig/mpo_national.png`, 7.5 x 7 in. Maps take about 0.8 / 1.9 of the height; each map's width is squeezed by `coord_equal(xlim = range +/- 9.5 cols)` to make room for side labels (`national/figures.R`, `tile_map()`) |
| Tile grid | `national/tables/mpo_tiles.csv`: 224 tiles, about 26 cols x 15 rows (aspect about 1.7) |
| Map size arithmetic | Side by side, each map gets about 3.6 in of width, so about 2.1 in of height, whatever the page height. **Stacking the two maps at full width (7 in each) roughly doubles tile size** and is the only way to reach two thirds of the page |
| ACS margins of error | The API returns `_M` columns (tested: Rhode Island tracts, `B03002_003M`, `B03002_017M`, `B19001_002M`). **Cells with an estimate of 0 carry an MOE of 14 or 20, not 0.** Rhode Island has 243 tracts with zero Pacific Latinx residents, so a truncated-normal draw would add about 3.4 phantom residents per zero cell on average, biasing exactly the small groups. Zero cells must be handled explicitly (Q4) |
| Current census cache | `index/cache/national/census/<st>_<level>.rds` and `index/test/census_*.rds`: estimates only, no `_M` columns; aggregated groups (e.g. income bins) are sums of raw cells |
| Permutation null, exact | Shuffling group labels among residents with every tract's population and every group's size fixed is a random two-way table with fixed margins: `r2dtable()` (base R, Patefield 1981). NYMTC (3,330 tracts x 14 groups, 13.0 M people): 1,000 tables in about 11 s; margins verified exact. Full run about 224 MPOs x 4 dimensions: estimated 10-25 min |
| Why the exact version | Independent multinomial draws per group (the earlier R2.2 wording) let tract totals drift, which changes each county's exposed total and so its rate (Eq. 7). With fixed margins, tract totals and county rates stay exactly as observed |
| Manuscript | Results end at `\subsection{Income Equity for Emissions Exposure}` (l.551); Discussion starts l.575. Methods: `\subsubsection{Estimating Exposure per Region}` (l.389) is the last Methods block. Data availability l.632 |
| Paper results file | `paper_equity/.contract/r0/results.json` has no national block; `national/results_national.json` holds the national numbers |
| New York paper data | 23 of the 24 New York counties ordered for exact 2022 are still missing from CAT (`STATE.md`). New York numbers will move once they land; every task below is rerunnable |

## 2. Tasks

Tier: **O** Opus, **S** Sonnet. Every R script starts with a header block in Tim's style: purpose, inputs, outputs, how to run, and the rule that numbers come from files, not typing. tidyverse, native pipe, `=` assignment.

### U-0 Shared estimator core (O). No dependencies. First.

- **Owns:** `index/uncertainty_core.R`, `index/tests/test_uncertainty_core.R`.
- **Do:** one function that computes the equal-group index (and the population-weighted companion) from matrices, so the permutation test and the ACS bootstrap reuse the exact estimator:
  `index_from_tracts(N, a, county, unit, emissions_county)`, where `N` is a tracts x groups count matrix (all tracts of every member county), `a` the tract exposed share (`area_roads / area_total`, 0 when NA), `county` the tract's county geoid, `unit` a logical (tract inside the MPO or region), `emissions_county` a named vector of 2022 county emissions. Steps: county rate = emissions / sum over the county's tracts of rowSums(N) * a (Eq. 7, whole county); group emissions E_g = sum over unit tracts of N_tg * a_t * rate; e_g, p_g over unit tracts; s_g; `get_index()` from `index/functions.R` (never re-implement it). Returns `list(I, I_pw, n_groups)`.
  A helper `unit_matrices(...)` builds those inputs from the cached objects the national engine already writes (`index/cache/national/mpo_work/<id>/{tracts,area_roads300}.rds`, `cache/national/census/<st>_tract.rds`) and, for New York regions, from `index/test/{area_roads300,census_tracts}.rds` + `data/regions_ny_data.rds`.
- **Accept (tests):** for 3 national MPOs (36197300, 37198001, 21197300) and 2 New York regions, `index_from_tracts()` equals the committed `indicator2` and `indicator_pw` to 1e-10 for all four dimensions; a synthetic unit where every tract has the same group mix gives I = 1.

### U-1 Permutation test (S, after Opus review of U-0). Depends U-0.

- **Owns:** `index/uncertainty_permutation.R`, `national/permutation.R`, `national/tables/mpo_permutation.csv`, `national/results_permutation.json`, `index/tests/test_uncertainty_permutation.R`. (Its own JSON, not `results_national.json`, so `models.R` stays untouched; U-3 merges.)
- **Do:** `permute_index(N, a, county, unit, emissions_county, B = 1000, seed)`: within the unit's tracts, draw `r2dtable(B, rowSums(N[unit, ]), colSums(N[unit, ]))`; tracts outside the unit stay as observed (they only enter the county rates, which depend on tract totals and so do not change); recompute I for each table with `index_from_tracts()`. Return I_obs, E0 = mean, q025, q975, p0 = (1 + #{I_b <= I_obs}) / (B + 1), and the chance-adjusted I* = 1 - max(0, (U_obs - E0[U]) / (1 - E0[U])) with U = 1 - I. Seed per unit from its id (`strtoi` of the digits, or a hash) so runs are reproducible in any order or in parallel.
- `national/permutation.R` loops over the 224 `done` MPOs x four dimensions (3 parallel workers like `run_national.sh`), writes `mpo_permutation.csv` (`mpo_id, type, I_obs, E0, q025, q975, p0, p0_bh, I_star, n_groups, B, seed`) and `results_permutation.json`: per type, count with p0 < 0.05, count after Benjamini-Hochberg at 0.05 (Q3), Spearman rho of I_obs and of I_star with log population, and the extremes' p0.
- **Accept:** tests pass (below); runtime logged; for every MPO, Monte Carlo SE of E0 < 0.002; E0 rises with log population (Spearman > 0); the race p0 for Staunton-Augusta-Waynesboro is reported.
- **Tests:** perfectly mixed synthetic unit gives p0 = 1 and I* = 1; perfectly segregated synthetic unit (group A only in exposed tracts) gives p0 = 1 / (B + 1); every permuted table keeps both margins; same seed gives identical output.

### U-2 ACS sampling-error intervals (O design, S build). Depends U-0. Parallel with U-1.

- **Owns:** `index/uncertainty_acs.R`, `index/census_moe.R` (new pull; does not touch `retrieve_census2`), `national/acs_intervals.R`, `national/tables/mpo_acs_intervals.csv`, `national/results_acs.json`, `index/tests/test_uncertainty_acs.R`. MOE caches in `index/cache/national/census_moe/<st>.rds` (gitignored; ACS data can be re-pulled, same rule as ND21).
- **Pull:** raw cells with `E` and `M` for every cell the four dimensions are built from: B03002_003-009, 013-019; B19001_002-017; B01001_003-025, 027-049; B15003_002-025; tract level, 50 states + DC, ACS 2022 5-year (`censusapi::getCensus`, key from `CENSUS_API_KEY`). Check that estimates equal the existing caches after aggregation.
- **Draw:** for b = 1..B (B = 500): each cell X ~ Normal(est, (MOE / 1.645)^2), truncated at 0; **cells with est = 0 stay 0** (Q4); aggregate cells into each dimension's groups exactly as `retrieve_census2` does; recompute I with `index_from_tracts()` (county rates recomputed from the drawn tract totals, so the whole chain carries the error). Report the 2.5th and 97.5th percentiles as a 95% interval for I, per unit and dimension. Cells are drawn independently (the Census Bureau's own approximation for sums); say so.
- `national/acs_intervals.R` runs the 224 MPOs; outputs `mpo_acs_intervals.csv` (`mpo_id, type, I_obs, lo95, hi95, B, seed`) and `results_acs.json` (median interval width per type; share of MPOs whose interval excludes the national median; the extremes' intervals).
- **Accept:** tests pass; with all MOE set to 0 the draw reproduces I_obs exactly; zero cells never become positive; interval width shrinks with population (Spearman < 0); runtime logged.

### U-3 Results contract and New York (S). Depends U-1, U-2.

- **Owns:** `index/make_results.R` (new section only), `paper_equity/.contract/r0/results.json` (regenerated), `index/runs/uncertainty/` (New York outputs).
- **Do:** extend the paper's `results.json` contract first: `national` (merged from `national/results_national.json`, `results_permutation.json`, `results_acs.json`, each leaf `{value, status, evidence}`), `robustness.permutation.<region>.<type>` and `robustness.acs_interval.<region>.<type>` for the ten New York regions, computed through the same `index/uncertainty_*.R` functions on variant `rerun` inputs. Every existing key unchanged (check: `jq -S` of the old keys before and after is identical).
- **Accept:** `make_results.R` runs headless; new keys present; existing keys byte-identical; `make_diff.R` still runs.

### U-4 Figure refinement (S, `dataviz` skill). No dependencies; can start with U-0.

- **Owns:** `national/figures.R`, `national/fig/mpo_national.png`.
- **Layout (ND24):** page 7.5 x 9.5 in, 500 dpi (same as the paper's other figures). Row 1: race map, full width. Row 2: income map, full width. Row 3: the two scatters side by side. Heights about 3.3 : 3.3 : 2.9, so the maps fill about two thirds. Tiles touch; coord_equal with no side padding.
- **Tile labels (ND24):** each tile shows its MPO's primary state (`state` in `national/tables/mpo_wide.csv`), about 5 pt, text colour chosen by the tile's fill luminance (white on dark tiles, ink on light), so it is readable on every tile.
- **Extremes (ND24):** black outline on the tile; leader line to a label above the map if the tile is in the upper half of the grid, else below; label "<MPO name>, <state> (0.xxx)". The plot's y-range is extended by about 2 rows above and below for the labels; labels never cover tiles.
- **Scales (ND25):** maps keep the shared 0.70-1.00 scale; scatters drop `limits = c(lo, 1)` and use the data extent with a small expansion; the annotation stays at the bottom right inside the panel.
- **Keep:** titles and subtitle (ND17), legend titles, 95% CI annotation from `results_national.json` (ND26), point rings on the extremes.
- **Accept:** rendered and viewed at full size and at 2x crops of each map: every tile has a legible label; maps at least 60% of the figure height; extremes labels above/below with no overlap; scatter y-axes not forced to 0.70; every printed number traced to the JSON (listed in the receipt).

### U-5 Paper section "Scaling up" (O, edit proposals). Depends U-3, U-4.

- **Owns:** `paper_equity/.contract/r0/edits/T-014.md`, `paper_equity/fig/mpo_national.png` (copied from `equity/national/fig/`), the preview under `paper_equity/.contract/r0/preview/t014/`.
- **Results:** new `\subsection{Scaling Up: Metropolitan Planning Organizations Nationwide}` after the income subsection (before l.575), two or three paragraphs, Tim's voice (`tim-results` skill): coverage (224 of 411 MPOs; single-county and Puerto Rico excluded, and why); the figure (where the least even MPOs are; the extremes); the race and income slopes on emissions per resident with 95% CIs; the permutation result in Tim's words ("x of 224 MPOs are significantly more uneven in emissions burden by race than we would expect by chance"); one sentence on the ACS intervals. Figure environment with caption.
- **Methods (needs Tim's yes, Q2):** a short `\subsubsection{Scaling Up to Metropolitan Planning Organizations}` after l.389: MPO boundaries (BTS NTAD), tract assignment by interior point, whole-county rate for partial counties, the Connecticut county crosswalk, the permutation test and the ACS intervals, each in one or two sentences (`tim-methods` skill).
- **Data and code availability:** one added sentence on the CAT links and that CAT values may change slightly over time (ND21).
- Every number a `{{results:national....}}` placeholder. Apply with the existing preview pattern (`preview/apply_t012.py` as the template; new `preview/apply_t014.py`), compile, build the yellow diff against the current `manuscript_v2.tex`, show Tim. Nothing applied to the manuscript before his approval.
- **Accept:** preview compiles with 0 errors; no unresolved placeholders; yellow PDF built; word count of the additions reported.

### U-6 Documentation and tests wiring (S). Depends U-1, U-2.

- **Owns:** `README.md` (a "National extension" and "Uncertainty" section, word-level elsewhere), `index/tests/run_all.R` (runs every `test_*.R`), `national/README.md` (how to run: `run_national.sh`, `mpo_table.R`, `models.R`, `tile_grid.R`, `figures.R`, `permutation.R`, `acs_intervals.R`).
- **Accept:** `Rscript index/tests/run_all.R` prints 0 failures; a reader can rerun the national pipeline from the README alone.

## 3. Order

U-0 (O) and U-4 (S) start together → U-1 and U-2 (parallel, after Opus reviews U-0) → U-3 → U-5 (O) and U-6 (parallel) → Tim reviews the T-014 preview.

## 4. Risks

| Risk | Handling |
|---|---|
| Zero-estimate cells have MOE 14-20; truncated draws invent people in small groups | Hold est = 0 cells at 0 (Q4); say so; this understates uncertainty for the rarest groups |
| ACS cells are not independent within a table | Independent draws, as in the Census Bureau's approximation for sums; stated as a limitation |
| 224 tests at 0.05 | Report the raw count and the Benjamini-Hochberg count (Q3) |
| The permutation test answers "more uneven than random residential placement", not "caused by roads" | Say that in one sentence |
| New York numbers move when the 23 New York counties land | All scripts rerunnable; the paper re-render preview catches it |
| New Methods paragraph cuts against the "no new paragraphs" voice rule | Q2: Tim approves the subsubsection, or the clarifications go into the Results paragraphs instead |
| Journal length limits | Report words added in U-5 |
| Playwright not applicable | No web page in this work; figures and PDFs are checked by rendering and viewing them |

## 5. Open questions for Tim

- **Q1. Map colour scale:** keep the shared 0.70-1.00 for both maps (as now, recommended so race and income compare), or give each map its own data extent?
- **Q2. Methods:** add the short `Scaling Up to Metropolitan Planning Organizations` subsubsection (recommended), or fold those sentences into the Results section?
- **Q3. Multiple testing:** headline the Benjamini-Hochberg count (recommended) and give the raw count beside it?
- **Q4. ACS zero cells:** hold estimates of 0 at 0 (recommended), or draw them like any other cell?
- **Q5. Apply the permutation test and ACS intervals to the ten New York regions too** (recommended: answers the small-group reviewer point)?

## 6. Needs Tim's approval before it happens

Applying T-014 to the manuscript; the new Methods subsubsection (Q2); any change to the New York headline numbers.

## 7. Answers (Tim, 2026-11-20)

- **Q1:** shared 0.70-1.00 colour scale on both maps (ND25 confirmed).
- **Q2:** add the short Methods subsubsection "Scaling Up to Metropolitan Planning Organizations" after "Estimating Exposure per Region" (U-5).
- **Q3:** no multiplicity adjustment ("I don't think adj is necessary"). The headline is the raw count with p0 < 0.05. U-1 drops `p0_bh` and the BH count from its outputs; U-5 reports the raw count only.
- **Q4:** hold zero-estimate cells at 0 in the ACS draws (U-2), stated as a limitation.
- **Q5:** not asked; proceeding on the recommendation (permutation test and ACS intervals for the ten New York regions too, U-3) unless Tim says otherwise.
