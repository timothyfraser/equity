# Plan: national figure (tile maps + scatters) and the missing CAT runs

Status: **proposed, 2026-11-20. Nothing here is implemented except a labelled mock-up.** Wait for Tim.
Repo `timothyfraser/equity`, branch `dev`. Extends `PLAN_NATIONAL.md` (sections 11-12 still stand).

## 0. Rulings recorded (Tim, 2026-11-20)

- **ND12. Equal-group is the national headline.** "The point of this was to actually show: Equal group matters ... no matter how many members there are in a group, it is not appropriate for members of different races or different ages or different incomes to be exposed disproportionately." The population-weighted score is shown only as the reviewer-facing companion. The size caveat goes in the text.
- **ND13. The ranked bar chart is retired** ("totally unreasonable and unreadable"). It is replaced by a four-panel figure: two tile-grid maps and two scatter plots. The full ranking stays as a supplementary table (`national/tables/mpo_index.csv`).
- **ND14. Run the missing CAT counties** on Cloud MOVES, all orders at once. Blocked on access (section 1.1).

## 1. Current state, measured

### 1.1 Why no CAT orders were placed (root cause)

| Check | Result |
|---|---|
| Saved CAT secret in this environment (`get_environment`) | Hosts `cat-apps.com`, `api.cat-apps.com`; injected as header `Authorization` |
| What `api.cat-apps.com` is | The public, read-only data API (`/cat-public`). It has no order route (`platform/api-public/plumber.R`: every route is GET except one stats POST). The order-by-API-key design (`platform/docs/DESIGN_API_BULK_ORDERS.md`, W8-9) is "DESIGN ONLY. Nothing here is implemented." |
| Where orders go | `POST https://connect.systems-apps.com/cat-api/orders`, JSON `{geoid, year}`; no tables means a default-input run (`endpoints_orders.R` `h_order_create`) |
| What that route needs | Header `X-Movesai-Auth: Bearer <sign-in token>`. `Authorization` is intercepted by Posit Connect before the API sees it (`/cat-api/info` says so). No secret for `connect.systems-apps.com` exists here. |
| Live probe, 2026-11-20 | `GET /cat-api/orders` with no token: 401. With a dummy `X-Movesai-Auth`: 401 `"Please sign in again."` (hint `token_provider_retired`), so the header reaches the API and only a real sign-in token is missing |
| A sign-in token | Comes from `POST /cat-api/auth/login` (email and password) or `/auth/refresh`; short-lived (`expires_in`). The agent must not handle the password. |
| research-mcp broker from this session | `broker_whoami` = `scorecard-cloud`, scopes `socialinfra:*` only. No `movesai:*` scope, so no MOVES job tools. |
| After a run finishes | Each order must be published (`POST /cat-api/orders/<id>/publish`, needs an approved verification for the geoid or admin; sanity guard can 409) and the Connect job `cat-drain-publish-queue` rebuilds `detail/<geoid>.parquet`, `year/2022.parquet` and the manifest |

So the key Tim gave works for reading published data (which needs no key) and cannot place orders. Nothing is broken; the session lacks a sign-in token for the private API.

### 1.2 Which counties are needed

| Set | Counties | Why |
|---|---|---|
| A. MPO blockers | 6: 35035, 51041, 51199, 51740, 51760, 51810 | Block El Paso, Richmond, Tri Cities, Hampton Roads (`national/LEDGER.md`) |
| B. New York | 24 (list in `paper_equity/.contract/r0/CAT_2022_RUN_REQUEST.md`) | Exact 2022 for all 62 NY counties; the paper currently interpolates these |
| C. Other 2020-only counties | 31 (rest of `CAT_2022_RUN_REQUEST_37.md`) | In no multi-county MPO; not needed for the chart |
| D. Puerto Rico | 78 municipios, no CAT data at all | Blocks the Puerto Rico MPO; ACS coverage for PR also untested |

Recommended: A + B = 30 orders. C and D only if Tim wants them.

### 1.3 Figure mock-up (run on the 220 MPOs in hand)

`national/proto/proto_tilemap.R` → `national/proto/proto_tilemap.png`, data `national/proto/proto_tilemap_data.csv`.

