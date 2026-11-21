---
name: national-rerun
description: Rerun the national MPO analysis after CAT publishes new runs, unblock a blocked_cat MPO, or rebuild the national figure and its uncertainty checks. Use when someone says "rerun national", "new CAT release", "blocked MPOs", "update the ledger", "rebuild Figure 8", or "MPO figure".
---

# Rerun the national MPO analysis

Every MPO has a status in `national/out/<MPO_ID>/status.json`, collected in `national/LEDGER.csv`:
`done`, `single_county` (not part of the analysis), `blocked_cat` (a member county has no 2022 CAT value yet), or
`error`. `run_national.sh` reprocesses only MPOs with no status, an error, or a status from an older CAT manifest.

## Steps

1. Check the key is set without printing it: `[ -n "$CENSUS_API_KEY" ] && echo set`.
2. From the repo root, run the stage:
   ```bash
   bash replicate.sh national       # ledger, per-MPO runs, table, models, tile grid, figure, permutation, ACS intervals
   ```
   Or step by step, in this order (each reads the one before):
   ```bash
   bash national/run_national.sh          # WORKERS=3 by default; do not run two copies at once
   Rscript national/mpo_table.R           # tables/mpo_wide.csv
   Rscript national/models.R              # results_national.json
   Rscript national/tile_grid.R           # tables/mpo_tiles.csv (only if the set of done MPOs changed)
   Rscript national/figures.R             # fig/mpo_national.png
   Rscript national/permutation.R         # results_permutation.json
   Rscript index/make_census_moe.R        # ACS margin-of-error cache for any new state
   Rscript national/acs_intervals.R       # results_acs.json
   ```
3. Then `bash replicate.sh results compare test` so `results/results.json` picks up the new national block.
4. Report: statuses before and after (`national/LEDGER.md`), the manifest, and which `national.*` numbers moved.

## Do not

- Change the figure layout without Tim. It is final: maps on the left with square tiles and state labels, extremes
  plus the on-the-line case labelled, scatters on the right, shared 0.70-1.00 colour scale.
- Add Puerto Rico (excluded) or single-county MPOs (not part of the analysis).
- Edit `national/run_mpo.R` while a run is going: Rscript reads files as it runs, and the edit corrupts the run.
- Store county emissions in `members.csv` (ND21); `run_mpo.R` already drops them.
