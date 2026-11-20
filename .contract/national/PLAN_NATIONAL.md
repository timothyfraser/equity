# PLAN — National equity index (all U.S. counties)

Status: **PROPOSED 2026-11-20, waiting for Tim. Nothing implemented.**
Scope: extend the New York equity pipeline in this repo to every U.S. county.
Evidence: two read-only scouts (`scouts/NAT_S1_TIMING.md`, `scouts/NAT_S2_REGIONS.md`) and direct measurements by the orchestrator, all on 2026-11-20.

## 1. The short answer

Yes, it is feasible. The hard part is computer time, not design. One choice makes the rest easy:

**Compute the index for every county first, then group counties into regions afterwards.** The costly geometry (road buffers × census tracts) is per county. Inside one county the emissions term cancels, so a county's index needs no emissions at all. Emissions only weight counties when they are combined into a region. Once the per-county group tallies exist, any region scheme takes seconds: states, metro areas, commuting zones, MPOs, or New York's REDC regions. So "how do we split counties?" does not block the run. We can report several schemes and pick the headline afterwards.

## 2. What we measured

| Input | Status from this session | Evidence |
|---|---|---|
| Emissions (CAT) | Ready. `year/<YYYY>.parquet` is national, about 0.3 MB per year, under 1 s each. 2020: 3,146 counties; 2025: 3,100; 2021-2024: about 740-770 each | orchestrator, `api.cat-apps.com/objects` |
| Interpolation coverage (rule D16: piecewise between nearest years 2020-2025) | 3,068 counties have at least 2 years; 38 have only 1 year; 45 lack 2025 (VA 15, SD 12, WV 10, NM 4, AK 1 lacks 2020) | orchestrator |
| Census ACS 2022 5-year (tracts and counties) | Ready. `CENSUS_API_KEY` works; about 2 s per state call; 51 states about 2-4 minutes | NAT-S1 step 1 |
| TIGER roads, tracts, counties (tigris) | **Blocked**: `www2.census.gov` returns proxy 403 | NAT-S1 step 2 |
| Region schemes: commuting zones (USDA ERS), BEA Economic Areas, MPO boundaries (BTS NTAD) | **Blocked**: ers.usda.gov, apps.bea.gov, geodata.bts.gov, services.arcgis.com | NAT-S2 |
| Metro/micro areas (CBSA) | Partly: a legacy (about 2013-2018) county-CBSA list from a CRAN package; the 2022 ACS API exposes a metro-area → state → county hierarchy (needs one call per state; untested for the CBSA code column) | NAT-S2; orchestrator |
| CAT county-group registry | Only states, the nation and two custom groups: no MPOs or commuting zones | orchestrator, `lookup/groups.parquet` |
| Geometry cost | About 70-80 s per county (buffer + tract overlap), measured on New York's cached shapes; 3 counties in 3.5-4 min. **Extrapolation, not measured nationally** | NAT-S1 step 3 |
| Geometry engine | `functions.R` never projects; sf runs buffers and intersections on the sphere (s2) in lon/lat. Planar math in an equal-area projection (EPSG:5070) is usually several times faster | orchestrator (`grep st_transform` = 0 hits) |

### Geography mismatches that need a rule

| Case | Problem | Proposed rule |
|---|---|---|
| Connecticut | ACS 2022 and TIGER 2022 use 9 planning regions (09110-09190); CAT emissions use the 8 old counties | County-level index needs no emissions, so compute it per planning region. For regional aggregation, apportion old-county emissions to planning regions by the share of near-road area (or use 2020 geography for CT). Needs Tim |
| Alaska 02063, 02066 (Valdez-Cordova split), 02158 vs 02270, South Dakota 46102 vs 46113 | Census and CAT use different codes | Fixed crosswalk table in `data/national/fips_crosswalk.csv` |
| Puerto Rico (78 municipios) | No CAT emissions | Out of scope (50 states + DC) unless Tim wants the county-level index only |
| 45 counties without 2025, 38 with one year | Cannot interpolate 2022 | Use the nearest available year and flag them; or drop from regional weights. Needs Tim |

## 3. Cost and storage