- **Tile grid works.** 220 MPO centroids (EPSG:5070) assigned to a 26 x 16 grid by minimum total squared displacement (`clue::solve_LSAP`, already installed). Mean displacement 1.36 cells, max 3.63. The country's outline is recognisable; the East is dense, the West sparse. No Alaska or Hawaii MPO is multi-county.
- **Emissions and population are nearly the same variable across MPOs:** r(log emissions, log population) = 0.974.
- **Race index against total emissions:** β = 0.020 per log unit (SE 0.002, p < 0.001). With log population added: β = -0.008 (p = 0.40). The slope is a size effect.
- **Race index against emissions per capita:** β = -0.049 (SE 0.008, p < 0.001). MPOs with more emissions per resident are less even on race.
- **Income index:** total emissions β = 0.003 (SE 0.001, p = 0.034); per capita β = -0.011 (SE 0.005, p = 0.022).
- **Race index against log population alone:** R² = 0.32.
- Mock-up defect to fix in V-3: tile label colour is wrong on light tiles in panel B.

## 2. Tasks

Rules: PLAN_NATIONAL section 4 applies (disjoint `owns`, receipts in `.contract/national/receipts/<id>.md`, parse check after every R edit, never hand-type a number, orchestrator commits). Tier: **O** Opus, **S** Sonnet.

### Track C: CAT runs (blocked on C-0)

**C-0 Access and scope (Tim).** Decide Q1 (how the session gets a sign-in token) and Q2 (county sets). Nothing below starts before this.

**C-1 Order script (S).** Depends C-0.
- Owns `national/cat_orders/county_list.csv`, `national/cat_orders/submit_orders.R`, `national/cat_orders/ORDERS.csv`.
- `county_list.csv`: `geoid, year (2022), set (A|B|C|D), reason`. Built from `national/LEDGER.csv` blocking counties and the two request files; no hand-typed geoids.
- `submit_orders.R <--dry-run | --live>`: for each row not already in `ORDERS.csv`, `GET /cat-api/orders?geoid=<g>&year=2022` (skip if an order for that county-year exists), then `POST /cat-api/orders` with JSON `{"geoid": "<g>", "year": 2022}`. Appends `geoid, year, order_id, submitted_utc, http_status` to `ORDERS.csv` after every call. The script sends header `X-Movesai-Auth: Bearer placeholder`; the session proxy replaces the value. It never reads, prints or stores a token.
- Boundaries: default is `--dry-run`; `--live` refuses to run if the list has more rows than `MAX_ORDERS` (set to the approved count); stops on the first 401 or 5xx; never retries a POST.
- Accept: dry run prints one line per county and makes no POST; live run gives one order id per county in `ORDERS.csv`; rerunning live submits nothing new.

**C-2 Watch and publish (S).** Depends C-1.
- Owns `national/cat_orders/publish_orders.R`.
- Poll `GET /cat-api/orders/<id>/summary` (read-only) until `available` is true; record the sanity tier. Then `POST /cat-api/orders/<id>/publish` with `{"if_absent": true}`. A 409 `publish_sanity_block` is logged and left for Tim (admin `confirm` is his call, never sent by the script).
- Accept: every order in `ORDERS.csv` ends as `published`, `already_published` or `blocked_for_tim` with the API's message.

**C-3 Objects rebuilt (catdashboard session or Tim).** Depends C-2. The `cat-drain-publish-queue` Connect job publishes the new `detail/` and `year/2022` objects and a new manifest. This session does not run platform jobs. Accept: `curl https://api.cat-apps.com/objects/LATEST` returns a manifest newer than `MANIFEST-e2ccfae4.tsv` and `year/2022.parquet` holds the ordered geoids.

**C-4 Pick up the new runs (S).** Depends C-3.
- `bash national/run_national.sh` (reprocesses every MPO under the new manifest; blocked MPOs clear automatically).
- New York: `cd index && Rscript make_emissions.R && Rscript run_ny.R && Rscript make_results.R && Rscript make_diff.R`, then in `paper_equity`: `python3 -I .contract/r0/preview/rerender.py` (preview first, Tim approves, then `--target`).
- Accept: `national/LEDGER.md` shows 0 `blocked_cat` except Puerto Rico (unless set D ran); MPOs with no member county in the new runs have identical indices before and after (diff of `national/index_mpo.csv` restricted to them is empty); `results.json` `_meta.emissions.counties_using_exact_2022_pm25` = 62.

