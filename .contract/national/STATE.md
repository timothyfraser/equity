# National extension: state and handoff (2026-11-20)

## Done
- National run, ledger-driven (`bash national/run_national.sh`): 411 MPOs; 220 done, 186 single-county, 5 blocked on CAT (El Paso, Richmond, Tri Cities, Hampton Roads, Puerto Rico). `national/LEDGER.md`.
- Replication data rule (ND21, R-1): no raw CAT emissions in git; MPO totals in `national/out/*/indices.csv`; query URLs and manifest in `index/test/EMISSIONS_SOURCES.md` and the README.
- National figure `national/fig/mpo_national.png` (V-1..V-4, ND15-ND20): cohesive US tile maps of the race and income indices, and each index against emissions per resident with the OLS fit. Numbers from `national/results_national.json`. Tile layout in `national/tables/mpo_tiles.csv` (receipts V-2, V-2b, V-2c).
- Models: race β = -0.049 (SE 0.008, p < 0.001); income β = -0.011 (SE 0.005, p = 0.022), which is not significant with HC3 (p = 0.065) or state-clustered SEs (p = 0.117). All in `results_national.json`.

## In progress / blocked
- CAT runs: 61 counties (ND23), placed by Tim's local CAT session from `.contract/national/CAT_ORDERS_HANDOFF.md`. This session cannot reach that session (peer messaging only sees sessions on the same machine) and has no CAT sign-in token.
- Exact next step once CAT publishes a new manifest: `bash national/run_national.sh`, then `Rscript national/mpo_table.R && Rscript national/models.R && Rscript national/tile_grid.R && Rscript national/figures.R`; for New York, `cd index && Rscript make_emissions.R && Rscript run_ny.R && Rscript make_results.R && Rscript make_diff.R`, then the paper re-render preview (`paper_equity/.contract/r0/preview/rerender.py`) for Tim's approval.
- Paper section "Scaling up" (V-6, ND22): after the CAT runs. Needs `results_national.json` merged into the paper's `results.json` (`national` key) so the text can use placeholders.

## Decisions and why
- Tile grid: one monotone warp applied to both the US outline and the MPO centroids, so the dense East gets more cells (w = 0.70). A state penalty raised state containment from 21% to 44% but moved the NYC metro tile into New England, so it is off (V-2c receipt).
- `index/test/emissions.rds` (old legacy-proxy file) cannot be reproduced exactly; only an exploratory `glimpse()` reads it; the bulk-loader version replaces it.

## Needs Tim
- Q4: the small-group chance check (V-5), explained in plain terms in the session summary.
- Whether the figure should report the classical SE (now) or a robust SE (income's significance depends on it).
