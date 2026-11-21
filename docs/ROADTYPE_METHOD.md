# Road-type emissions weighting

Status: **specification, 2026-11-20. Nothing implemented.** Task N-013 in `.contract/national/PLAN_NATIONAL.md`.
Ruling (Tim, 2026-11-20): use CAT road types, apply to New York too, gate before it replaces the paper's headline.

## What it does

The paper spreads each county's emissions evenly over everyone living within 0.3 km of a major road. So inside one
county the emissions term cancels, and a quiet rural state road counts the same as a congested interstate.

This method splits each county's emissions over four road classes, using CAT's own road-type table, and gives each
class's emissions only to the people living near roads of that class. Emissions then vary inside a county.

Nothing after Equation 8 changes. Equations 1, 9, 10 and 11 are untouched.

## Data

| Input | Source | Fields used |
|---|---|---|
| Roads | TIGER/Line 2022 primary and secondary roads, `tl_2022_<SS>_prisecroads.zip` (`tigris::primary_secondary_roads(state, year = 2022)`) | `LINEARID`, `MTFCC` (`S1100` primary, limited access; `S1200` secondary), `geometry` |
| Urban areas | TIGER/Line 2022, 2020 Census urban areas, `tl_2022_us_uac20.zip` (`tigris::urban_areas(year = 2022, criteria = "2020")`) | `UACE20`, `geometry` |
| Tracts, counties | TIGER/Line 2022, as the paper | `GEOID`, `geometry` |
| Emissions by road type | CAT `https://api.cat-apps.com/objects/detail/<geoid>.parquet`, rows `by == 15`, `pollutant == 110` | `year`, `geoid`, `pollutant`, `roadtype` (1 to 5), `emissions` |
| County total | CAT `year/<YYYY>.parquet`, `by == 16`, as the paper | `emissions` |

## Mapping

| Class c | CAT `roadtype` | TIGER `MTFCC` | Inside a 2020 urban area |
|---|---|---|---|
| 2 | rural restricted access | S1100 | no |
| 3 | rural unrestricted access | S1200 | no |
| 4 | urban restricted access | S1100 | yes |
| 5 | urban unrestricted access | S1200 | yes |

A road line that crosses an urban-area edge is cut there: the part inside is urban, the part outside is rural.

CAT road type 1 (off-network: starts, idling, parked vehicles) has no road. It is spread over the four classes in
proportion to their on-network emissions, so the county total stays the paper's county total.

## Equations (paper notation, with a road-class index c)

For county j, tract k, group i, class c, with exposure zone Z(j,c) = the 0.3 km buffer around class-c roads in county j:

- **Eq. 2c** `%Area(k,c) = Area(k ∩ Z(j,c)) / Area(k)`
- **Eq. 4c** `Exposed(i,j,k,c) = Pop(i,k) × %Area(k,c)`
- **Eq. 5c** `Exposed(i,j,c) = Σ_k Exposed(i,j,k,c)`
- **Eq. 6c** `Exposed(j,c) = Σ_k Σ_i Exposed(i,j,k,c)`
- **Class weight** `w(j,c) = E15(j,c) / Σ_{c'=2..5} E15(j,c')`, where E15 is the CAT `by = 15` value at the target year
- **Class emissions** `Emissions(j,c) = Emissions(j) × w(j,c)`, where Emissions(j) is the paper's county total (D16)
- **Eq. 7c** `EmissionsRate(j,c) = Emissions(j,c) / Exposed(j,c)`
- **Eq. 8c** `Emissions(i,j) = Σ_c EmissionsRate(j,c) × Exposed(i,j,c)`

By construction `Σ_i Emissions(i,j) = Emissions(j)`. With one class, Eqs. 2c to 8c are the paper's Eqs. 2 to 8.

For an MPO m that holds only part of county j, the rate (Eq. 7c) uses **all** tracts of county j, and Eq. 8c sums
only the tracts in m. The MPO receives the part of the county's emissions that its exposed residents account for.

## Residents inside two classes' buffers

**Choice: count them once in each class (additive).** A person living near both a freeway and an arterial is exposed
to both, and receives both rates.

Why:
- each class's emissions are shared only among the people near that class, so the county total is conserved class by class;
- no arbitrary priority rule ("freeway wins") is needed;
- with one class it reduces exactly to the paper's method, which makes the regression test exact.