### Track V: national figure (can start now, on the 220 MPOs)

**V-1 MPO table (S).**
- Owns `national/mpo_table.R`, `national/tables/mpo_wide.csv`.
- One row per `done` MPO: `mpo_id, mpo_name, state, n_counties, n_states, pop_in_mpo, race, income, edu, age, overall, race_pw, income_pw, race_groups_lt_1000, emissions (sum of emissions_county * share_county_affected from members.csv), rate (emissions / pop_in_mpo), x, y (centroid, EPSG:5070)`. Lift the code from `national/proto/proto_tilemap.R`.
- Accept: row count equals `done` in `LEDGER.csv`; no missing values; New York MPO values equal `national/out/<id>/indices.csv`.

**V-2 Tile grid (S).** Depends V-1.
- Owns `national/tile_grid.R` (function `get_tile_grid(cen, ncol = 26, nrow = 16)`), `national/tables/mpo_tiles.csv`; adds `clue` to `setup.sh`.
- The grid is assigned over **all** multi-county MPOs with a polygon in the contiguous US (done and blocked), so tiles do not move when blocked MPOs finish; blocked tiles are drawn as empty outlines.
- Accept: every MPO has a unique cell; same input gives the same output; receipt reports mean and max displacement (mock-up: 1.36 and 3.63 cells) and the share of MPO pairs whose east-west and north-south order is preserved.

**V-3 Four-panel figure (S, `dataviz` skill).** Depends V-2, V-4.
- Owns `national/figures.R` (rewritten), `national/fig/mpo_national_percapita.png`, `national/fig/mpo_national_total.png`. Deletes `national/fig/mpo_rank_*.png` (ND13).
- A: tile map, race index. B: tile map, income index. C: race index against emissions. D: income index against emissions. Both x-axis versions are built (per capita, total); Tim picks one for the paper (Q3).
- Reuse: the paper's plasma hues for race and income (`get_lines`, `get_emissions_slopes` in `index/functions.R`); the log-fit line style of `get_emissions_slopes` (white under-stroke, `y ~ log(x)`); zoomed axis with the start value stated (D13).
- Tiles: one sequential hue per map, darker = less even, legend bar under each map, state abbreviation in each tile with text colour chosen by tile luminance, New York MPOs outlined. Scatters: point area by population, fitted curve and 95% band from V-4, coefficient label read from `results_national.json`, never typed.
- Accept: rebuilds from `mpo_wide.csv`, `mpo_tiles.csv` and `results_national.json` alone; legible at 7.5 in wide (checked at 2x by screenshot); no tile label unreadable; fits one journal page.

**V-4 Curve estimates (O spec review, S build).** Depends V-1.
- Owns `national/models.R`, `.contract/national/results_national.json` (schema `results/v1`).
- For each index (race, income, edu, age, overall) and each x (total emissions, emissions per capita): (1) OLS `index ~ log(x)`, the paper's form, with HC3 and state-clustered standard errors; (2) the same with `log(pop_in_mpo)` added; (3) a GAM `s(log(x), k = 5)` for shape, reporting effective degrees of freedom; (4) beta regression (logit link) as a robustness check, since the index lies in (0, 1). Adds `betareg` and `sandwich` to `setup.sh`.
- Accept: every coefficient, SE, p, R² and n is in `results_national.json` with evidence strings; the mock-up's numbers in section 1.3 are reproduced by model (1) and (2) to three decimals.

**V-5 Small-group null (O design, S run). Needs Tim's yes (Q4).** Depends V-1.
- Owns `national/null_sim.R`, `national/tables/mpo_null.csv`.
- For each MPO, simulate the index under perfect equity: each group's exposed residents drawn as Binomial(group population in tract, tract exposed share), 500 draws, seed 1. Report the mean and 5th percentile of the simulated index, and each MPO's observed index relative to them.
- Purpose: the size caveat in the text gets a number ("an MPO of this size would score x by chance alone"), which defends the equal-group headline instead of weakening it.
- Accept: simulated index rises with population; table has one row per MPO; New York regions included for the paper.

