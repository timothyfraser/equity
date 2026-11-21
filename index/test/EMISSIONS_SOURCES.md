# Emissions sources

We do not store raw CAT emissions in GitHub, because anyone can pull them from CAT public without a key.
The analysis outputs (indices, MPO totals) are stored; the national county emissions are not.

One exception (ND46): the New York emissions the paper used (CAT `MANIFEST-e2ccfae4`, 85 KB) are frozen in
[`../data/cat_MANIFEST-e2ccfae4/`](../data/cat_MANIFEST-e2ccfae4/) with checksums, because CAT keeps only its latest
release. `bash replicate.sh` loads them; `EMISSIONS=live bash replicate.sh` pulls the latest release from the URLs below.

## Exact URLs

- Latest manifest pointer: https://api.cat-apps.com/objects/LATEST
- One parquet file per year: `https://api.cat-apps.com/objects/year/<YYYY>.parquet`, for 2020 to 2025:
  - https://api.cat-apps.com/objects/year/2020.parquet
  - https://api.cat-apps.com/objects/year/2021.parquet
  - https://api.cat-apps.com/objects/year/2022.parquet
  - https://api.cat-apps.com/objects/year/2023.parquet
  - https://api.cat-apps.com/objects/year/2024.parquet
  - https://api.cat-apps.com/objects/year/2025.parquet

## Manifest used

`MANIFEST-e2ccfae4.tsv` (recorded in [`emissions_provenance.txt`](emissions_provenance.txt), along with row counts and the download time).

## Key

None. CAT public needs no key.

## Regenerate

```bash
cd index && Rscript make_emissions.R
```

This rewrites `emissions_all_pollutants.{rds,csv}`, `emissions_2020_2025_endpoints.rds`, `emissions_2022_exact.rds`
and `emissions.rds` in this folder (all gitignored) and refreshes `emissions_provenance.txt`.
For MPO runs, `national/run_mpo.R` pulls the same files itself and stores only `emissions_mpo` and `emissions_rate_mpo` in each `indices.csv`.

CAT is updated over time, so values pulled later may differ slightly from the ones behind the paper.
