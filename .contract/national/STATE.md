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

## Update: Scaling up (2026-11-20, PLAN_SCALING_UP.md)

Done:
- U-0 shared matrix estimator `index/uncertainty_core.R` (reproduces indicator2 / indicator_pw to 1e-10; 0.9 ms per call on NYMTC).
- U-1 exact permutation test (fixed-margin `r2dtable`, B = 1,000): race 222 of 224 MPOs have p0 < 0.05 (raw, ND31); income 224, edu 223, age 222. Least even MPO (Staunton-Augusta-Waynesboro, VA): observed 0.708 vs chance expectation 0.959. Size gradient persists after the chance adjustment (Spearman with log pop 0.588 for I, 0.463 for I*). New York: every region p0 = 0.001 (the floor).
- U-2 ACS intervals (B = 500, zero cells held at 0): median 95% widths race 0.060, income 0.019, edu 0.019, age 0.013; widths shrink with population.
- U-3 paper `results.json` gains `national.*`, `robustness.permutation.*`, `robustness.acs_interval.*`; every older key byte-identical.
- U-4 figure: maps side by side with square tiles and a state label on every tile; extremes labelled above/below; scatters on their own y-range with β and 95% CI.
- U-6 `national/README.md`, root README sections, `index/tests/run_all.R` (4 files, 123 checks, 0 failures).

Waiting on Tim:
- T-014 preview (`paper_equity/.contract/r0/build/T-014_changes_yellow.pdf`). On approval: `python3 -I .contract/r0/preview/apply_t014.py --target` in paper_equity, copy `equity/national/fig/mpo_national.png` to `paper_equity/fig/`, recompile.
- Open points: "emissions term cancels" wording for single-county MPOs; p and CI number format (renderer prints p = 0.0443 and -0.000254; Tim's rule is three decimals); Methods subsubsection is 448 words and carries the New York findings (move to Results?); two TODO citations (BTS NTAD MPO layer; Carrington and Troske 1997); three contract paths to add (total MPOs 411, permutation B, ACS B).
- 23 New York counties still missing from CAT 2022: the New York rebuild waits; all scripts rerun.

## Update 2026-11-21: Scaling up applied

Done (receipts W-1..W-3):
- Results contract: on-the-line MPO per map (race: Traverse Transportation Coordinating Initiative, MI, 0.905; income: Lake-Sumter MPO, FL, 0.951), state names, counts below 0.95 / 0.90, total MPOs (411), draw counts.
- Figure: maps left (square tiles, state labels, extremes solid, on-the-line dashed), scatters right (on-the-line as a diamond), β with 95% CI.
- Paper (paper_equity commit 1a39f70): Methods subsubsection "Scaling Up to Metropolitan Planning Organizations" (methods only); Results subsection "Scaling Up" after the national figure (results only); two sentences in the New York race paragraph (p0 = 0.001 for every region and dimension; Mohawk Valley 0.854 vs a chance expectation of 0.985, ACS range 0.813-0.884); availability sentence. Three verified citations. Renderer prints three decimals (ND41); the only already-applied number that changed is the Long Island income slope (-0.000181 -> -0.0002). Compiles: 0 errors, 0 undefined citations, 32 pages.

Blocked:
- New York exact 2022 (measured 2026-11-21, MANIFEST-6b77a4af): none of the 23 ordered NY counties has a 2022 run in `detail/<geoid>.parquet` or `year/2022.parquet`; 12 have a new 2023 run; 11 have neither. Check: `curl -s https://api.cat-apps.com/objects/detail/36019.parquet -o x.parquet` then list `unique(year)` (2020 and 2023 present, 2022 absent).
- Exact next step once they publish: `cd index && Rscript make_emissions.R && Rscript run_ny.R && Rscript make_results.R && Rscript make_diff.R`; `Rscript runs/uncertainty/ny_permutation.R && Rscript runs/uncertainty/ny_acs_intervals.R`; rerun make_results.R; then in paper_equity `python3 -I .contract/r0/preview/rerender.py` (preview), Tim approves, `--target`. Note: the paper's NY numbers use emissions from MANIFEST-e2ccfae4 cached in index/test; `make_emissions.R` will pull the current manifest (which now also has the 12 new 2023 runs), so NY numbers will move slightly even before 2022 lands.

- 2026-11-21: Methods subsubsection rewritten in plain language per Tim (T-015, paper commit f58f65a): 534 -> 443 words, Connecticut sentence dropped, chance-adjusted index in words with the formula in parentheses. Manuscript compiles: 0 errors, 0 undefined citations, 33 pages.