**V-6 Paper section (O, edit proposals only).** Depends V-3, V-4, (V-5), and C-4 or Tim's go to write it on 220 of 225.
- Owns `paper_equity/.contract/r0/edits/T-014.md` (proposals; nothing applied without Tim).
- Results subsection "National comparison of MPOs", a Methods paragraph (MPO assignment by tract interior point, whole-county rate for partial counties, Connecticut county crosswalk, MPO coverage), the figure and caption, the supplementary table. Every number a `{{results:...}}` placeholder into `results_national.json`. Tim's voice (`tim-results`, `tim-methods` skills).
- Accept: `apply_edits`-style preview compiles with 0 errors; yellow diff built for Tim.

Order: V-1 → V-2 and V-4 (parallel) → V-3 → V-5 (if approved) → V-6. Track C runs beside it once C-0 is answered.

## 3. Risks

| Risk | Evidence | Handling |
|---|---|---|
| The national race pattern is mostly MPO size | r(log emissions, log pop) = 0.974; race slope on total emissions vanishes with population (p = 0.40); race ~ log pop R² = 0.32 | Per-capita x-axis (Q3); V-4 model (2); V-5 null. The text must not claim that higher-emission regions are more even on race without this |
| Same issue reaches the New York paper | The paper says regions with higher total emissions are more even on race (r = 0.529, n = 10) | After V-4, check whether that sentence needs softening; Tim decides |
| Tile map read as true geography | Max displacement 3.63 cells; East crowded | Caption states tiles are approximate; state abbreviations on tiles |
| Orders cost money and cannot be unsent | 99.1% of historic orders came from one script; no quota on the submit path (`DESIGN_API_BULK_ORDERS.md` section 0) | Dry run by default, hard cap, duplicate check, no POST retries, ledger after every call (C-1) |
| Token expires mid-run | Sign-in tokens are short-lived | Submit all orders in one pass (seconds each); publishing later needs a fresh token |
| Publish refused | Needs verification for each geoid or admin; sanity guard compares with the published 2020 value | Script records the 409 and stops for Tim (C-2) |
| New York numbers change again | 24 counties move from interpolated to exact 2022 | `rerender.py` preview and Tim's approval before the manuscript changes (C-4) |
| MPOs are not independent observations | Neighbouring MPOs share states and road networks | State-clustered SEs in V-4; say so in the text |

## 4. Open questions for Tim

- **Q1. How does this session get a CAT sign-in token?** (a) Tim saves a fresh token in the secure credential form for host `connect.systems-apps.com`, header `X-Movesai-Auth`, prefix `Bearer` (the agent never sees it; valid about an hour, long enough to submit everything) — recommended; (b) hand tracks C-1 to C-3 to a session in the CATDASHBOARD environment; (c) give this session's broker token `movesai` builder scopes (runs MOVES outside the order pipeline; publishing unclear; not recommended).
- **Q2. Which counties?** A + B (30 orders, recommended); add C (61); add D, Puerto Rico (139).
- **Q3. Scatter x-axis in the paper figure:** emissions per capita (recommended), total emissions, or both as a 2 x 2 scatter block.
- **Q4. Run the small-group null simulation (V-5)?** Recommended yes.
- **Q5. Write the paper section on 220 MPOs now, or wait for the CAT runs?** Recommended: figure and models now, paper text after C-4.

## 5. Needs Tim's approval before it happens

Placing any order (C-1 live), publishing any order (C-2), changing the manuscript (C-4 rerender, V-6), and adding the null simulation as a method (V-5).

---

# Revision 2 (Tim, 2026-11-20): rulings and the tasks as dispatched

## R2.0 Rulings