| Item | Estimate | Confidence |
|---|---|---|
| Census download | 2-4 min | measured |
| Emissions download | under 1 min | measured |
| TIGER download (roads, tracts, counties for 51 states) | about 1-3 GB raw zips; time unknown | not measured (blocked) |
| Geometry at 300 m, current code | 17-70 CPU-hours; 4-18 h wall on this 4-CPU machine | extrapolated from NY |
| Geometry at 300 m, projected (EPSG:5070) + parallel by state | expected several times faster; to be measured in N-002 | hypothesis |
| Five buffer distances (sensitivity) | about 5× the 300 m cost; propose a stratified sample of states instead | extrapolated |
| Worst single state | Texas (254 counties): 1.4-5.6 h per distance at current speed | extrapolated |
| Disk, intermediates (roads, tracts, buffers, overlaps) | about 0.6-1 GB per distance | extrapolated |
| Disk, final outputs (per-county group tallies, indices) | under 20 MB | estimate: 3,143 counties × about 26 groups |

**Storage rule (proposed):** commit only small outputs (per-county tallies and indices as Parquet/CSV, crosswalks, results JSON) to GitHub. Keep TIGER shapes and buffers out of git: cache them locally under `cache/` (gitignored), keyed by state and vintage, rebuildable from the scripts. Publish one archive of the intermediates as a GitHub Release asset (or Zenodo, for a DOI) when the paper is submitted. Do not use Git LFS.

## 4. How to split counties into regions

All options run after the county tallies exist, so this is a reporting choice.

| Scheme | Complete? | Size | Fit to Tim's question | Obtainable now? |
|---|---|---|---|---|
| County (no grouping) | yes, 3,143 | 1 county | The national map. Simplest and most transparent | yes |
| State | yes, 51 | 3-254 counties | Coarse; one comparison table | yes |
| CBSA (metro + micro) + "rest of state, nonmetro" | yes, about 960 | median 1 county | Fine-grained; nonmetro remainders are odd shapes | partly (legacy list; current list via Census API, to verify) |
| USDA Commuting Zones 2020 | yes, about 600 | several counties | Closest national analogue to NY's REDC regions (labour-market regions that include rural areas) | blocked: needs ers.usda.gov |
| BEA Economic Areas | yes, 179 | many counties | Coarser regional economies | blocked: needs apps.bea.gov |
| MPOs | **no**, urbanised areas only (about 410) | partial counties | Tim's preference for planning relevance; leaves rural areas out, which is exactly where the NY finding sits | blocked: needs geodata.bts.gov |

**Recommendation:**
- **Headline:** a county-level national map of the index, plus a commuting-zone version as the REDC-like national partition.
- **Companion:** a per-MPO table for the planning audience, with an explicit "outside any MPO" class. Without that class, the MPO version cannot speak to rural corridors.
- Keep New York's REDC regions as the bridge back to the current paper.

## 5. Method changes the national version forces

1. **Equal-group weighting gets worse nationally.** With 10 race groups, counties where a group is a handful of people will drive the equal-group index; the red team already flags this as the fatal issue for New York (`paper_equity/.contract/r0/REVIEWER_SIM.md`). Nationally, the headline should be the population-weighted score, or the equal-group score with a bootstrap over ACS margins of error and a minimum group size. **Needs Tim.**
2. **ACS margins of error** are available from the same API calls (`_M` columns); pull them now, so a bootstrap is possible later without re-downloading.
3. **County-level index needs no emissions**, which answers the air-quality reviewer more honestly: the index is about who lives near major roads; emissions only weight places within a region.

## 6. Tasks

Model tier: **O** = Opus (architecture/judgement), **S** = Sonnet (implementation). Every unit: 15-minute box, disjoint `owns`, files plus a receipt, orchestrator commits. Branch: `dev` in `timothyfraser/equity`; NY outputs and `index/` behaviour must stay byte-identical (regression gate in N-003).

**N-000 Rulings (Tim).** Q1-Q8 in section 7. Blocks everything except N-001.

**N-001 Network access (Tim + orchestrator).**
- Add `www2.census.gov` (TIGER via tigris) to this environment's allowed hosts. Optionally also add `ers.usda.gov`, `apps.bea.gov` and `geodata.bts.gov` for the region files. This is a change to Tim's personal environment, so it needs his approval in the prompt `update_environment` shows.
- Alternative: Tim downloads the three region files on his machine and commits them.
- Accept: `curl -sI https://www2.census.gov/geo/tiger/TIGER2022/PRISECROADS/` returns 200 from this container.

