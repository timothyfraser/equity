#!/usr/bin/env bash
# replicate.sh: rerun the analysis behind the paper, stage by stage. Run from anywhere; it works from the repo root.
#
#   bash replicate.sh                 # New York analysis + uncertainty + results.json + tests (no API key needed)
#   bash replicate.sh all             # the above, plus the national MPO analysis (long; see docs/REPLICATION.md)
#   bash replicate.sh ny results      # any subset of stages, run in the order given
#
# Stages
#   census       rebuild the ACS 2022 tract and county caches   (needs CENSUS_API_KEY; the caches are already in git)
#   ny           pull CAT emissions, compute the New York indices, draw the New York figures (map, lines, two-way bars, bar charts, sensitivity)
#   uncertainty  New York permutation test and ACS intervals
#   national     every multi-county MPO: ledger, indices, table, models, tile grid, national figure, permutation, ACS intervals
#   results      write results/results.json, the source of every number in the paper
#   test         unit tests for the index and the uncertainty code
#
# Each stage stops the script on its first error. Logs go to the terminal.
set -euo pipefail
cd "$(dirname "$0")"
export EQUITY_ROOT="$PWD"

stage_census() {
  if [ -z "${CENSUS_API_KEY:-}" ]; then
    echo "census: CENSUS_API_KEY is not set. The ACS caches in index/test/ are already in git, so this stage is optional." >&2
    return 1
  fi
  (cd index && Rscript make_census.R)
}
stage_ny() {
  (cd index && Rscript make_emissions.R && Rscript run_ny.R)
}
stage_uncertainty() {
  Rscript index/runs/uncertainty/ny_permutation.R
  Rscript index/runs/uncertainty/ny_acs_intervals.R
}
stage_national() {
  bash national/run_national.sh
  Rscript national/mpo_table.R
  Rscript national/models.R
  Rscript national/tile_grid.R
  Rscript national/figures.R
  Rscript national/permutation.R
  Rscript national/acs_intervals.R
}
stage_results() {
  (cd index && Rscript make_results.R)
}
stage_test() {
  Rscript index/tests/run_all.R
}

stages=("$@")
if [ ${#stages[@]} -eq 0 ]; then stages=(ny uncertainty results test); fi
if [ "${stages[0]}" = "all" ]; then stages=(ny uncertainty national results test); fi

for s in "${stages[@]}"; do
  case "$s" in
    census|ny|uncertainty|national|results|test) ;;
    *) echo "unknown stage: $s (expected census, ny, uncertainty, national, results, test, or all)" >&2; exit 2 ;;
  esac
done

for s in "${stages[@]}"; do
  echo "== $s  ($(date -u +%H:%M:%S) UTC)"
  t0=$(date +%s)
  "stage_$s"
  echo "== $s done in $(( $(date +%s) - t0 )) s"
done
