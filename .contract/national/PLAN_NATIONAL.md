# PLAN — National section: equity index for every U.S. MPO

Status: **PROPOSED (revision 2, 2026-11-20), waiting for Tim. Nothing implemented.**
Supersedes revision 1 (county-first design, rejected by Tim).
Scouts: `scouts/NAT_S1_TIMING.md`, `scouts/NAT_S2_REGIONS.md`.

## 0. Tim's direction (verbatim, 2026-11-20)

- "The whole point of this was to use the emissions data, so no, we're not going to do it at the county level and cancel out the emissions term."
- "repeating this at the national level ... the purpose there would be to show, hey, which MPOs have the highest equity versus inequity. It would be like a giant bar chart."
- "I don't think the point would be to compare urban versus rural in that section ... I would use the existing MPO boundaries."
- Earlier the same day: the national result goes into the Journal of Transport Geography paper ("Add to this paper"), and the hosts should be allowed.

## 1. Design in one paragraph

Each MPO is treated like one of New York's regions. Its census tracts are assigned to the MPO. Its member counties (whole or partial) contribute CAT emissions through the paper's own equations (Eqs. 5-10):
- each county's emissions rate per exposed resident (Eq. 7) applies to the MPO tracts in that county;
- group burden shares are summed across the MPO's counties (Eq. 9);
- the equity index (Eq. 1, corrected normaliser) is computed per MPO.

The national output is one ranked chart of about 400 MPOs, plus a table. It uses the same code path as the New York paper, so New York's MPOs double as a consistency check against the state results.

## 2. What we measured (2026-11-20)

| Input | Status | Evidence |
|---|---|---|
| MPO boundaries | **Not in any of Tim's repos.** catdashboard has an "mpo" user type and two hand-made NYC groups (`platform/web/src/data/cube/groups.ts`), no boundaries; movesai `optim/cmaq.csv` names MPOs on CMAQ projects but has no geography; no public GitHub mirror found | orchestrator grep of catdashboard main, dev, cursor/visualizer, feature/tim-project-beta; movesai; research-mcp; `api.github.com` search |
| Official MPO source | BTS National Transportation Atlas Database, "Metropolitan Planning Organizations" layer (geodata.bts.gov / ArcGIS hub) | **blocked** (proxy 403), NAT-S2 |
| TIGER roads, tracts, counties | **blocked** (`www2.census.gov` 403) | NAT-S1 |
| Allowing the hosts from this session | `update_environment` call **rejected by the environments service** (nothing changed) | orchestrator, 2026-11-20 |
| CAT emissions, county totals | ready: `year/2020.parquet` 3,146 counties, `year/2025.parquet` 3,100; 2021-2024 about 740-770 each | orchestrator |
| CAT emissions by road type | ready per county in `detail/<geoid>.parquet` (`by = 15`: road types 2 rural restricted, 3 rural unrestricted, 4 urban restricted, 5 urban unrestricted). Example Albany 2020 PM2.5: 1.2 / 2.0 / 19.6 / 18.3 tons. Detail files are 1.5-4 MB each (about 3-8 GB for all counties) | orchestrator |
| ACS 2022 5-year | ready: `CENSUS_API_KEY` works, about 2 s per state call | NAT-S1 |
| Geometry cost | about 70-80 s per county with the current code (NY cached shapes); code runs in lon/lat on the sphere (no `st_transform`), likely slower than an equal-area projection | NAT-S1, orchestrator |
| Interpolation coverage (D16) | 3,068 counties have at least 2 of 2020-2025; 45 lack 2025 (VA, WV, SD, NM); 38 have one year | orchestrator |

## 3. Method details to settle

