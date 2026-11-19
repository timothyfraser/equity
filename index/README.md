# index/

The full documentation is in the [root README](../README.md). Run everything from this folder with `Rscript`
(set `CENSUS_API_KEY` first; see the [quick start](../README.md#quick-start)).

| Script | Step | What it does |
|---|---|---|
| [`make_data.R`](make_data.R) | 1 | Downloads ACS 5-year (2022) demographics through `censusapi`. |
| [`make_shapes.R`](make_shapes.R) | 2 | Builds TIGER road, tract, and 0.3 km buffer geometries. |
| [`make_emissions.R`](make_emissions.R) | 3 | Loads CAT county emissions (uses `cat_bulk.R`). |
| [`run_ny.R`](run_ny.R) | 4 | Computes the indices and writes figures and tables for New York. |
| [`functions.R`](functions.R) | library | Index and data-processing functions. |
| [`api_proxy.sh`](api_proxy.sh) | retired | Old Cloud Run proxy for emissions; replaced by the public CAT object store. |

Outputs land in `test/` (derived; safe to regenerate).