- **ND15. Scatter x-axis = emissions per capita on a log scale, labelled in original units** (not log values). One model only: `index ~ log(emissions per capita)`. New York keeps its current figure and total-emissions axis.
- **ND16. Tile map is one cohesive, US-shaped block.** Tiles touch; no gaps for geography. No state abbreviations on tiles (they read as states; a tile is an MPO). Not sized by population.
- **ND17. Map text.** Title "Race/ethnicity equity index per metropolitan planning organization" (and "Income equity index per ..."). Subtitle exactly "One tile per MPO, arranged nearest its location." Fill legend titled with the index name.
- **ND18. Scatter text.** Clear titles, no subtitle, y-axis titles kept. Annotation: Greek β, its SE, and p exact to three decimals, or "p < 0.001". No GAM line, no second model.
- **ND19. Shared scale.** Race and income share one index scale, 0.70 to 1.00, in both maps and both scatters.
- **ND20. Label the extremes.** On each map the most and least equal MPO get a thin black outline and a leader line to a label giving the MPO name and its index (three decimals). The same two MPOs are ringed in the matching scatter.
- **ND21. Replication data rule.** Do not store raw CAT emissions in GitHub when they can be pulled from CAT public without a key. Store only values the analysis produces (indices, MPO totals) plus the exact query URLs and the CAT manifest name, and say that values may change slightly as CAT is updated.
- **ND22. Paper section "Scaling up":** two or three paragraphs at the end of Results, written after the CAT runs land (Q5 as recommended).
- **CAT orders:** Tim's local CAT session places them (Q1 option b). Counties: the 37 in `CAT_2022_RUN_REQUEST_37.md` plus the 24 New York counties = 61, no Puerto Rico. Hand-off text: `.contract/national/CAT_ORDERS_HANDOFF.md`.
- **Q4 (chance simulation):** not ruled; explained again to Tim, not started.

## R2.1 Tasks (supersede V-1..V-4 in section 2 where they differ)

**R-1 Replication data rule (S).** First; no dependencies.
- Owns `.gitignore`, `README.md` (data section only), `index/test/EMISSIONS_SOURCES.md` (new), `national/run_mpo.R`, `national/pilot/run_pilot_mpo.R`, `national/migrate_drop_county_emissions.R` (new), every `national/out/*/members.csv`, `national/out/*/indices.csv`, `national/pilot/out/*/members.csv`.
- Do: (1) `git rm --cached` the tracked NY emissions files `index/test/emissions.rds`, `emissions_2020_2025_endpoints.rds`, `emissions_2022_exact.rds`, `emissions_all_pollutants.{rds,csv}` and gitignore them; keep `emissions_provenance.txt`. Confirm `index/make_emissions.R` regenerates each one; if one is not regenerated, add that to `make_emissions.R` rather than keep the file. (2) `run_mpo.R` and `run_pilot_mpo.R`: stop writing `emissions_county`; write MPO-level `emissions_mpo` (sum over member counties of `emissions_county * share_county_affected`) and `emissions_rate_mpo` (= `emissions_mpo / pop_in_mpo`) into `indices.csv`. (3) Migration script: for every existing `out/<id>`, add those two columns to `indices.csv` from `members.csv`, then drop `emissions_county` from `members.csv`. Idempotent. (4) `EMISSIONS_SOURCES.md` + README: the exact URLs (`https://api.cat-apps.com/objects/LATEST`, `.../objects/year/<YYYY>.parquet` for 2020-2025), the manifest used (`MANIFEST-e2ccfae4.tsv`), no key needed, and "CAT is updated over time, so re-pulled values may differ slightly from the ones behind the paper."
- Accept: `git ls-files | grep -E 'emissions_.*\.(rds|csv)$'` returns only `demo/` (left alone per CLAUDE.md); moving the five NY files aside and running `Rscript make_emissions.R` recreates them and `all.equal` to the moved copies is TRUE; no committed `members.csv` has an `emissions_county` column; every `done` MPO's `indices.csv` has `emissions_mpo` and `emissions_rate_mpo`; `Rscript national/run_mpo.R 36197300` still gives indices identical to the committed ones.

