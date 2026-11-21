# equity: who lives next to the road, and who carries its emissions burden?

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![R 4.3+](https://img.shields.io/badge/R-4.3%2B-276DC3?logo=r&logoColor=white)
[![data: CAT public objects](https://img.shields.io/badge/data-CAT%20public%20objects-0b7285)](https://api.cat-apps.com/objects/LATEST)
[![checks](https://github.com/timothyfraser/equity/actions/workflows/check.yml/badge.svg)](https://github.com/timothyfraser/equity/actions/workflows/check.yml)

Replication code for **Fraser, T., Park, Y. G., Li, Y., Tang, Y., & Gao, H. O. *Measuring Burden and Disparity of
Exposure to Transportation Emissions in American Communities*** (submitted to the *Journal of Transport Geography*).

When a region's on-road emissions concentrate along its major roads, which groups of people live next to those roads?
This repository builds a **population-adjusted equity index** that answers that question for any group of counties.
It scores how evenly the near-road burden of transportation PM<sub>2.5</sub> falls across race and ethnicity
(14 groups), household income, educational attainment, and age, from 0 (all burden on one group) to 1 (perfectly even).
The paper applies it to all 62 counties of New York State in 2022, grouped into 10 economic development regions, and
then to the 224 multi-county metropolitan planning organizations (MPOs) in the United States that CAT covers. The
index allocates each county's emissions to the people living near its roads; it does not model dispersion.

Everything runs on public data. No raw emissions are stored here: the code pulls them from the Cornell CAT public
object store at run time, and every number the paper prints is written by code to
[`results/results.json`](results/results.json).

## Contents

1. [Replicate the paper in three commands](#replicate-the-paper-in-three-commands)
2. [What each figure and table comes from](#what-each-figure-and-table-comes-from)
3. [The method in one page](#the-method-in-one-page)
4. [Data sources](#data-sources)
5. [Repository layout](#repository-layout)
6. [How this code was built and checked](#how-this-code-was-built-and-checked)
7. [How to cite](#how-to-cite)

## Replicate the paper in three commands

You need R 4.3 or newer on Linux or macOS (tested on Ubuntu 24.04, R 4.3.3; full package versions in
[`docs/sessionInfo.txt`](docs/sessionInfo.txt)). The New York analysis needs no API key: the Census data it uses are
cached in [`index/test/`](index/test/). Only the national stage pulls new Census data.

```bash
git clone https://github.com/timothyfraser/equity && cd equity
bash setup.sh          # Ubuntu 24.04: installs R and every package the code calls (macOS: see docs/REPLICATION.md)
bash replicate.sh      # New York analysis, uncertainty checks, results.json, and the tests
```

`replicate.sh` runs in stages, so you can rerun one piece at a time:

| Stage | Command | What it does | Time |
|---|---|---|---|
| `ny` | `bash replicate.sh ny` | Pulls CAT emissions, computes the New York indices, draws the New York figures | about 65 s |
| `uncertainty` | `bash replicate.sh uncertainty` | Permutation test and ACS margin-of-error intervals for New York | about 45 s |
| `national` | `bash replicate.sh national` | Every MPO in the BTS layer (411: 224 computed, 186 single-county, 1 in Puerto Rico, excluded): ledger, indices, models, national figure, uncertainty. Needs a free [Census API key](https://api.census.gov/data/key_signup.html) | estimated 1-3 h on a first run; minutes after |
| `results` | `bash replicate.sh results` | Writes [`results/results.json`](results/results.json) | about 10 s |
| `compare` | `bash replicate.sh compare` | Compares your `results.json` with the paper's, number by number | seconds |
| `test` | `bash replicate.sh test` | Unit tests for the index and the uncertainty code | about 5 s |
| `census` | `bash replicate.sh census` | Optional: rebuilds the New York ACS caches (needs the key) | a few min |

`bash replicate.sh` with no arguments runs `ny uncertainty results compare test`; `bash replicate.sh all` adds `national`.
The full guide, with expected outputs and how to check your numbers against ours, is
[`docs/REPLICATION.md`](docs/REPLICATION.md).

**One caveat.** CAT is a live database that is updated as new model runs are published. If you rerun later, CAT may
serve slightly different emissions than the ones behind the paper. The manifest we used is recorded in
[`index/test/emissions_provenance.txt`](index/test/emissions_provenance.txt) and in `results.json`, and the
`compare` stage reports, number by number, how your rerun differs from the paper and which CAT release each came from.
CAT does not keep the bytes of old releases, so a rerun today cannot recover the paper's exact New York inputs; the
paper's New York numbers use `MANIFEST-e2ccfae4` and its national numbers `MANIFEST-59ea1fac`. The national results
are rebuilt only when you run the `national` stage.

## What each figure and table comes from

| In the paper | File | Made by | Numbers in `results.json` |
|---|---|---|---|
| Figure 1, research design flowchart | drawn by hand | none | none |
| Figure 2, step-by-step index calculation | drawn by hand | none | none |
| Figure 3, Albany County roads and exposure zones | `index/test/map.png` | `index/run_ny.R` | none |
| Figure 4, regional variation in equity | `index/test/lines_overall.png` | `index/run_ny.R` | `table2.rerun`, `summary.rerun` |
| Figure 5, emissions vs. racial equity by region | `index/test/twoway_bars.png` | `index/run_ny.R` | `correlations.rerun` |
| Figures 6 and 7, race and income equity by region | `index/test/bars_race.png`, `bars_income.png` | `index/run_ny.R` | `anova.rerun`, `region_slopes.rerun` |
| Figure 8, MPOs across the United States | `national/fig/mpo_national.png` | `national/figures.R` | `national.*` |
| Figures B1 and B2, age and education equity | `index/test/bars_age.png`, `bars_edu.png` | `index/run_ny.R` | `anova.rerun`, `region_slopes.rerun` |
| Figures C1 and C2, sensitivity to zone radius and pollutant | `index/test/sensitivity_scatterplot.png`, `sensitivity_distance_pollutant.png` | `index/run_ny.R` | `sensitivity.rerun` |
| Figure C3, emissions vs. equity across regions | `index/test/slopes_by_type.png` | `index/run_ny.R` | `emissions_slopes.rerun` |
| Table 1 and Table A1, literature review | written by hand | none | none |
| Table 2, equity index scores by region | none (typeset from JSON) | `index/make_results.R` | `table2.rerun` |
| Table A2, descriptive statistics | none (typeset from JSON) | `index/make_results.R` | `descriptives.rows` |
| Uncertainty results (permutation, ACS intervals) | `index/runs/uncertainty/*.csv`, `national/tables/mpo_*.csv` | `index/runs/uncertainty/*.R`, `national/permutation.R`, `national/acs_intervals.R` | `robustness.*`, `national.permutation`, `national.acs` |

Each number in `results.json` is stored as `{"value": ..., "status": ..., "evidence": ...}`, where `evidence` names
the file and script that produced it. Table A2's rows (`descriptives.rows`) hold `mean_pct` and `sd_pct` with one
status and evidence per row.

## The method in one page

1. **Exposure zone.** Buffer every primary and secondary road (TIGER/Line, 2022) by 0.3 km.
2. **Who lives there.** Intersect census tracts (Census cartographic boundary polygons, 2022) with the zone and
   apportion each tract's ACS group counts by the share of the tract's area inside the zone (area weighting).
3. **Emissions per exposed resident.** Divide each county's on-road PM<sub>2.5</sub> (CAT, 2022) by the number of
   people living in its zones, so each exposed resident in a county carries the same share of that county's emissions.
4. **Relative burden.** Within a region, take each group's share of the emissions burden (*e<sub>g</sub>*, from its
   residents inside the zones) and its share of the region's population (*p<sub>g</sub>*, from county ACS totals).
   Divide *e<sub>g</sub>* by *p<sub>g</sub>* and rescale these ratios to sum to 1 across groups. Call the result
   *s<sub>g</sub>*. A group with no members in the region is left out, not scored zero.
5. **Index.** The equal-group index for *n* groups is
   *I* = 1 − *n* / (2(*n* − 1)) × Σ<sub>g</sub> |*s<sub>g</sub>* − 1/*n*|.
   It is 1 when every group carries the same relative burden and 0 when one group carries all of it
   (`get_index()` in [`index/functions.R`](index/functions.R)). A population-weighted companion,
   1 − ½ Σ<sub>g</sub> |*e<sub>g</sub>* − *p<sub>g</sub>*| over each group's emissions and population shares, is also
   computed for reviewers; the paper reports the equal-group index. The overall score in Table 2 is the unweighted
   mean of the four dimension scores.
6. **Is it more than chance?** An exact permutation test shuffles group labels among residents while holding every
   tract's population and every group's total fixed (1,000 draws), and reports how often chance alone is as uneven as
   what we observe.
7. **How much is sampling error?** Every ACS cell is redrawn 500 times from its published margin of error, and the
   index is rescored to give a 95% interval.

The national extension repeats steps 1 to 7 for each multi-county MPO, assigning each tract to the MPO that contains
its interior point; a county partly inside an MPO keeps its whole-county emissions rate. Details:
[`national/README.md`](national/README.md).

## Data sources

| Data | Source | Read by | Key |
|---|---|---|---|
| On-road emissions, every US county, 2020-2025 | [CAT public object store](https://api.cat-apps.com/objects/LATEST), one Parquet file per year (`https://api.cat-apps.com/objects/year/<YYYY>.parquet`) | [`index/cat_bulk.R`](index/cat_bulk.R) | none |
| Race and ethnicity, income, education, age, with margins of error | [ACS 5-year 2022](https://www.census.gov/data/developers/data-sets/acs-5year.html) via [`censusapi`](https://cran.r-project.org/package=censusapi) | [`index/make_census.R`](index/make_census.R), `retrieve_census2()` | `CENSUS_API_KEY` (only to rebuild the cache) |
| Roads, tracts, counties | [TIGER/Line](https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html) via [`tigris`](https://cran.r-project.org/package=tigris) | [`index/make_shapes.R`](index/make_shapes.R), [`national/run_mpo.R`](national/run_mpo.R) | none |
| MPO boundaries | [BTS National Transportation Atlas Database, MPO layer](https://geodata.bts.gov/) | [`national/pilot/pilot_functions.R`](national/pilot/pilot_functions.R) | none |

New York emissions for 2022 are interpolated per county between the nearest CAT years where a county has no 2022 run;
how many counties that touches is recorded in `results.json` (`_meta.emissions`). Emissions sources and the exact
URLs: [`index/test/EMISSIONS_SOURCES.md`](index/test/EMISSIONS_SOURCES.md).

## Repository layout

| Path | What it is |
|---|---|
| [`replicate.sh`](replicate.sh) | One entry point for every stage of the analysis. |
| [`setup.sh`](setup.sh) | Installs R and the packages (Ubuntu 24.04). |
| [`index/`](index/) | The New York analysis and the index library ([`functions.R`](index/functions.R)). Script table: [`index/README.md`](index/README.md). |
| [`index/test/`](index/test/) | Cached inputs (Census, shapes) and derived outputs (indices, figures). Regenerate; never hand-edit. |
| [`index/runs/`](index/runs/) | Results for each emissions variant and the uncertainty checks. |
| [`index/tests/`](index/tests/) | Unit tests: `Rscript index/tests/run_all.R`. |
| [`national/`](national/) | The MPO extension: ledger, per-MPO outputs, models, national figure. See [`national/README.md`](national/README.md). |
| [`results/results.json`](results/results.json) | Every number in the paper, with its evidence. |
| [`docs/`](docs/) | [Replication guide](docs/REPLICATION.md), [session info](docs/sessionInfo.txt), a [road-type weighting spec](docs/ROADTYPE_METHOD.md) (not used in the paper). |
| [`scripts/check.sh`](scripts/check.sh) | Repository checks: R parses, tests pass, links resolve, no secrets or machine paths. |
| [`.contract/`](.contract/) | The project's decision log, plans, and receipts. See [`.contract/README.md`](.contract/README.md). |
| [`demo/`](demo/) | Early prototypes from 2025. Not used by the paper. |
| [`CLAUDE.md`](CLAUDE.md), [`.claude/skills/`](.claude/skills/) | Instructions for coding agents. |

## How this code was built and checked

The original New York pipeline (`index/`) was written by the authors in 2025. The 2026 revision corrected the index
normaliser, moved emissions to the CAT public object store, added four race groups, and added the national MPO
extension and the uncertainty checks. Much of the revision was written with Claude Code (Anthropic) under Tim
Fraser's direction, working to a written plan with decisions reserved for him. What that left behind, for anyone who
wants to check it:

- [`.contract/national/CONTRACT.yaml`](.contract/national/CONTRACT.yaml): decisions ND1-ND45, each with who made it
  and why. [`STATE.md`](.contract/national/STATE.md) is the running log, and
  [`receipts/`](.contract/national/receipts/) holds one receipt per finished step with the checks it ran.
- [`results/results.json`](results/results.json): written by `index/make_results.R`; the manuscript's numbers are
  filled from it.
- [`index/tests/`](index/tests/): the index on hand-computed cases; the matrix version of the index against the
  paper's values; the permutation test's margins and its two extreme cases (a fully mixed unit and a fully
  segregated one); the ACS draws with zero margins, zero cells, and fixed seeds. The 2025 paper's region-level
  results ship as a fixture, and the tests confirm that the 2025 (legacy) formula reproduces them.
- An author-only audit in `make_results.R` (it needs the private manuscript repository) compares the rerun with the
  values printed in the 2025 version of the paper and records the result in `_meta.checks`.

## How to cite

Citation metadata: [`CITATION.cff`](CITATION.cff). Until the paper is published, please cite:

> Fraser, T., Park, Y. G., Li, Y., Tang, Y., & Gao, H. O. (2026). *Measuring Burden and Disparity of Exposure to
> Transportation Emissions in American Communities.* Submitted to the *Journal of Transport Geography*.
> Code: https://github.com/timothyfraser/equity

An earlier version was presented at the Complex Adaptive Systems Conference, University of Tokyo, June 2026.

**Authors.** Timothy Fraser (Cornell University, lead developer), Yeonkyeong Gina Park (California Air Resources
Board), Yifei Li, Yuchen Tang, and H. Oliver Gao (Cornell University). License: [MIT](LICENSE).

---

## For agents

Read [`CLAUDE.md`](CLAUDE.md). It lists the rules (no raw CAT emissions in git, no hand-typed numbers, never edit
`index/test/` by hand) and the three skills in [`.claude/skills/`](.claude/skills/).
