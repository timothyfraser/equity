# CLAUDE.md: equity

Public replication repo for *Measuring Burden and Disparity of Exposure to Transportation Emissions in American
Communities* (Fraser, Park, Li, Tang, Gao; in preparation). Read `README.md` first; this file is the short agent version.

## Layout

- `index/` is the pipeline the paper uses: `make_data.R` (ACS via censusapi), `make_shapes.R` (TIGER roads, tracts,
  0.3 km buffers), `make_emissions.R` (CAT emissions, via `cat_bulk.R`), `run_ny.R` (indices, figures),
  `functions.R` (library).
- `index/test/` holds derived outputs. Regenerate them; never hand-edit.
- `index/published/` is a local, gitignored snapshot of the as-published outputs. Do not commit it.
- `demo/` is early prototypes, not used by the paper. Leave it alone.
- `index/api_proxy.sh` is retired (old Cloud Run proxy); emissions come from https://api.cat-apps.com/objects/year/<YYYY>.parquet.

## How to run

```bash
bash setup.sh
export CENSUS_API_KEY=...        # from your environment; never write it to a file in the repo
cd index && Rscript make_emissions.R && Rscript run_ny.R
```

Parse check after any R edit: `Rscript -e 'parse(file="index/functions.R")'`.

## Rules

- Never commit secrets, `.env` files, or API keys. `CENSUS_API_KEY` comes from the environment.
- Every number in the paper traces to `paper_equity/.contract/r0/results.json`, produced by `index/make_results.R`.
  Do not type a paper number by hand.
- Edits to `functions.R` keep superseded functions under `_legacy` names (for example `get_index_legacy`); do not delete them.
- R style: tidyverse, native pipe, `=` for assignment.
- No link in this repo may point to github.coecis.cornell.edu (login-gated).
- Branches: work on `dev`; `main` is merged by Tim.