**N-002 Measure and choose the geometry engine (O, then S).** Owns `national/bench/`.
- For Delaware (3 counties), Vermont (14) and one large state (Georgia, 159), run the current per-county method (s2, lon/lat) and a projected variant: `st_transform(5070)`, `sf_use_s2(FALSE)`, buffer the state's roads once, union per county, then `st_intersection` of tracts with the county's buffer. Record seconds per county per stage, RAM, and the tract overlap area.
- Accept: projected and current overlap shares agree within 0.5 percentage points for 99% of tracts (median absolute difference reported); per-county seconds measured for both; a written choice in `national/bench/BENCH.md`.
- Depends N-001.

**N-003 Make the library state-aware without changing NY (S).** Owns `index/functions.R` (only `get_state`, `get_shapes_counties`, `get_shapes_tracts`, `get_shapes_roads`, `get_shapes_buffers`, `get_area_roads`, `get_county_group_values`, `get_all`, `get_overall`) and `index/tests/test_national_refactor.R`.
- Add explicit arguments for state FIPS, CRS, cache directory and region table.
- Remove the global `path_shapes_buffers` side effect in `get_shapes_buffers` (scout bug 7).
- Add per-county checkpointing to `get_area_roads` (skip counties whose output file exists).
- Defaults keep current NY behaviour.
- Accept: `Rscript index/tests/test_index.R` passes, and rerunning `make_results.R` reproduces `results.json` exactly. Check: `jq -S . | sha256sum` before and after equal.
- Depends N-002 (engine choice).

**N-004 National census pull (S).** Owns `national/make_census.R`, `data/national/census_tracts.parquet`, `data/national/census_counties.parquet`.
- Loop `retrieve_census2` over 50 states + DC for tracts and counties, ACS 2022 5-year, including the `_M` margin-of-error columns for every table used.
- Use `nanoparquet` to write; retry each state once on failure.
- Accept: 51 states present; tract count within 1% of 85,000; NY rows equal the cached NY census exactly.
- Depends N-000 (Q5 MOE).

**N-005 National emissions and FIPS crosswalk (S).** Owns `national/make_emissions_national.R`, `data/national/emissions_2020_2025.parquet`, `data/national/fips_crosswalk.csv`.
- Use `retrieve_emissions_bulk` for all counties and years 2020-2025, all 11 pollutants. Interpolate 2022 with `get_emissions_interpolated` (D16).
- Write the crosswalk for CT, AK and SD per section 2, and flag counties without 2025.
- Accept: 3,143 county rows for pollutant 110 after crosswalk, with the flags column populated; NY values equal `test/emissions_all_pollutants.rds` interpolation exactly.
- Depends N-000 (Q3, Q4).

**N-006 National geometry run (S, long-running).** Owns `national/run_geometry.R`, `cache/` (gitignored), `data/national/tallies_300.parquet`.
- Per state, in parallel (`future`/`furrr`, 3 workers):
  - download TIGER (tigris cache in `cache/tigris`);
  - build buffers with the N-002 engine;
  - compute tract overlap shares;
  - compute per-county group tallies with `get_county_group_values` logic: affected and population by group, plus area totals.
- Checkpoint per county; resumable; runs under `nohup` with a log.
- Accept: tallies exist for every county in N-005's list; NY tallies equal the NY run within 1e-9 (or within the N-002 tolerance if the engine changed); run log shows wall time per state.
- Depends N-002, N-003, N-004, N-005.
- **Note:** the 15-minute box applies to writing and smoke-testing the script on two states; the full run is a background job the orchestrator monitors.

**N-007 County and state indices (S).** Owns `national/make_indices.R`, `data/national/index_county.parquet`, `data/national/index_state.parquet`, `.contract/national/results_national.json`.
- For each county and state: equal-group index (corrected), population-weighted index, and both per dimension, using `get_region_group_values`/`get_indicator`. If Q5 = bootstrap: 200 ACS-MOE draws per county with 95% intervals.
- Accept: values in [0,1]; NY state-level values equal a fresh NY run with one region "New York"; results JSON validates against `revisions/templates/results.schema.json`.
- Depends N-006.