**V-1 MPO table (S).** Depends R-1.
- Owns `national/mpo_table.R`, `national/tables/mpo_wide.csv`.
- One row per `done` MPO: `mpo_id, mpo_name, state, n_counties, n_states, pop_in_mpo, race, income, edu, age, overall, race_pw, income_pw, race_groups_lt_1000, emissions_mpo, emissions_rate_mpo`. Reads `national/out/*/indices.csv` and `national/LEDGER.csv` only.
- Accept: rows = `done` count in `LEDGER.csv`; no NA; spot check three MPOs against their `indices.csv`.

**V-2 Cohesive tile grid (O).** No dependencies.
- Owns `national/tile_grid.R`, `national/tables/mpo_tiles.csv`, `national/fig/tile_grid_check.png`.
- Tiles: every MPO with status `done` or `blocked_cat` in `national/LEDGER.csv` whose polygon centroid lies in the contiguous US (excludes Puerto Rico; no AK or HI MPO is multi-county). Centroids in EPSG:5070 from `index/cache/national/mpo/<id>.geojson` (re-fetch with `get_mpo_polygon()` in `national/pilot/pilot_functions.R` if missing).
- Mask: lower-48 + DC outline (`tigris::states(cb = TRUE, year = 2022)`), EPSG:5070. Square cells; choose the cell size so the count of cells whose centre falls inside the outline is the smallest count >= N tiles.
- Assignment: minimum total squared distance from centroid to cell centre (`clue::solve_LSAP`). Surplus cells go to the edge: add dummy rows that cost 0 on boundary cells (fewer than 4 in-mask neighbours) and a large constant elsewhere, then drop them. The design is the agent's to improve (for example a density-equalising pre-step so East Coast MPOs are not pushed inland); judge by the acceptance numbers and the picture.
- Out `mpo_tiles.csv`: `mpo_id, col, row, cx, cy` (centroid), `disp_cells`.
- Accept: one 4-connected block; no empty cell enclosed by occupied cells; deterministic; the receipt reports mean and max displacement in cells and the share of MPO pairs whose east-west and north-south order is preserved; `tile_grid_check.png` shows the block with US outline beside it, and it reads as the US.

**V-4 Models (S).** Depends V-1.
- Owns `national/models.R`, `national/results_national.json`.
- For each index (race, income, edu, age, overall): OLS `index ~ log(emissions_rate_mpo)`; record `beta, se, p, r2, n` (classical SE, the figure's numbers) plus `se_hc3, p_hc3` and `se_cluster_state, p_cluster_state` (`sandwich`, cluster = MPO's primary state). Also `extremes.<index>.{min,max} = {mpo_id, mpo_name, value}` and `coverage = {done, single_county, blocked_cat, pending}` from `LEDGER.csv`, `cat_manifest`, `generated_utc`. Leaf objects follow the paper's `{value, status, evidence}` style.
- Accept: valid JSON; race β ≈ -0.049 (the mock-up's figure, three decimals) with the current data; every number the figure prints exists in the JSON.

**V-3 Four-panel figure (S, `dataviz` skill).** Depends V-2, V-4.
- Owns `national/figures.R` (rewrite), `national/fig/mpo_national.png`; deletes `national/fig/mpo_rank_*.png` and `national/proto/` once accepted.
- Implements ND16-ND20 exactly. Reuse the paper's plasma hues for race and income (`index/functions.R` `get_lines`). Map: sequential single hue, darker = less even, scale 0.70-1.00 (extend down by 0.05 steps only if a value falls below), legend titled with the index name, blocked MPOs as empty outlined tiles labelled once in the legend or caption as "awaiting CAT data". Scatter: x = `emissions_rate_mpo` converted to kg per resident, log10 axis with plain-number labels, axis title "On-road PM2.5 emissions per resident, kg, 2022 (log scale)"; y title = index name; OLS line `y ~ log(x)` with 95% band; annotation from `results_national.json` only.
- Accept: rebuilds from `mpo_wide.csv`, `mpo_tiles.csv`, `results_national.json` alone; looked at as a rendered PNG at 2x: no overlapping labels, extremes labels legible and outside the block, legend titles present, both maps and both scatters on 0.70-1.00.

Order: R-1 and V-2 in parallel → V-1 → V-4 → V-3. Paper text (V-6, "Scaling up") waits for the CAT runs.