1. **Assigning tracts to MPOs.** Recommended: a tract belongs to an MPO if its interior point (`st_point_on_surface`) lies inside the MPO polygon. Each tract then sits in exactly one MPO or none, and partial counties are handled naturally: Eq. 7's county rate applies only to the county's MPO tracts. Alternative: area-weighted partial tracts (more exact, more geometry).
2. **County emissions for partial counties.** Eq. 8 already allocates a county's emissions in proportion to exposed residents, so an MPO receives the share of county emissions that its tracts' exposed residents represent. No new assumption is needed.
3. **Single-county MPOs (needs Tim).** When an MPO lies inside one county, every exposed resident shares that county's rate, so the emissions weight is constant across its tracts. Its index then reflects who lives near major roads, not how much those roads emit. Two options:
   - **(a) Report as is,** and flag single-county MPOs in the chart.
   - **(b) Road-type weighting (recommended).** Split each county's emissions over road classes using CAT's `by = 15` table. Match TIGER road classes: MTFCC S1100 primary ≈ restricted access; S1200 secondary ≈ unrestricted; urban vs rural from the census urban-area flag. Give each tract's exposed residents the emissions rate of the road classes in its buffer. Emissions then vary within counties, which uses more of CAT and answers CEUS Reviewer 1's "quiet rural state road vs congested interstate" point. It costs the detail downloads, one road-class join per buffer, and a short methods paragraph. It also changes the New York numbers if applied there, so the paper must pick one method for both.
4. **Weighting of groups (Tim, 2026-11-20).** The equal-group index stays the headline. Justification (Tim): "There is no reason that a Black person or a Native American person should be exposed to more or less air pollution, regardless of how many people there are." Report the population-weighted score beside it.
   - Add a small-group robustness check: drop groups under 1,000 people in a unit.
   - In New York this check keeps Mohawk Valley lowest on race (0.819 all groups; 0.870 groups ≥ 1,000; 0.882 groups ≥ 5,000; orchestrator run 2026-11-20). Those numbers must move into `results.json` before the paper cites them.
   - Nationally, many MPOs have very small groups, so the robustness column matters more there.
5. **Emissions year.** D16 rule nationally (piecewise between nearest of 2020-2025). Counties without 2025 or with one year: nearest available year, flagged.
6. **Geography mismatches.**
   - Connecticut: ACS 2022 and TIGER 2022 use planning regions; CAT uses the old counties. Assign CT tracts to the old counties through tract-to-2020-county codes, so tracts carry their CAT county's rate.
   - Alaska and South Dakota code renames: fixed crosswalk.
   - Puerto Rico: out of scope.

## 4. Cost

| Item | Estimate |
|---|---|
| Counties touched by MPOs | about 1,000-1,300 (unknown until boundaries arrive) |
| Geometry at 300 m, current code | about 20-30 CPU-hours (1,100 counties × 70-80 s); 5-8 h wall on 4 CPUs |
| With an equal-area projection (N-002) | expected several times faster; to be measured |
| Census pull | under 5 minutes for 51 states |
| CAT detail files (only if 3b) | about 1-4 GB for MPO counties; downloaded once, cached outside git |
| Final outputs committed to git | under 10 MB (MPO × group tallies, indices, crosswalk) |
| Intermediates (TIGER, buffers, overlaps) | gitignored `cache/`; one release archive at submission |

## 5. Tasks

Model tier: **O** = Opus, **S** = Sonnet. 15-minute units, disjoint `owns`, files plus a receipt, orchestrator commits. Repo `timothyfraser/equity`, branch `dev`. The NY regression gate (N-003) keeps the paper's NY numbers byte-identical unless Tim picks option 3b.

**N-000 Rulings (Tim).** Section 7. Blocks everything.

