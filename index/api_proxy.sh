#!/bin/bash

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

