# CLAUDE.md: equity

Replication code for *Measuring Burden and Disparity of Exposure to Transportation Emissions in American
Communities* (Fraser, Park, Li, Tang, Gao; submitted to the *Journal of Transport Geography*). People start at
[`README.md`](README.md); this file is the agent version. Read it before you change anything.

## What this repo is

- `index/`: the New York analysis (62 counties, 10 regions, 2022) and the index library `index/functions.R`.
- `national/`: the same index for every multi-county MPO in the United States (224 computed).
- `results/results.json`: every number the paper prints, written by `index/make_results.R`.
- `replicate.sh`: the one entry point. Stages: `census ny uncertainty national results compare test`.
- `.contract/`: the decision log (ND1-ND45), plans, and receipts. Read `.contract/national/CONTRACT.yaml` before you
  change a method.

## Rules

1. **No raw CAT emissions in git** (ND21). The code pulls them from `https://api.cat-apps.com/objects/` at run time.
   Keep only derived totals (`emissions_mpo`, `emissions_rate_mpo`). The `index/test/emissions_*` files are gitignored.
2. **No hand-typed numbers.** Every number in the paper traces to `results/results.json`, and every leaf there is
   `{value, status, evidence}` with `evidence` naming the script and file (Table A2's `descriptives.rows` carry
   `mean_pct`/`sd_pct` with a status and evidence per row; `_meta.checks` holds author-audit diagnostics). To change a number, change the code and
   rerun `bash replicate.sh results`.
3. **Derived outputs are regenerated, never edited.** That covers `index/test/`, `index/runs/` (except the scripts in
   `index/runs/uncertainty/*.R`), `national/out/`, `national/tables/`, `national/fig/`, and `national/results_*.json`.
4. **Keep superseded functions.** An edit to `index/functions.R` that changes a method keeps the old function under a
   `_legacy` name (for example `get_index_legacy()`).
5. **Never edit a test to make it pass.** If `Rscript index/tests/run_all.R` fails, fix the code or report it.
6. **Secrets.** `CENSUS_API_KEY` comes from the environment. Never write it to a file, print it, or commit `.env`.
7. **Method decisions belong to Tim.** The equal-group index is the headline; the population-weighted index is a
   companion. 14 race groups. Puerto Rico is excluded (filtered in `national/mpo_table.R` and `tile_grid.R`). New York 2022 emissions are interpolated (ND45). Do not change
   any of these without his ruling; record the ruling in `.contract/national/CONTRACT.yaml`.
8. **Branches.** Work on `dev`; Tim merges to `main`.

## Checks to run before you commit

```bash
bash scripts/check.sh          # R parses, tests pass, links resolve, no secrets or machine paths, JSON valid
bash replicate.sh results compare   # if you touched anything that feeds a number
```

## Skills

| Skill | Use it when |
|---|---|
| [`replicate`](.claude/skills/replicate/SKILL.md) | Someone asks to rerun, reproduce, or verify the paper's results or figures. |
| [`national-rerun`](.claude/skills/national-rerun/SKILL.md) | CAT published new runs, an MPO is `blocked_cat`, or the national figure needs rebuilding. |
| [`paper-numbers`](.claude/skills/paper-numbers/SKILL.md) | A number in the paper needs adding, changing, or tracing to its source. |

## Style

R: tidyverse, native pipe `|>` in new code (older code uses `%>%`; leave it unless you are rewriting the function),
`=` for assignment, explicit package prefixes for rarely used functions. Parse-check after every R edit:
`Rscript -e 'invisible(parse(file = "index/functions.R"))'`. Bash: `set -euo pipefail`. No link may point to
github.coecis.cornell.edu (it requires a Cornell login).
