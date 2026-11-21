# Replication guide

This guide takes you from a fresh clone to the paper's numbers and figures, and tells you how to check that what you
got matches what we report. The short version is in the [README](../README.md#replicate-the-paper-in-three-commands).

## Contents

1. [Requirements](#requirements)
2. [Run it](#run-it)
3. [Runtimes](#runtimes)
4. [Check your numbers against ours](#check-your-numbers-against-ours)
5. [What each stage reads and writes](#what-each-stage-reads-and-writes)
6. [The national stage](#the-national-stage)
7. [What is not in the repository, and why](#what-is-not-in-the-repository-and-why)
8. [Troubleshooting](#troubleshooting)

## Requirements

- **R 4.3 or newer.** The results were built with R 4.3.3 on Ubuntu 24.04; every package version is in
  [`sessionInfo.txt`](sessionInfo.txt).
- **Ubuntu 24.04:** `bash setup.sh` installs R, the system libraries, and every package.
- **macOS:** install a current R (4.5 or newer) from CRAN, then the spatial libraries and packages. Current CRAN
  releases of some dependencies (`Deriv`, pulled in by `ggpubr`) no longer install on R 4.3; Ubuntu's `setup.sh`
  avoids this by taking those packages from apt.
  ```bash
  brew install gdal geos proj udunits
  Rscript -e 'install.packages(c("sf", "dplyr", "tidyr", "purrr", "readr", "stringr", "ggplot2", "viridis",
    "jsonlite", "httr", "broom", "ggpubr", "scales", "gtools", "progress", "nanoparquet", "ggtext", "shadowtext",
    "ggspatial", "censusapi", "tigris", "patchwork", "ragg", "clue", "lmtest", "sandwich"))'
  ```
- **Windows:** use WSL with Ubuntu 24.04. The uncertainty and national stages use `parallel::mclapply`, which does not
  fork on native Windows.
- **Network access** to `api.cat-apps.com` only with `EMISSIONS=live` and for the national stage, which also reaches
  the Census API and TIGER/Line. The default New York run reads its emissions from the repo.
- **A Census API key only for the national stage** (or to rebuild the New York Census caches). Get one free at
  <https://api.census.gov/data/key_signup.html> and `export CENSUS_API_KEY=...` in your shell. Never write it to a
  file in the repository.
- **Disk:** about 150 MB for the clone and the New York analysis; about 1 GB of caches for the national stage.

## Run it

```bash
git clone https://github.com/timothyfraser/equity && cd equity
bash setup.sh
bash replicate.sh                 # ny uncertainty results compare test
bash scripts/check.sh             # optional: repository checks (parsing, links, JSON, secrets, tests)
```

`replicate.sh` runs in stages. Run any of them by name (`bash replicate.sh ny`, `bash replicate.sh results compare`),
in an order that respects their inputs. With no arguments it runs `ny uncertainty results compare test`;
`bash replicate.sh all` adds `national`.

| Stage | What it does | Key needed |
|---|---|---|
| `ny` | Loads the paper's frozen New York emissions (`EMISSIONS=live` pulls the latest from CAT), computes the New York indices, draws the New York figures | no |
| `uncertainty` | Permutation test and ACS margin-of-error intervals for New York | no |
| `national` | Every MPO in the BTS layer (411: 224 computed, 186 single-county, 1 in Puerto Rico, excluded): ledger, indices, models, national figure, uncertainty | yes |
| `results` | Writes [`results/results.json`](../results/results.json) | no |
| `compare` | Compares your `results.json` with the paper's, number by number | no |
| `test` | Unit tests for the index and the uncertainty code | no |
| `census` | Optional: rebuilds the New York ACS caches | yes |

`replicate.sh` overwrites the paper's tracked outputs (figures in `index/test/`, `results/results.json`) with yours,
so `git diff` shows exactly what changed. Your `results.json` will also lack the author-only audit (the `published`
and `fix_only` variants and `_meta.checks`), because it needs the private manuscript repository; that shows up in
`git diff` as deletions and in `compare` as numbers "only in the paper's file". To restore the paper's copies:
`git checkout -- index/test index/runs results national`.

## Runtimes

Measured on a fresh clone, 4 vCPU cloud machine, November 2026, except the national first run, which is an estimate:

| Stage | Time |
|---|---|
| `ny` | about 65 s |
| `uncertainty` | about 45 s (3 cores) |
| `results` | about 7 s |
| `compare` | under 1 s |
| `test` | about 6 s |
| `national`, first run | estimated 1 to 3 hours of downloads and geometry (the pilot measured 4-12 s per member county; the 224 MPOs have 804 member counties), then about 6 minutes, measured, for the two uncertainty checks with 3 workers |
| `national`, rerun | minutes: only MPOs that changed are recomputed |

## Check your numbers against ours

`bash replicate.sh compare` reads the paper's `results/results.json` as committed and your freshly written copy, and
compares every number the two share at three decimals, the precision the paper prints. It reports matches by block,
the largest differences, and the CAT manifest behind each file.

**On the default settings your New York numbers match ours exactly.** The paper's New York emissions (CAT
`MANIFEST-e2ccfae4`) are frozen in [`index/data/cat_MANIFEST-e2ccfae4/`](../index/data/cat_MANIFEST-e2ccfae4/), with
checksums, and the `ny` stage loads them. A fresh clone on 21 November 2026 matched all 2,383 numbers, and every
figure and intermediate file came out byte-identical to the committed copies.

**`EMISSIONS=live bash replicate.sh` pulls the latest CAT release instead.** CAT is a live database: the year files at
`https://api.cat-apps.com/objects/year/<YYYY>.parquet` always serve the latest release, and old releases are not
kept. Expect differences, which `compare` reports with the manifest behind each file. On 21 November 2026, while CAT
was publishing new 2022 runs for New York counties, live reruns moved up to 7 of the 50 headline Table 2 values in
the third decimal (largest change 0.0015), and later more (the ANOVA F for education across regions went from 8.15
to 6.65). Most differences were in the `exact_2022_38` check, which uses only counties with exact 2022 runs.

`compare` is a report, not a test: it always exits 0. The CI badge on the README therefore means "the code runs from
a clean checkout and the unit tests pass", not "the numbers equal the paper's".

The national results (`national.*`) are not recomputed by the default stages. They come from the committed per-MPO
outputs in `national/out/`, built on `MANIFEST-59ea1fac`. They match exactly unless you run the national stage. The
MPO boundaries come from a live BTS service; the 411 MPO IDs and names we used are in `national/mpo_list.csv`, but the
boundary polygons are not archived.

## What each stage reads and writes

| Stage | Reads | Writes |
|---|---|---|
| `census` | Census API | `index/test/census_tracts.rds`, `census_counties.rds` (refuses to change existing columns) |
| `ny` | `index/data/cat_MANIFEST-e2ccfae4/` (or the CAT year files with `EMISSIONS=live`); `index/test/census_*.rds`, `shapes_*.rds`, `area_roads*.rds`; `index/data/regions_ny_data.rds` | `index/test/emissions_*` (gitignored), `emissions_provenance.txt`, `stat_*.rds`, every New York figure |
| `uncertainty` | the `ny` outputs; `index/test/census_moe/36.rds` | `index/runs/uncertainty/ny_permutation.csv`, `ny_acs_intervals.csv` |
| `national` | BTS MPO layer, CAT, Census API, TIGER/Line | `national/out/<MPO>/`, `LEDGER.*`, `tables/`, `fig/mpo_national.png`, `results_*.json` |
| `results` | all of the above | `results/results.json`, `index/runs/<variant>/`, `index/runs/summary_numbers.rds` |
| `compare` | `results/results.json` at HEAD and in your working tree | the terminal only |
| `test` | `index/tests/`, plus the caches above when present | the terminal only |

The figure-by-figure map is in the [README](../README.md#what-each-figure-and-table-comes-from).

## The national stage

```bash
export CENSUS_API_KEY=...        # your own key
bash replicate.sh national results compare
```

The stage keeps a ledger: every MPO gets a status in `national/out/<MPO_ID>/status.json` (`done`, `single_county`,
`blocked_cat`, or `error`), collected in [`national/LEDGER.md`](../national/LEDGER.md). Reruns are idempotent: an MPO
is recomputed only if it has no status, errored, or was computed under an older CAT manifest. When CAT publishes runs
for a county that blocked an MPO, the next rerun picks it up. Details: [`national/README.md`](../national/README.md).

## What is not in the repository, and why

| Not stored | Why | How the code gets it |
|---|---|---|
| National county emissions | Public, keyless, and large; storing a copy would fork the source of truth (ND21). New York's are the exception (ND46): 85 KB, frozen so the paper reproduces exactly | Pulled from CAT at run time; the manifest is recorded |
| National Census and geometry caches (`index/cache/`) | About 1 GB, and fully reproducible | Rebuilt by the national stage |
| The 2025 paper's full outputs (`index/published/`) | They hold raw emissions | Region-level copies used by the tests are in `index/tests/fixtures/published_2025/` |
| The manuscript | Under review | The paper's numbers are in `results/results.json` |

Tests that need a cache a fresh clone does not have print `SKIP` with the stage that creates it, rather than failing.
After `bash replicate.sh`, only the national-cache checks are skipped.

## Troubleshooting

- **`tigris` fails with an unused `progress_bar` argument or a `curl_parse_url` error.** Your `httr2` or `curl` is too
  old. `setup.sh` upgrades them. Elsewhere: `install.packages(c("curl", "httr2"))`.
- **`census: CENSUS_API_KEY is not set`.** Only the `census` and `national` stages need it.
- **A stage dies partway through the national run.** Rerun it. Downloads are atomic and the ledger skips finished
  MPOs. Do not run two copies of `run_national.sh` at once: they share download caches.
- **`compare` shows differences.** Read the two manifests it prints first (see
  [above](#check-your-numbers-against-ours)).