**N-008 Region crosswalks (S).** Owns `data/national/regions_*.csv`, `national/make_regions.R`.
- Write state, CBSA (current, via Census API or the 2023 list), CBSA + rest-of-state, commuting zones (if N-001 allowed), BEA EA (if allowed), MPO by largest area overlap plus "outside MPO" (if allowed), and NY REDC.
- Accept: each partition scheme covers 100% of counties exactly once (except MPO, which reports coverage); counts match NAT-S2's.
- Depends N-001 (for CZ/EA/MPO).

**N-009 Regional indices per scheme (S).** Owns `national/make_regional.R`, `data/national/index_<scheme>.parquet`, additions to `results_national.json`.
- Aggregate the county tallies with emissions weights (2022 interpolated) per scheme.
- Accept: NY REDC regions reproduce `paper_equity` `table2.rerun` exactly.
- Depends N-007, N-008.

**N-010 Figures (S, `dataviz` skill).** Owns `national/figures.R`, `national/fig/*.png`.
- National county choropleth (equal-group and population-weighted side by side; the CAT `lookup/geo_counties_svg.parquet` or TIGER counties), a state ranking, a commuting-zone map, and an MPO table (top and bottom 20).
- Accept: all figures regenerate from `results_national.json` and parquet files only; checked by viewing each at phone width.
- Depends N-009.

**N-011 Sensitivity on a sample (S).** Owns `national/sensitivity.R`, outputs.
- Buffer distances 100 m to 2 km for a stratified sample of 6 states (largest urban, most rural, CT, a VA/WV gap state), plus the emissions-year variants.
- Accept: rank correlation of county indices across distances reported per state.
- Depends N-007.

**N-012 Paper framing (O + Tim).**
- Decide between a national section added to the JTG submission and a separate follow-up paper (section 7, Q1).
- Write a one-page outline for that paper. Make no manuscript edits without Tim.
- Depends N-009.

**N-013 Release and docs (S).** Owns `README.md` (national section), `national/README.md`, release notes.
- GitHub Release asset or Zenodo deposit for the intermediates; reproduce-from-scratch instructions.
- Accept: a fresh clone can rebuild `results_national.json` from the scripts plus the release asset.
- Depends N-010.

## 7. Questions for Tim

1. **Q1. Which paper?** Recommended: submit the New York paper to JTG now, unchanged by this, and make the national version its own follow-up paper. Adding it now delays the submission your coauthor needs.
2. **Q2. Network.** Allow `www2.census.gov` in this environment (required), plus `ers.usda.gov`, `apps.bea.gov` and `geodata.bts.gov` (for commuting zones, economic areas, MPOs)? Or download those three files yourself?
3. **Q3. Connecticut.** Planning regions with apportioned emissions (recommended), or 2020 geography?
4. **Q4. Counties without 2025 emissions (45) or with one year (38).** Nearest available year, flagged (recommended), or drop from regional weights?
5. **Q5. National headline weighting.** Population-weighted (recommended); equal-group with ACS-MOE bootstrap; or both?
6. **Q6. Regions.** County map plus commuting zones plus MPO companion (recommended), or MPOs only?
7. **Q7. Puerto Rico.** Out of scope (recommended) or county-level index only?
8. **Q8. Compute.** Run here in the background (4 CPUs, about 4-18 h at current speed, less after N-002), or on a bigger machine you control?

## 8. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| TIGER host stays blocked | Nothing geometric can run here | N-001; or Tim's machine runs N-006 |
| Geometry slower than estimated | Run spans days | N-002 engine choice; parallel by state; checkpointing; 300 m only nationally |
| Small-group noise dominates equal-group index | Misleading national map | Q5; MOE columns pulled in N-004 |
| CT and other code mismatches | Missing or wrong counties | `fips_crosswalk.csv`, counted in N-005 acceptance |
| Region files unavailable | No CZ/MPO results | County, state and CBSA results do not depend on them |
| Interpolation gaps outside NY | 83 counties need a fallback | Q4 flag column, reported in every table |
| Storage creep in git | Slow repo | Storage rule in section 3 |

---

## For agents

- Reuse: `index/functions.R` (all index maths; T-003 corrected normaliser and absent-group rule), `index/cat_bulk.R` (`retrieve_emissions_bulk`, `cat_manifest_name`), `index/make_results.R` patterns for results JSON, `revisions/templates/results.schema.json`.
- The NY regression gate (N-003) is the guarantee that the national refactor does not change the paper's numbers.
- Scout evidence and exact error strings: `.contract/national/scouts/`.