**N-001 Data access (Tim).**
- Add these hosts to the environment in claude.ai Settings (the session's own request was rejected): `www2.census.gov` (TIGER), `geodata.bts.gov` and `services.arcgis.com` (BTS NTAD MPO layer, served through ArcGIS).
- Or download on your own machine and commit to `data/national/raw/` (raw files are gitignored if over 50 MB; commit a checksum file instead):
  - the BTS NTAD "Metropolitan Planning Organizations" layer as GeoPackage or shapefile, recording the download date and URL;
  - TIGER 2022 tracts and primary-secondary roads (per state, about 1-3 GB).
- Accept: from this container, `curl -sI https://www2.census.gov/geo/tiger/TIGER2022/PRISECROADS/` returns 200 and the MPO layer is readable with `sf::st_read`; or the files exist in `data/national/raw/` with checksums.

**N-002 Geometry engine benchmark (O then S).**
- Owns `national/bench/`.
- For three MPOs of different sizes (one single-county, one about 5 counties, one 10+ counties, picked from the layer), time the current code (s2, lon/lat) against an EPSG:5070 planar variant: buffer roads once per county, then intersect with tracts.
- Accept: tract overlap shares agree within 0.5 percentage points for 99% of tracts; seconds per county for both; choice recorded in `national/bench/BENCH.md`.
- Depends N-001.

**N-003 State-aware library with NY regression gate (S).**
- Owns `index/functions.R`, only these functions: `get_state`, `get_shapes_*`, `get_area_roads`, `get_county_group_values`, `get_all`, `get_overall`. Also owns `index/tests/test_national_refactor.R`.
- Add arguments for state FIPS, CRS, cache dir and a tract-to-unit table.
- Remove the `path_shapes_buffers` global side effect (NAT-S1 bug 7).
- Add per-county checkpoints in `get_area_roads`.
- Accept: `Rscript index/tests/test_index.R` passes, and `make_results.R` reproduces `results.json` byte-identically (sha256 of `jq -S .` before and after).
- Depends N-002.

**N-004 MPO crosswalk (S).**
- Owns `national/make_mpo_xwalk.R`, `data/national/mpo_tracts.parquet` (tract geoid, county geoid, mpo_id, mpo_name, state(s)) and `data/national/mpo_counties.csv` (mpo_id, county geoid, share of county tracts).
- Assign tracts by interior point (or the rule Tim picks).
- Accept: every tract is in at most one MPO; MPO count equals the layer's; counties-per-MPO distribution reported; NY MPOs listed with their counties for Tim to eyeball.
- Depends N-001, N-000.

**N-005 Census pull for MPO states (S).**
- Owns `national/make_census.R`, `data/national/census_tracts.parquet`, `data/national/census_counties.parquet`.
- `retrieve_census2` over all states containing MPO tracts, ACS 2022 5-year, tract and county, including `_M` margin-of-error columns.
- Accept: NY rows equal `index/test/census_tracts.rds` exactly; tract count reported.
- Depends N-000.

**N-006 Emissions for MPO counties (S).**
- Owns `national/make_emissions_national.R`, `data/national/emissions_2020_2025.parquet` and `data/national/fips_crosswalk.csv`. If 3b is chosen, also owns `data/national/emissions_roadtype_2022.parquet`.
- Use `retrieve_emissions_bulk` for all MPO counties, 2020-2025, pollutant 110 (plus the 11 sensitivity pollutants), then `get_emissions_interpolated` (D16). If 3b, also read `detail/<geoid>.parquet` with `by = 15`, interpolated the same way.
- Accept: every MPO county has a 2022 value or a flag; NY values equal the NY run.
- Depends N-000.

**N-007 Geometry run for MPO counties (S, background).**
- Owns `national/run_geometry.R`, `cache/`, `data/national/area_roads_300.parquet`.
- Run per state, 3 parallel workers, checkpointed and resumable under `nohup`.
- Accept: overlap shares for every MPO tract; NY tracts equal `index/test/area_roads300.rds` within the N-002 tolerance; wall time per state logged.
- Depends N-002, N-003, N-004, N-005.

**N-008 MPO indices (S).**
- Owns `national/make_mpo_index.R`, `data/national/index_mpo.parquet`, `.contract/national/results_national.json`.
- For each MPO and dimension, compute:
  - the equal-group index (headline);
  - the population-weighted index;
  - the robustness index on groups ≥ 1,000;
  - counties, tracts, population, single-county flag, interpolation flags.
- If 3b, compute the road-type-weighted version too.
- Accept: values in [0,1]; the JSON validates against `revisions/templates/results.schema.json`; a regression on NY MPOs computed two ways (MPO run vs NY state run restricted to the same counties) agrees to 1e-9.
- Depends N-006, N-007.

**N-009 The chart and table (S, `dataviz` skill).**
- Owns `national/figures.R`, `national/fig/mpo_rank.png`, `national/fig/mpo_rank_race.png`, `national/tables/mpo_index.csv`.
- One ranked chart of all MPOs (overall index, about 400 bars or dots, ordered, coloured by population class), and a race-only version.
- Label the top and bottom 15; flag single-county MPOs and interpolation fallbacks.
- Use a zoomed axis (D13 style) with the start value stated.
- Accept: regenerates from `results_national.json` only; readable at the journal's full-page width (check at 2× scale).
- Depends N-008.

**N-010 Sensitivity (S).**
- Owns `national/sensitivity.R`.
- Rank correlation of MPO indices across 300 m vs 100 m and 500 m for a sample of 30 MPOs, and across emissions-year variants.
- Accept: Spearman ρ reported.
- Depends N-008.

**N-011 Paper section (O, edit proposals only).**
- Owns `paper_equity/.contract/r0/edits/T-015.md`.
- A new short subsection, "National comparison of MPOs" (Results), plus a Methods paragraph on MPO assignment (and road-type weighting if 3b), the figure and caption, and one or two Discussion sentences.
- This is an approved exception to the no-new-paragraph rule, because Tim asked for the section. Everywhere else the rule still holds.
- Numbers are `{{results_national:...}}` placeholders.
- Accept: proposals preview cleanly with the T-010a pipeline; net words reported.
- Depends N-008, N-009.

**N-012 Release and docs (S).**
- Owns `README.md` (national section), `national/README.md`.
- Release archive of intermediates; rebuild-from-scratch instructions.
- Accept: a fresh clone plus the release asset rebuilds `results_national.json`.
- Depends N-009.

## 6. Order and timing

```
N-000, N-001 (Tim) ─► N-002 ─► N-003 ─┐
                      N-004 ─────────┤
                      N-005 ─────────┼─► N-007 (5-8 h background) ─► N-008 ─► N-009 ─► N-011 ─► (Tim) ─► apply
                      N-006 ─────────┘                                 └─► N-010
```

Agent time about 3-4 hours plus the background geometry run. Realistic: two days from the moment the data are reachable. This delays the JTG submission by that much.

## 7. Questions for Tim

1. **Q1 Data access.** Add `www2.census.gov`, `geodata.bts.gov` and `services.arcgis.com` in Settings, or download the MPO layer and TIGER files yourself?
2. **Q2 Tract-to-MPO rule.** Tract interior point inside the MPO (recommended), or area-weighted partial tracts?
3. **Q3 Emissions within counties.**
   - **(b) Road-type weighting from CAT `by = 15` (recommended).** Uses more of CAT, and gives single-county MPOs a real emissions signal. If chosen, apply it to New York too and rerun the paper's numbers.
   - **(a) County rates as in the current paper.** Flag single-county MPOs.
4. **Q4 Which MPOs.** All of them (about 400), or only multi-county MPOs?
5. **Q5 Robustness column.** Groups ≥ 1,000 people (recommended) or another threshold?
6. **Q6 Timing.** Hold the JTG submission for the national section (about two days once data are reachable), as chosen, or submit New York now and send the national section later?

## 8. Risks

| Risk | Effect | Mitigation |
|---|---|---|
| Hosts stay blocked | Nothing geometric can run here | Tim downloads (N-001 alternative) |
| MPO layer vintage and edits | MPO lists change over time | Record layer date; cite NTAD version |
| Partial tracts at MPO edges | Small assignment error | Interior-point rule; report share of MPO population in edge tracts |
| Single-county MPOs | Emissions weight is constant inside them | Q3 option b, or flag |
| Small groups | Noisy equal-group scores | Robustness column; ACS MOE pulled for a later bootstrap |
| Compute overrun | Longer wait | Planar engine (N-002), checkpoints, 300 m only nationally |
| Road-type mapping (3b) | TIGER MTFCC does not equal MOVES road type exactly | Documented mapping; sensitivity with option a |

---

## For agents

- Reuse `index/functions.R` (corrected index, absent-group rule, piecewise emissions interpolation), `index/cat_bulk.R` (`retrieve_emissions_bulk`), `index/make_results.R` (results JSON pattern), `paper_equity/.contract/r0/preview/apply_edits.py` (proposal preview and apply).
- CAT objects: `https://api.cat-apps.com/objects/LATEST`, `year/<YYYY>.parquet` (`by = 16`), `detail/<geoid>.parquet` (all `by` codes, including 15 = road type).
- The NY small-group robustness numbers quoted in 3.4 came from an ad hoc run; N-008 (and T-011b for the paper) must regenerate them through `make_results.R`.
