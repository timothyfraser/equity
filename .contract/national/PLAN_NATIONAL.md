# PLAN — National section: equity index for every U.S. MPO

Status: **PROPOSED (revision 3, 2026-11-20). Nothing implemented. Data access is open; work can start once Tim answers section 7.**
Supersedes revision 2. Road-type method: `docs/ROADTYPE_METHOD.md`. Scouts: `scouts/NAT_S1_TIMING.md`, `scouts/NAT_S2_REGIONS.md`.

## 0. Tim's rulings (2026-11-20)

- "The whole point of this was to use the emissions data, so no, we're not going to do it at the county level and cancel out the emissions term."
- Purpose: "show which MPOs have the highest equity versus inequity ... like a giant bar chart." Not an urban-versus-rural comparison.
- Use the existing MPO boundaries (BTS NTAD layer).
- Road-type weighting from CAT `by = 15`: **yes**, and applied to New York too. A gate (G1) decides whether it replaces the paper's headline.
- Ranked chart: **multi-county MPOs only.** Single-county MPOs are computed and listed in the table.
- Equal-group index is the headline: "There is no reason that a Black person or a Native American person should be exposed to more or less air pollution, regardless of how many people there are." Population-weighted and small-group robustness (groups ≥ 1,000) sit beside it.
- Goes into the Journal of Transport Geography paper.
- Defaults taken without objection: tracts join an MPO by interior point; robustness threshold 1,000 people.

## 1. Design

Each MPO is treated like one of New York's regions, with the paper's own equations.