Consequence: `Σ_c Exposed(j,c)` is larger than the number of distinct exposed residents. The count of distinct
exposed residents (the union buffer, as in the paper) is still computed and reported, as class `all`.

## Emissions year

D16 rule, per county, pollutant and road type: piecewise linear between the nearest available years 2020 to 2025,
exact where 2022 exists. Only the weights w(j,c) come from the road-type table; the level comes from the county total.

**Warning, measured 2026-11-20 on Albany (36001), PM2.5 tons:**

| Year | rt 2 | rt 3 | rt 4 | rt 5 | rt 1 (off-network) | Total |
|---|---|---|---|---|---|---|
| 2020 | 1.2 | 2.0 | 19.6 | 18.3 | absent | 41.1 |
| 2022 | 9.1 | 10.7 | 9.9 | 14.8 | 10.7 | 55.1 |
| 2025 | 5.6 | 7.0 | 6.5 | 10.1 | 10.0 | 39.2 |

2015 and 2020 look like one kind of run (urban-dominated, no off-network row); the other years look like another
(rural share 36% in Albany, off-network separate). The road-type split is therefore not comparable across years.
Task N-014 audits this for all counties before any number is used, and Tim picks the rule (PLAN question Q1).
The code takes a `share_rule` argument so either rule runs without a rewrite.

## Edge cases

| Case | Rule | Flag |
|---|---|---|
| Emissions in class c, but no exposed residents of class c in the county (no such road in TIGER, or nobody lives near it) | Merge c into a partner class: add its weight to the partner. Partner order: same access, other area type (2↔4, 3↔5); then same area type, other access (2↔3, 4↔5); then the remaining class with the most exposed residents | `merged_<c>_into_<p>` |
| Road of class c exists, CAT emissions for c are zero or missing | Rate is 0. Those residents get nothing from class c; they still count in the union exposed total | `zero_emissions_<c>` |
| No class has any exposed resident (county has no primary or secondary road, or nobody near one) | County is dropped from Eqs. 8 to 9 (its emissions are not allocated) and listed | `no_major_road` |
| No `by = 15` rows for the county at all | Fall back to the paper's single rate for that county | `no_roadtype_data` |

Merging goes across urban and rural first because MTFCC (access type) is reliable, while "urban" differs between the
Census urban areas used here and the highway-agency boundaries behind MOVES.

## Regression test

1. **Collapse.** Run the new functions with every road mapped to one class and w = 1. County-by-group `affected`,
   `emissions_group` and `pop` must equal `get_county_group_values()` on the same exposure table, max absolute
   difference ≤ 1e-9, for all four dimensions, New York, 300 m.
2. **Conservation.** Four classes: `|Σ_i Emissions(i,j) − Emissions(j)| / Emissions(j) ≤ 1e-9` for every county not flagged `no_major_road`.
3. **Fresh roads against cached roads.** The union (`all`) overlap share from the new download against
   `index/test/area_roads300.rds`: report the distribution of differences. Not a 1e-9 test (the cached roads have no
   download date); pass if 99% of tracts are within 0.5 percentage points, otherwise stop and report.

## Limits to state in the paper

- TIGER primary and secondary roads are a small part of the network. CAT's unrestricted road types (3 and 5) include
  every local street. All of that class's emissions are placed on the S1200 roads. The paper already does this for the
  whole county total; the class split makes it more visible.
- Census urban areas are not the highway-agency urban boundaries that MOVES uses.
- Still a proximity screen, not a concentration.

---

## For agents

Implementation contract for N-013. Read `index/functions.R` lines 493-557 (roads, buffers), 687-725
(`get_area_roads`), 775-925 (`get_emissions_interpolated`, `get_county_group_values`) first. Keep every existing
function unchanged; add new ones. R style: tidyverse, native pipe, `=` assignment. Parse check after each edit.

### Functions to add to `index/functions.R`

