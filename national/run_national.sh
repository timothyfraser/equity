#!/usr/bin/env bash
# run_national.sh: compute the equity index for every multi-county MPO the CAT data supports, and keep the ledger.
# Idempotent: rerun at any time. After new CAT runs are published (a new manifest at
# https://api.cat-apps.com/objects/LATEST), rerunning picks up the blocked MPOs automatically.
# Usage (repo root): bash national/run_national.sh        WORKERS=3 by default
set -euo pipefail
cd "$(dirname "$0")/.."
WORKERS="${WORKERS:-3}"
MAN="$(curl -fsS https://api.cat-apps.com/objects/LATEST | tr -d '[:space:]')"
mkdir -p national/out national/logs
[ -f national/mpo_list.csv ] || Rscript national/ledger.R list
# Download this manifest's year files once, before the parallel workers start (they share the cache;
# concurrent first downloads corrupted a file on 2026-11-20).
Rscript -e 'setwd("index"); source("cat_bulk.R"); m = sub("\\.tsv$", "", commandArgs(TRUE)[1]); invisible(retrieve_emissions_bulk("36001", 2020:2025, 110, cache_dir = file.path("cache/cat_year", m)))' "$MAN"
Rscript national/ledger.R todo "$MAN" > national/logs/todo.txt
echo "CAT manifest $MAN: $(wc -l < national/logs/todo.txt) MPOs to process with $WORKERS workers"
xargs -P "$WORKERS" -I{} sh -c 'Rscript national/run_mpo.R {} > national/logs/{}.log 2>&1; echo "$(date -u +%H:%M:%S) $(tail -1 national/logs/{}.log)"' < national/logs/todo.txt
Rscript national/ledger.R build
