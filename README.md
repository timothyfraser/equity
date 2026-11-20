# equity: exposure to transportation emissions across American communities

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![R 4.3+](https://img.shields.io/badge/R-4.3%2B-276DC3?logo=r&logoColor=white)
[![data: CAT public API](https://img.shields.io/badge/data-CAT%20public%20API-0b7285)](https://api.cat-apps.com/objects/LATEST)
![paper: in preparation](https://img.shields.io/badge/paper-in%20preparation-orange)
[![reproducible research](https://img.shields.io/badge/reproducible-research-brightgreen)](https://github.com/timothyfraser/equity)

This repository holds the code that computes **population-adjusted exposure equity indices** for the paper
*Measuring Burden and Disparity of Exposure to Transportation Emissions in American Communities*.
It combines county-level transportation emissions from the Cornell CAT public object store, demographics from the
American Community Survey (ACS), and road-network buffers from TIGER/Line, then summarizes how evenly the burden of
exposure is shared across race and ethnicity, household income, educational attainment, and age.
The worked example in `index/` covers New York State; the code is written to extend to other states.

## Quick links

- Paper: in preparation for submission (no public preprint yet).
- Emissions data: [CAT object store, latest pointer](https://api.cat-apps.com/objects/LATEST) (one parquet file per year, e.g. [2020](https://api.cat-apps.com/objects/year/2020.parquet)). Raw emissions are not stored in this repo; see [`index/test/EMISSIONS_SOURCES.md`](index/test/EMISSIONS_SOURCES.md).
- Pipeline scripts: [`index/`](index/) and its [script table](index/README.md).
- Index method: [`index/functions.R`](index/functions.R).
- Instructions for coding agents: [`CLAUDE.md`](CLAUDE.md).
- Research group: [Gao Labs, Cornell](https://gao.cee.cornell.edu/) and [GitHub organization](https://github.com/Gao-Labs).

## Table of contents

1. [Quick start](#quick-start)
2. [Data sources](#data-sources)
3. [Method summary](#method-summary)
4. [Repository layout](#repository-layout)
5. [National extension](#national-extension)
6. [Uncertainty](#uncertainty)
7. [How to cite](#how-to-cite)
8. [Contributors](#contributors)
9. [Changelog](#changelog)

## Quick start

You need R 4.3 or newer and a free [Census API key](https://api.census.gov/data/key_signup.html).

```bash
bash setup.sh                                   # installs R and every package the code calls (Ubuntu 24.04)
export CENSUS_API_KEY=your-census-api-key-here  # placeholder: paste your own key; never commit it
cd index && Rscript make_emissions.R && Rscript run_ny.R
```

`make_data.R` (census) and `make_shapes.R` (roads, tracts, buffers) are the other two workflow steps; see the
[script table](index/README.md) for the order and what each one writes.

## Data sources

| Data | Source | How the code reads it | Key needed |
|---|---|---|---|
| Transportation emissions, every US county, one file per year | [CAT public object store](https://api.cat-apps.com/objects/LATEST) (`https://api.cat-apps.com/objects/year/<YYYY>.parquet`) | `index/cat_bulk.R`, called by `index/make_emissions.R`; not stored in this repo, rerun `cd index && Rscript make_emissions.R` (manifest `MANIFEST-e2ccfae4.tsv`; CAT is updated over time, so values pulled later may differ slightly from the ones behind the paper) | No |
| Demographics: race and ethnicity, income, education, age | [ACS 5-year, 2022](https://www.census.gov/data/developers/data-sets/acs-5year.html) | [`censusapi`](https://cran.r-project.org/package=censusapi) in `index/make_data.R` | Yes, `CENSUS_API_KEY` environment variable |
| Roads and census tracts | [TIGER/Line](https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html) | [`tigris`](https://cran.r-project.org/package=tigris) in `index/make_shapes.R` | No |

## Method summary

1. **Buffer.** Roads are buffered by **0.3 km (300 m)** to represent the exposure zone around each road.
2. **Area weighting.** Each census tract is intersected with the buffers, and demographic counts are apportioned by the share of tract area that falls inside the buffer.
3. **Emissions weights.** County emissions from CAT are allocated to buffered areas, so that each area carries a share of its county's emissions.
4. **Index.** For each demographic group, the index compares the group's share of emissions exposure with an equal split, and `get_indicator` / `get_overall` in [`index/functions.R`](index/functions.R) summarize it. A value of 1 means the burden is shared evenly across groups; lower values mean it is concentrated on fewer groups. A population-weighted companion measure is also computed (see the [changelog](#changelog)).

The exact definitions live in the code and the paper; this summary is deliberately short.

## Repository layout

| Path | What it is |
|---|---|
| [`index/`](index/) | The pipeline the paper uses: `make_data.R`, `make_shapes.R`, `make_emissions.R`, `run_ny.R`, plus the library `functions.R` and the loader `cat_bulk.R`. |
| [`index/test/`](index/test/) | Derived outputs (rds, figures) written by the pipeline; safe to regenerate. |
| `index/published/` | Local, gitignored snapshot of the as-published outputs; not in the repository. |
| [`demo/`](demo/) | Early prototypes, not used by the paper. |
| [`setup.sh`](setup.sh) | Installs R and the required packages on Ubuntu 24.04. |
| [`CLAUDE.md`](CLAUDE.md) | Instructions for coding agents working in this repository. |
| [`index/api_proxy.sh`](index/api_proxy.sh) | Retired: the old Cloud Run proxy for emissions. Kept for history. |
| [`equity.Rproj`](equity.Rproj) | RStudio project file. |

## National extension

The same equal-group index is also computed for every multi-county metropolitan planning organization (MPO) in the
United States, with a national figure and a regression of the index on emissions rate. See
[`national/README.md`](national/README.md) for what it computes and how to rerun it (`bash national/run_national.sh`
and the steps after it).

## Uncertainty

Two checks sit beside every MPO index. A **permutation test** asks whether the MPO is more uneven than random
allocation of group labels would give, and **ACS intervals** show how much of the index could be sampling error in the
Census estimates. Both are described in [`national/README.md`](national/README.md#uncertainty). To run all tests:

```bash
Rscript index/tests/run_all.R    # every index/tests/test_*.R, one line per file, exits non-zero on any failure
```

## How to cite

If you use this code, please cite:

Fraser, T., Park, Y. G., Li, Y., Tang, Y., & Gao, H. O. *Measuring Burden and Disparity of Exposure to Transportation Emissions in American Communities.* In preparation for submission. Code: https://github.com/timothyfraser/equity

## Contributors

- Timothy Fraser (lead developer)
- Yeonkyeong Gina Park
- Yifei Li
- Yuchen Tang
- H. Oliver Gao

Institution: Gao Labs, Cornell University.

## Changelog

- **2026-11-19**
  - Emissions now come from the public CAT object store through the new loader `index/cat_bulk.R` and the updated `index/make_emissions.R`; the old `api_proxy.sh` workflow is retired.
  - The README now states the 0.3 km buffer used in the paper (it previously said 1 km) and no longer links to a login-gated host.
  - The index normaliser in `index/functions.R` is corrected: the equal-group index uses `n / (2 (n - 1))`. The previous version is kept as `get_index_legacy`, and a population-weighted companion measure is added.
  - Added `setup.sh` and `CLAUDE.md`.

License: [MIT](LICENSE).