```r
get_roads_by_class = function(counties, urban_areas, year = 2022, crs = NULL)
# counties: sf with geoid. Downloads prisec roads per state (keep MTFCC), keeps S1100 and S1200,
# clips to counties exactly as get_shapes_roads() does, cuts each line at urban-area edges
# (st_intersection for the urban part, st_difference for the rural part against the county's
# unioned urban polygons), then st_combine per (geoid, class).
# Returns sf: geoid (chr 5), class (chr: "2","3","4","5"), geometry. One row per county and class present.

get_area_roads_by_class = function(tracts, roads_by_class, counties, dist = 300, crs = NULL, cache_dir = NULL)
# For each county: build the buffer per class and the union buffer ("all") with the same steps as
# get_shapes_buffers() (buffer, then clip to the county polygon), intersect with tracts as get_area_roads() does.
# Per-county checkpoint files in cache_dir (skip a county whose file exists).
# Returns tibble (long): geoid (tract, chr 11), geoid_county (chr 5), class (chr: "all","2","3","4","5"),
# area_total (km2), area_roads (km2; 0 when no overlap, never NA).

get_roadtype_weights = function(detail, totals, year = 2022, .pollutant = 110, share_rule = "d16")
# detail: tibble geoid, pollutant, year, roadtype (int 1-5), emissions (by == 15 rows).
# totals: tibble geoid, pollutant, year, emissions (by == 16), as get_emissions_interpolated() takes.
# share_rule "d16": apply get_emissions_interpolated() separately to each roadtype 2-5, then normalise.
# share_rule "anchor:<YYYY>": weights from that single year's rows.
# Roadtype 1 is ignored in the weights. Returns tibble geoid, class (chr), w (sums to 1 per geoid),
# emissions_class = D16 county total × w, rt_flag (chr, NA when clean).

get_county_group_values_roadtype = function(exposure_by_class, census_tracts, class_emissions,
    path_census_counties, vars, pop_var = "pop", id_var = "geoid", id_var2 = "geoid_county",
    unit = NULL, classes = c("2","3","4","5"))
# exposure_by_class: output of get_area_roads_by_class(). class_emissions: output of get_roadtype_weights().
# unit: NULL (whole counties, county populations from path_census_counties, as the paper) or a tibble
# geoid (tract), unit_id; then rows are per (unit_id, geoid_county, group), Eq. 8c sums only the unit's
# tracts, pop and pop_total are tract sums over the unit's tracts, and `emissions` = Σ_group emissions_group
# for that (unit, county) so get_region_group_values() works unchanged.
# Applies the merge rules in the Edge cases table before computing rates.
# Returns the same columns as get_county_group_values() (geoid_county, emissions, emissions_rate,
# affected_total, pop_total, group, affected, emissions_group, pop) plus unit_id and rt_flag.
# `affected` and `affected_total` come from class "all" (distinct exposed residents). emissions_rate is NA.
```

Collapse mode for the regression test: `classes = "all"` with `class_emissions` holding one row per county,
`class = "all"`, `w = 1`.

### Other files (N-013 owns)

- `index/make_roadtype.R`: New York end to end at 300 m. Writes `index/test/roads_by_class.rds`,
  `index/test/area_roads300_by_class.rds`, `index/test/emissions_roadtype.rds` (detail `by == 15` rows, pollutant 110,
  62 counties, 2020-2025), `index/test/roadtype_flags.csv` (geoid, rt_flag, w and exposed per class).
  Detail files are cached under `cache/cat_detail/` (gitignored), never committed.
- `index/tests/test_roadtype.R`: tests 1 to 3 above, plus merge-rule unit tests on a three-tract synthetic fixture
  built inside the test file and marked `# FAKE DATA`.

### Known traps

- `get_county_group_values()` computes `affected_total` over the groups of the dimension passed in `vars`, so the
  rate differs by dimension. Keep that behaviour.
- A county with `affected_total == 0` gives `Inf` and `NaN` in the legacy function and poisons its region. The new
  function must drop and flag it (`no_major_road`), not propagate `NaN`.
- `get_shapes_buffers()` writes to a global `path_shapes_buffers`. Do not call it; reproduce its geometry steps.
- `sf_use_s2()` and the CRS must be the same in the collapse test's two arms.
- CAT year files: `roadtype` 1 is absent in 2015 and 2020 for Albany and present in other years. Never assume five rows.
- Diagnostic to print in `make_roadtype.R`: per county, the largest share of county emissions carried by one tract,
  and any class with fewer than 50 exposed residents. Report, do not alter.

### Acceptance

```bash
Rscript -e 'parse(file="index/functions.R")'
cd index && Rscript make_roadtype.R && Rscript tests/test_roadtype.R && Rscript tests/test_index.R
```

All tests pass; `roadtype_flags.csv` has 62 rows; receipt lists counts per flag and the diagnostic table.
