#!/bin/bash

# RETIRED (2026-11-19). Emissions now come from the public CAT object store
# (https://api.cat-apps.com/objects/year/<YYYY>.parquet, no key) via index/cat_bulk.R
# and index/make_emissions.R. This gcloud proxy to api-analyzer is no longer needed
# and is kept only for history. Do not use it.

# api_proxy.sh --- Start up the cloud run proxy in the terminal
REPO="$(git rev-parse --show-toplevel)" && \
  cd "$REPO" && cd "../equity/index" && \
  SECRET="$(pwd)/secret"  && \
  SERVICE="api-analyzer"  && \
  . "$SECRET/.env" %% \
  SERVICE_URL="$API_URL"  && \
  PROJECT="moves-runs"  && \
  LOCATION="us-central1"  && \
  PORT=5345  && \
  gcloud run services proxy $SERVICE \
    --project=$PROJECT \
    --region=$LOCATION \
    --port=$PORT

