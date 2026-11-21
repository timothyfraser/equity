# index: the New York analysis and the index library

This folder holds the code the paper's New York results come from. To run it, use
[`../replicate.sh`](../replicate.sh) from the repo root; the full guide is
[`../docs/REPLICATION.md`](../docs/REPLICATION.md). To run a script by hand, `cd index` first: the scripts here read
and write paths relative to this folder.

## Scripts, in the order they run

| Script | Stage | What it does | Writes |
|---|---|---|---|
| [`make_census.R`](make_census.R) | census (optional) | Rebuilds the ACS 2022 5-year tract and county caches. Needs `CENSUS_API_KEY`. Refuses to overwrite if an existing column would change. | `test/census_tracts.rds`, `test/census_counties.rds` |
| [`make_census_moe.R`](make_census_moe.R) | national | Pulls ACS estimates and margins of error for the interval check. Needs `CENSUS_API_KEY`. New York's copy ships in `test/census_moe/`. | `cache/national/census_moe/<state>.rds` |
| [`make_shapes.R`](make_shapes.R) | (cached) | Builds TIGER roads, tracts, and road buffers at 100-2000 m. Its outputs are in git. | `test/shapes_*.rds`, `test/area_roads*.rds` |
| [`make_emissions.R`](make_emissions.R) | ny | Pulls CAT county emissions for 2020-2025 and records the manifest. Raw emissions are gitignored. | `test/emissions_*.rds`, `test/emissions_provenance.txt` |
| [`run_ny.R`](run_ny.R) | ny | Computes the indices for the 10 regions and draws every New York figure, including the distance and pollutant sensitivity grid. | `test/stat_*.rds`, `test/*.png` |
| [`runs/uncertainty/ny_permutation.R`](runs/uncertainty/ny_permutation.R) | uncertainty | Exact permutation test, 10 regions x 4 dimensions, B = 1,000. | `runs/uncertainty/ny_permutation.csv` |
| [`runs/uncertainty/ny_acs_intervals.R`](runs/uncertainty/ny_acs_intervals.R) | uncertainty | ACS margin-of-error intervals, B = 500. | `runs/uncertainty/ny_acs_intervals.csv` |
| [`make_results.R`](make_results.R) | results | Recomputes every number in the paper under each emissions variant and writes them with their evidence. | `../results/results.json`, `runs/<variant>/`, `runs/summary_numbers.rds` |

## Libraries (sourced, not run)

| File | What it holds |
|---|---|
| [`functions.R`](functions.R) | The index (`get_index()`, `get_indicator()`, `get_overall()`), data retrieval, geometry, and plotting functions. Superseded versions keep a `_legacy` suffix (for example `get_index_legacy()`, the 2025 normaliser). |
| [`cat_bulk.R`](cat_bulk.R) | Reads CAT's public Parquet objects and the current manifest. |
| [`uncertainty_core.R`](uncertainty_core.R) | The index as a matrix calculation on tract-by-group counts, shared by both uncertainty checks. |
| [`uncertainty_permutation.R`](uncertainty_permutation.R) | The permutation test (fixed-margin tables via `r2dtable`, Patefield 1981). |
| [`uncertainty_acs.R`](uncertainty_acs.R) | The ACS margin-of-error draws. |

## Emissions variants in `runs/`

The paper reports `variant_A` (`rerun` in `results.json`): the corrected index with 2022 emissions, interpolated per
county between the nearest CAT years where a county has no 2022 run. The others are checks: `variant_A_endpoints`
(a straight line between 2020 and 2025 only), `variant_A_race10` (the 2025 paper's ten race groups), `variant_B`
and `variant_C` (exact 2020 and 2025 emissions), and `variant_D` (exact 2022 emissions, only the counties that have
them). `fix_only` is an author-only audit; see [`make_results.R`](make_results.R).

## Tests

```bash
Rscript index/tests/run_all.R     # from the repo root: every tests/test_*.R in its own process; exits 1 on any failure
```

| Test file | What it checks |
|---|---|
| [`tests/test_index.R`](tests/test_index.R) | The index normaliser, groups with no members, and the companion scores, on hand-computed cases. |
| [`tests/test_uncertainty_core.R`](tests/test_uncertainty_core.R) | The matrix version of the index equals the paper's values for New York regions and national MPOs. |
| [`tests/test_uncertainty_permutation.R`](tests/test_uncertainty_permutation.R) | Margins are preserved; a fully mixed unit scores 1 and a fully segregated unit hits the smallest possible p-value. |
| [`tests/test_uncertainty_acs.R`](tests/test_uncertainty_acs.R) | With zero margins of error every draw equals the observed index; zero cells stay zero; seeds reproduce. |

## Author-only scripts

These compare the revision with the 2025 version of the paper. They need the private manuscript repository and the
gitignored snapshot `published/`, so they are not part of the replication.

| Script | What it does |
|---|---|
| [`make_diff.R`](make_diff.R) | Writes a before/after table of the paper's numbers (`RERUN_DIFF.md`) from `runs/summary_numbers.rds`. |
| [`make_compare.py`](make_compare.py) | Pairs each 2025 figure with its rerun for side-by-side review. |
| [`api_proxy.sh`](api_proxy.sh) | Retired. The old Cloud Run proxy for emissions, replaced by the CAT public object store. |
