# national: the equal-group index for every multi-county MPO

This folder extends the New York worked example in [`index/`](../index/) to the whole country, one metropolitan
planning organization at a time.

## What it computes

An **MPO (metropolitan planning organization)** is the federally designated body that plans transportation for a
metropolitan area. Many MPOs span several counties, and sometimes several states. For every MPO that covers more than
one county, this code computes the same equal-group index as the paper (1 means the burden of transportation
emissions is shared evenly across groups, lower values mean it is concentrated) for race and ethnicity, income,
education, and age, plus an overall score and a population-weighted companion for race and income.

- **Boundaries.** MPO boundaries and IDs come from the Bureau of Transportation Statistics (BTS) National Transportation
  Atlas Database (NTAD) layer "Metropolitan Planning Organizations". The layer URL is `NTAD_MPO_URL` in
  [`pilot/pilot_functions.R`](pilot/pilot_functions.R); the list of 411 MPOs is written to [`mpo_list.csv`](mpo_list.csv).
- **Emissions.** County emissions come from the public CAT object store (no key). See [Data rule](#data-rule).
- **Demographics.** ACS 5-year 2022 tracts, as in `index/`.

## The ledger

Every MPO gets a status in `national/out/<MPO_ID>/status.json`. [`LEDGER.csv`](LEDGER.csv) and
[`LEDGER.md`](LEDGER.md) collect them.

| Status | Meaning |
|---|---|
| `done` | index computed |
| `single_county` | all tracts in one county; not part of the national analysis |
| `blocked_cat` | a member county has no CAT value for 2022 yet; picked up automatically on a later rerun |
| `error` | anything else; message in `status.json`; retried on the next run |

An MPO is recomputed only if it has no status, errored, or was `done`/`blocked_cat` under an older CAT manifest.

## Rerun everything after a new CAT release

From the repo root, in this order (each step reads the previous one's output):

```bash
bash national/run_national.sh        # ledger + one run per MPO that needs it (3 workers; WORKERS=n to change)
Rscript national/mpo_table.R         # wide table, one row per done MPO
Rscript national/models.R            # index ~ log(emissions rate) across MPOs
Rscript national/tile_grid.R         # tile map layout
Rscript national/figures.R           # four-panel national figure
Rscript national/permutation.R       # permutation test
Rscript national/acs_intervals.R     # ACS intervals
```

Rough runtimes, from the receipts in `.contract/national/receipts/`:

| Step | Time |
|---|---|
| `run_national.sh` | not timed for a full first run; reruns only touch MPOs that changed, downloads are cached |
| `mpo_table.R`, `models.R`, `figures.R` | not timed; short table and plotting steps |
| `tile_grid.R` | about 110 s |
| `permutation.R` | 3.4 min (896 jobs, 3 workers, B = 1000) |
| `acs_intervals.R` | about 2.5 min (896 jobs, 3 workers, B = 500) |

## Outputs

| File | What it is |
|---|---|
| `mpo_list.csv` | the 411 MPOs from BTS NTAD |
| `out/<MPO_ID>/` | per-MPO `status.json`, `indices.csv`, `checks.csv`, `members.csv`, `timing.csv` |
| `LEDGER.csv`, `LEDGER.md` | status of every MPO |
| `index_mpo.csv` | all `done` MPO indices stacked (from `ledger.R build`) |
| `tables/mpo_wide.csv` | one row per `done` MPO: indices, population, emissions rate |
| `results_national.json` | regression results and extreme MPOs (every value carries its evidence) |
| `tables/mpo_tiles.csv`, `fig/tile_grid_check.png` | tile positions and the layout check |
| `fig/mpo_national.png` | the national figure |
| `tables/mpo_permutation.csv`, `results_permutation.json` | permutation test results |
| `tables/mpo_acs_intervals.csv`, `results_acs.json` | ACS intervals |
| `logs/` | one log per MPO run |

## Uncertainty

**Permutation test.** For each MPO and dimension we ask whether the MPO is more uneven than chance. We shuffle group
labels among residents while keeping each tract's population and each group's total fixed, rescore the index 1000 times,
and report `p0`, the share of shuffled worlds at least as uneven as observed. We also report a chance-adjusted index.
These are raw p-values with no multiplicity adjustment. Code: [`../index/uncertainty_permutation.R`](../index/uncertainty_permutation.R).

**ACS intervals.** ACS counts are estimates with published margins of error. We redraw every cell from its own error
distribution 500 times (zero cells stay zero), rebuild the group table, and rescore the index; the 2.5th and 97.5th
percentiles are the 95% interval. Cells are drawn independently, so intervals understate the true uncertainty,
most for the rarest groups. Code: [`../index/uncertainty_acs.R`](../index/uncertainty_acs.R).

Tests for both: `Rscript index/tests/run_all.R`.

## Data rule

No raw CAT emissions are stored in this repo; anyone can pull them without a key. Each `indices.csv` keeps only the MPO
totals (`emissions_mpo`, `emissions_rate_mpo`). URLs and the manifest are in
[`../index/test/EMISSIONS_SOURCES.md`](../index/test/EMISSIONS_SOURCES.md). CAT is updated over time, so values pulled
later may differ slightly from the ones behind the paper.

---

## For agents

- Run everything from the repo root (or through `bash replicate.sh national`). Scripts find the repo root from
  `EQUITY_ROOT` if set, otherwise from the working directory.
- `run_national.sh` is idempotent and prefetches CAT year files before starting parallel workers (concurrent first downloads
  once corrupted a file). Do not run several copies at once.
- Order matters: `mpo_table.R` writes `tables/mpo_wide.csv`; `models.R`, `tile_grid.R`, `figures.R`, `permutation.R` and
  `acs_intervals.R` all read it, and `figures.R` also needs `results_national.json` and `tables/mpo_tiles.csv`.
- Every number in the `results_*.json` files is computed by the script that writes it, never typed. Keep it that way.
- Seeds depend only on MPO id and dimension (`unit_seed`, `acs_seed`), so results do not depend on worker count.
- Do not store raw CAT emissions. Do not edit `index/tests/` to make a failure pass.
- Plan and decisions: `.contract/national/PLAN_SCALING_UP.md`, `.contract/national/STATE.md`.
