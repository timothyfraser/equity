# National extension: state and handoff (2026-11-20, updated after CAT manifest MANIFEST-59ea1fac)

## Done
- National run, ledger-driven (`bash national/run_national.sh`), rerun under `MANIFEST-59ea1fac.tsv`: 411 MPOs; 224 done, 186 single-county, 1 blocked (Puerto Rico, no CAT data, out of scope). The 37 counties with only a 2020 run now have 2022 runs. `national/LEDGER.md`.
- Replication data rule (ND21, R-1): no raw CAT emissions in git; MPO totals in `national/out/*/indices.csv`; query URLs and manifest in `index/test/EMISSIONS_SOURCES.md` and the README.
- National figure `national/fig/mpo_national.png` (V-1..V-4, ND15-ND20): cohesive US tile maps of the race and income indices, and each index against emissions per resident with the OLS fit. Numbers from `national/results_national.json`. Tile layout in `national/tables/mpo_tiles.csv` (receipts V-2, V-2b, V-2c).
- Models (224 MPOs, classical OLS, reported as 95% CI per Tim): race β = -0.049 (95% CI -0.065 to -0.034, p < 0.001); income β = -0.010 (-0.019 to -0.0003, p = 0.044; HC3 p = 0.10, state-clustered p = 0.19); overall β = -0.018 (-0.025 to -0.010). All in `results_national.json`.

## In progress / blocked
- CAT runs: 38 of the 61 ordered counties are published in `MANIFEST-59ea1fac.tsv` (all 37 MPO-related counties + Kings 36047). 23 New York counties are still missing from `year/2022.parquet`: 36019 36025 36027 36031 36033 36039 36041 36053 36057 36059 36063 36069 36075 36077 36081 36083 36087 36091 36093 36105 36111 36113 36121. Ask Tim's CAT session whether those runs failed or are still publishing.
- The New York paper is NOT rebuilt yet (waits for the 23 counties). Exact next step once they publish: `bash national/run_national.sh`, then `Rscript national/mpo_table.R && Rscript national/models.R && Rscript national/tile_grid.R && Rscript national/figures.R`; for New York, `cd index && Rscript make_emissions.R && Rscript run_ny.R && Rscript make_results.R && Rscript make_diff.R`, then the paper re-render preview (`paper_equity/.contract/r0/preview/rerender.py`) for Tim's approval.
- Paper section "Scaling up" (V-6, ND22): after the CAT runs. Needs `results_national.json` merged into the paper's `results.json` (`national` key) so the text can use placeholders.

## Decisions and why
- Tile grid: one monotone warp applied to both the US outline and the MPO centroids, so the dense East gets more cells (w = 0.70). A state penalty raised state containment from 21% to 44% but moved the NYC metro tile into New England, so it is off (V-2c receipt).
- `index/test/emissions.rds` (old legacy-proxy file) cannot be reproduced exactly; only an exploratory `glimpse()` reads it; the bulk-loader version replaces it.

## Needs Tim
- Q4: the small-group chance check (V-5), explained in plain terms in the session summary.
- Whether the figure should report the classical SE (now) or a robust SE (income's significance depends on it).

- 2026-11-20 fixes: parallel workers corrupted a shared CAT year file on the first rerun; `run_national.sh` now prefetches the year files before workers start, and `cat_bulk.R` downloads atomically. `models.R` takes the manifest from `done` MPOs only (single-county MPOs keep their first-run manifest).
- V-5 (random-allocation benchmark) is specified exactly in `PLAN_VIZ_AND_CAT.md` R2.2; not started, waiting on Tim.