- A tract belongs to the MPO that contains its interior point.
- Every county touched by an MPO is processed whole. Its emissions rate per exposed resident (Eq. 7) uses all its tracts.
- The MPO sums emissions only over its own tracts (Eq. 8), so a partial county gives the MPO the part of its emissions that the MPO's exposed residents account for.
- Emissions are split over four road classes inside each county (`docs/ROADTYPE_METHOD.md`), so the emissions term no longer cancels inside a county.
- Group shares are summed across the MPO's counties (Eqs. 9-10); the index is Eq. 1.
- Population shares for an MPO are sums over its tracts, not county totals.
- Year: D16 rule (piecewise linear between the nearest of 2020-2025). Counties with one usable year take that year and are flagged.
- Connecticut: tracts map to the eight old counties (CAT's geography) through a fixed tract crosswalk. Alaska and South Dakota renames: fixed crosswalk. Puerto Rico: out.

Two methods are computed for every MPO: `county_rate` (the paper today) and `roadtype`. The chart shows `roadtype`.

## 2. What we measured (2026-11-20)

| Input | Status | Evidence |
|---|---|---|
| Hosts | **Open.** `www2.census.gov`, `geodata.bts.gov`, `services.arcgis.com` return 200 | orchestrator, after Tim's Settings change |
| MPO boundaries | BTS NTAD FeatureServer, 411 polygons, WGS84, item modified 2026-04-03. Fields `OBJECTID, AREA, MPO_ID` (8-char text), `MPO_NAME, STATE, Shape__Area, Shape__Length`. Not in any of Tim's repos | orchestrator |
| TIGER 2022 | `PRISECROADS/` and `UAC/` (`tl_2022_us_uac20.zip`) listings return 200 | planner |
| CAT county totals | `year/2020.parquet` 3,146 counties, `year/2025.parquet` 3,100; 2021-2024 about 740-770 each | orchestrator |
| CAT by road type | `detail/<geoid>.parquet`, `by = 15`, 4.2 MB for Albany. Columns `by, year, geoid, pollutant, sourcetype, fueltype, regclass, roadtype, emissions, vmt, ...` | planner |
| **Road-type split differs by year** | Albany PM2.5, road types 2/3/4/5/off-network: 2020 = 1.2/2.0/19.6/18.3/absent (total 41.1); 2022 = 9.1/10.7/9.9/14.8/10.7 (55.1); 2025 = 5.6/7.0/6.5/10.1/10.0 (39.2). 2015 looks like 2020. Rural share jumps from 8% to 36% | planner |
| Cached NY roads | `index/test/shapes_roads.rds` is one dissolved feature per county, no MTFCC. New York needs a fresh download | orchestrator |
| ACS 2022 5-year | `CENSUS_API_KEY` works, about 2 s per state call | NAT-S1 |
| Geometry cost | about 70-80 s per county with current code (lon/lat, no projection) | NAT-S1 |
| D16 coverage | 3,068 counties have at least 2 of 2020-2025; 45 lack 2025 (VA, WV, SD, NM); 38 have one year | orchestrator |
| NY small-group check (ad hoc) | Mohawk Valley race index 0.819 all groups; 0.870 groups ≥ 1,000; 0.882 groups ≥ 5,000; lowest in all three | orchestrator |

## 3. Cost

| Item | Estimate |
|---|---|
| Counties touched by MPOs | about 1,000-1,300 (known after N-004) |
| Geometry, 300 m, five buffers per county (4 classes + union) | 20-30 CPU-hours for the union alone with current code; N-002 measures the planar engine. Budget 8-16 h wall on 4 CPUs |
| CAT detail files | 1.5-4 MB each, about 3-5 GB for MPO counties; cached, never committed |
| Committed outputs | under 10 MB |

## 4. Rules for every task

- Repo `timothyfraser/equity`, branch `dev`. One 15-minute unit each unless marked background. Disjoint `owns`. Files plus a receipt in `.contract/national/receipts/<id>.md`; the orchestrator commits.
- Model tier: **O** Opus, **S** Sonnet. Planning units may use Fable (ND7).
- Never hand-type a number. Keep superseded functions under `_legacy`. Parse check after every R edit.
- Downloads go to `cache/` (gitignored). Every download records URL, date and sha256 in `data/national/SOURCES.csv`.
- New York's `results.json` variants other than the new one stay byte-identical: `jq -S . results.json | sha256sum` on the existing variants before and after.

## 5. Tasks

### Wave 0 — done or Tim
- **N-000 Rulings.** Section 0. Open items: section 7.
- **N-001 Data access.** **Done.**

### Wave 1 — parallel, no dependencies

**N-004 MPO crosswalk (S).**
- Owns `national/make_mpo_xwalk.R`, `data/national/mpo.gpkg`, `data/national/mpo_tracts.parquet`, `data/national/mpo_counties.csv`, `data/national/fips_crosswalk.csv`, `data/national/SOURCES.csv`.
- In: `https://services.arcgis.com/xOi1kZaI0eWDREZv/arcgis/rest/services/NTAD_Metropolitan_Planning_Organizations/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=geojson` (one request); TIGER 2022 tracts for 50 states + DC (`tigris::tracts(state, year = 2022)`, cached in `cache/tiger/tracts/`).
- Do: tract interior point (`st_point_on_surface`, EPSG:5070) in MPO polygon. A point inside two MPOs goes to the MPO covering more of the tract's area; count these. Map CT tracts to old counties and apply AK/SD renames; write the crosswalk.
- Out `mpo_tracts.parquet`: `geoid` (chr 11), `geoid_county` (chr 5, CAT geography), `state_fips`, `mpo_id` (chr 8, NA outside any MPO), `mpo_name`. One row per tract in every MPO county (members and non-members).
- Out `mpo_counties.csv`: `mpo_id, mpo_name, states, geoid_county, n_tracts_in_mpo, n_tracts_county, n_counties, multi_county` (TRUE when the MPO has tracts in 2+ counties).
- Accept: 411 features read; each tract in at most one MPO; MPOs with zero tracts listed; counts of multi-county and single-county MPOs; whether `STATE` lists several states for multi-state MPOs; New York MPOs with their counties printed in the receipt.

**N-005 Census pull (S).**
- Owns `national/make_census.R`, `data/national/census_tracts.parquet`, `data/national/census_counties.parquet`.
- Do: `retrieve_census2` for 50 states + DC, ACS 2022 5-year, tract and county, same columns as `index/test/census_tracts.rds` plus `_M` columns.
- Accept: New York rows equal `index/test/census_tracts.rds` and `census_counties.rds` exactly (`all.equal`); row counts per state in the receipt.

**N-006 County emission totals (S).**
- Owns `national/make_emissions_national.R`, `data/national/emissions_2020_2025.parquet`.
- Do: `retrieve_emissions_bulk` for all counties, 2020-2025, the 11 pollutants. No interpolation here.
- Out: `geoid, pollutant, year, emissions`.
- Accept: New York rows equal `index/test/emissions_all_pollutants.rds` for shared keys; count of counties by number of available years.

**N-002 Geometry engine benchmark (O design, S run).**
- Owns `national/bench/`.
- Do: on three New York county sets (Hamilton; Albany + Rensselaer + Schenectady + Saratoga; the five NYC boroughs), time current code (lon/lat) against EPSG:5070 planar with roads buffered once per county.
- Accept: `national/bench/BENCH.md` gives seconds per county for both, share of tracts whose overlap share agrees within 0.5 points (need 99%), and one chosen engine with its `crs` and `sf_use_s2` setting.

**N-014 Road-type vintage audit (S). New.**
- Owns `national/audit_roadtype.R`, `data/national/roadtype_audit.csv`, `.contract/national/scouts/NAT_S3_ROADTYPE.md`.
- Do: download `detail/<geoid>.parquet` for the 62 New York counties plus 150 random other counties (seed 1) to `cache/cat_detail/`. Keep `by == 15`, pollutant 110, years 2020-2025.
- Out: `geoid, year, rt1..rt5, total16, sum_2to5, has_rt1`.
- Accept: the scout file reports, per year, the share of counties with an off-network row, the share where road types 2-5 sum to the county total, the median rural share, and the median absolute change in each class's weight between 2020 and 2025. It ends with one sentence: are the splits comparable across years or not.

### Wave 2 — serial, both edit `index/functions.R`

**N-003 State-aware library (S).** Depends N-002.
- Owns `index/functions.R` (only `get_state`, `get_shapes_counties`, `get_shapes_tracts`, `get_shapes_roads`, `get_shapes_buffers`, `get_area_roads`; old bodies kept as `_legacy`), `index/tests/test_national_refactor.R`.
- Do: accept geoids from several states (loop by state); add `crs` and `cache_dir` arguments with the N-002 engine as an option and current behaviour as default; remove the `path_shapes_buffers` global write; per-county checkpoints in `get_area_roads`.
- Accept: `Rscript index/tests/test_index.R` and `test_national_refactor.R` pass; `Rscript index/make_results.R` leaves `results.json` byte-identical (`jq -S . | sha256sum`).

**N-013 Road-type functions and New York run (O review, S build).** Depends N-003, N-014, Q1.
- Spec, signatures, schemas, tests and acceptance: `docs/ROADTYPE_METHOD.md`, "For agents".
- Owns `index/functions.R` (new functions only: `get_roads_by_class`, `get_area_roads_by_class`, `get_roadtype_weights`, `get_county_group_values_roadtype`), `index/make_roadtype.R`, `index/tests/test_roadtype.R`, `index/test/roads_by_class.rds`, `index/test/area_roads300_by_class.rds`, `index/test/emissions_roadtype.rds`, `index/test/roadtype_flags.csv`.
- Accept: `cd index && Rscript make_roadtype.R && Rscript tests/test_roadtype.R && Rscript tests/test_index.R` all pass, including the collapsed-class regression at 1e-9.

### Wave 3 — parallel

**N-015 New York `rerun_roadtype` variant and gate G1 (S). New.** Depends N-013.
- Owns `index/make_results.R` (one new variant), `index/runs/variant_A_roadtype/`, `paper_equity/.contract/r0/RERUN_DIFF_ROADTYPE.md`.
- Do: add variant `rerun_roadtype` (same inputs as `rerun`, road-type weighting). Table of `rerun` against `rerun_roadtype` per region and dimension, rank changes, and the lowest region on race.
- Accept: existing variants byte-identical; new variant validates against the results schema.
- **G1 (Tim):** does `rerun_roadtype` replace `rerun` as the paper's headline?

**N-016 Detail downloads and class weights, national (S). New.** Depends N-004, N-013.
- Owns `national/make_roadtype_national.R`, `data/national/emissions_roadtype.parquet`, `data/national/roadtype_flags.csv`.
- Do: download detail files for every county in `mpo_counties.csv` (4 parallel, resumable, `cache/cat_detail/`); keep `by == 15`, pollutant 110, 2020-2025; run `get_roadtype_weights`.
- Out `emissions_roadtype.parquet`: `geoid, class, w, emissions_class, rt_flag`.
- Accept: one row per county and class; `w` sums to 1 per county; flag counts; New York rows equal the N-013 values.

**N-007 Geometry run (S, background).** Depends N-003, N-004, N-013.
- Owns `national/run_geometry.R`, `data/national/area_roads_300_by_class.parquet`, `national/logs/`.
- Do: for every county in `mpo_counties.csv`, by state, 3 workers under `nohup`, resumable: `get_roads_by_class` then `get_area_roads_by_class(dist = 300)` with the N-002 engine.
- Out: `geoid, geoid_county, class ("all","2","3","4","5"), area_total, area_roads`.
- Accept: every tract of every MPO county present with class `all`; New York rows equal `index/test/area_roads300_by_class.rds` within the N-002 tolerance; seconds per state logged; counties that failed listed (must be zero).

### Wave 4

**N-008 MPO indices (S).** Depends N-005, N-006, N-007, N-016.
- Owns `national/make_mpo_index.R`, `data/national/index_mpo.parquet`, `.contract/national/results_national.json`.
- Do: `get_county_group_values_roadtype(unit = mpo_tracts)` for the four dimensions, twice (`classes = "all"` for `county_rate`; four classes for `roadtype`), then `get_region_group_values(region = "unit_id")` and `get_indicator`.
- Out, one row per `mpo_id × method × dimension` (dimension in race, income, edu, age, overall): `index_equal`, `index_pw`, `index_equal_min1000`, `n_groups`, `n_groups_min1000`, `n_counties`, `multi_county`, `n_tracts`, `pop`, `flags`.
- Accept: indices in [0,1] or NA with a reason; JSON validates against `revisions/templates/results.schema.json`; for New York MPOs made of whole counties, the MPO result equals the same code run with those counties as a region, to 1e-9; threshold 0 reproduces `index_equal`.

### Wave 5 — parallel

**N-009 Chart and table (S, `dataviz` skill).** Depends N-008.
- Owns `national/figures.R`, `national/fig/mpo_rank.png`, `national/fig/mpo_rank_race.png`, `national/tables/mpo_index.csv`.
- Do: ranked chart of multi-county MPOs, `roadtype` method, equal-group index; markers for the population-weighted and ≥ 1,000 values on the same row; top and bottom 15 labelled; New York MPOs highlighted; zoomed axis with the start value stated. Race-only version. The CSV holds all MPOs, both methods.
- Accept: rebuilds from `results_national.json` alone; legible at full-page journal width (checked at 2×).

**N-010 Sensitivity (S).** Depends N-008.
- Owns `national/sensitivity.R`, `national/tables/sensitivity.csv`.
- Do: Spearman ρ of MPO ranks between `roadtype` and `county_rate`; equal-group against ≥ 1,000; and 100 m and 500 m for 30 sampled MPOs (seed 1).
- Accept: ρ values written to `results_national.json` under `sensitivity`.

**N-011 Paper section (O, edit proposals only).** Depends N-008, N-009, G1.
- Owns `paper_equity/.contract/r0/edits/T-015.md`.
- Do: Results subsection "National comparison of MPOs"; Methods paragraph on MPO assignment and road-type weighting (Eqs. 2c-8c from `docs/ROADTYPE_METHOD.md`); figure and caption; one or two Discussion sentences; the limits listed in the method doc. Numbers are `{{results_national:...}}` placeholders. Approved exception to the no-new-paragraph rule.
- Accept: previews cleanly with the T-010a pipeline; net words reported.

**N-012 Release and docs (S).** Depends N-009.
- Owns `README.md` (national section), `national/README.md`.
- Accept: fresh clone plus the release archive of intermediates rebuilds `results_national.json`.

## 6. Order

```
Wave 1: N-004  N-005  N-006  N-002  N-014
Wave 2: N-003 ─► N-013                      (Q1 answered before N-013)
Wave 3: N-015 ─► G1 (Tim)    N-016    N-007 (background, 8-16 h)
Wave 4: N-008
Wave 5: N-009  N-010  N-011 (after G1)  N-012
```

About 4-5 agent-hours plus the background run. Two to three days. The JTG submission waits for it.

## 7. Questions for Tim

1. **Q1 Which year's road-type split?** The split changes sharply between CAT years (section 2).
   - **(a) 2020 split for every county (recommended).** Available for 3,146 counties, looks like local road data, one consistent basis. Levels still follow D16.
   - (b) D16 per road type, as first planned. Mixes two kinds of run; New York's 38 exact-2022 counties get a different split from the other 24.
   - (c) Wait for the N-014 audit, then decide.
2. **Q2 Off-network emissions** (starts, idling; about a quarter of PM2.5 where reported).
   - **(a) Spread over the four road classes in proportion (recommended).** County total unchanged.
   - (b) Drop them; on-road only. Changes the county totals and the New York numbers again.
3. **Q3 Chart headline with very small groups.** With ten race groups, a small MPO's equal-group score is driven by groups of a few dozen people.
   - **(a) Chart ranks by the equal-group index, with the ≥ 1,000 value as a second marker on each row (recommended).**
   - (b) Chart ranks by the ≥ 1,000 version; all-groups in the table.

## 8. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| Road-type split not comparable across years | Class weights are an artefact of which run a year came from | N-014, Q1 |
| TIGER primary/secondary roads carry all unrestricted-road emissions | Local-street emissions land on people near state routes | State it in Methods; N-010 compares against `county_rate` |
| Census urban areas differ from MOVES urban boundaries | Emissions in a class with no matching road | Merge rule; flags reported |
| A class with very few exposed residents | A handful of tracts carry a large share of county emissions | Diagnostic in N-013 and N-016; reported, not altered |
| Small groups | Noisy equal-group scores | ≥ 1,000 column; Q3 |
| Partial tracts at MPO edges | Small assignment error | Interior-point rule; count reported |
| NTAD layer changes | MPO list drifts | Layer date and sha256 in `SOURCES.csv` |
| Compute overrun | Longer wait | Planar engine, checkpoints, 300 m only |
| New York numbers change a third time (G1) | Paper edits redone | Gate before any paper edit; both variants kept |

---

## For agents

- Reuse `index/functions.R` (`get_index`, `get_indicator`, `get_region_group_values`, `get_emissions_interpolated`), `index/cat_bulk.R` (`retrieve_emissions_bulk`), `index/make_results.R` (variant and JSON pattern), `paper_equity/.contract/r0/preview/apply_edits.py`.
- CAT objects: `https://api.cat-apps.com/objects/` + `LATEST`, `year/<YYYY>.parquet` (`by = 16`), `detail/<geoid>.parquet` (`by = 15` has `roadtype` 1-5; 1 is absent in some years).
- `get_region_group_values` computes `eshare = sum(emissions_group) / sum(emissions)`. For MPO units `emissions` must be the unit's allocated emissions, not the county total (method doc).
- `get_county_group_values` yields `NaN` for a county with no exposed residents. The road-type function drops and flags it.
- The NY small-group numbers in section 2 are ad hoc; N-008 and paper task T-011b regenerate them through code.
- `CONTRACT.yaml` in this folder carries `depends`, `owns` and `definition_of_done` per task and wins on any difference.
