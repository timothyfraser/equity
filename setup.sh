#!/usr/bin/env bash
# setup.sh: install R and every package the equity code calls (Ubuntu 24.04). Idempotent.
set -euo pipefail

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi

# Stale package indexes 404, so always update first.
$SUDO apt-get update
$SUDO apt-get install -y \
  r-base-core r-cran-sf r-cran-dplyr r-cran-tidyr r-cran-purrr r-cran-readr \
  r-cran-stringr r-cran-ggplot2 r-cran-viridis r-cran-jsonlite r-cran-httr \
  r-cran-broom r-cran-ggpubr r-cran-scales r-cran-gtools r-cran-progress \
  r-cran-patchwork r-cran-ragg r-cran-clue r-cran-lmtest r-cran-sandwich \
  libcurl4-openssl-dev

# tigris >= 2.3 needs httr2 >= 1.1 and curl >= 6 (curl_parse_url); apt's r-cran-httr2/curl can be older.
$SUDO Rscript -e 'v = function(p) if (requireNamespace(p, quietly = TRUE)) packageVersion(p) else package_version("0.0.0"); if (v("httr2") < "1.1.0" || v("curl") < "6.0.0") install.packages(c("curl", "httr2"), repos = "https://cloud.r-project.org")'

# Packages apt lacks, and newer versions of the ones the plotting packages need: Posit Package Manager binaries.
# Current shadowtext/ggtext pull in ggplot2 4.x, which needs newer scales, rlang, gtable and S7 than Ubuntu 24.04 ships;
# install.packages() does not upgrade a dependency that is installed but too old, so they are upgraded explicitly
# (into /usr/local/lib/R/site-library, ahead of apt's copies). These are the versions the paper was built with
# (docs/sessionInfo.txt) or newer.
$SUDO Rscript - <<'RSCRIPT'
options(
  repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/noble/latest"),
  HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(),
                          paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"]))
)
v = function(p) if (requireNamespace(p, quietly = TRUE)) packageVersion(p) else package_version("0.0.0")
at_least = c(rlang = "1.3.0", scales = "1.4.0", gtable = "0.3.6", S7 = "1.0.0", ggplot2 = "4.0.4")
old = names(at_least)[!vapply(names(at_least), function(p) v(p) >= at_least[[p]], logical(1))]
if (length(old) > 0) install.packages(old)
need = c("nanoparquet", "ggtext", "shadowtext", "ggspatial", "censusapi", "tigris")
missing = need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) install.packages(missing)
need = c(need, "patchwork", "ragg", "clue", "lmtest", "sandwich", "ggpubr", "sf")
still = need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(still) > 0) stop("Failed to install: ", paste(still, collapse = ", "))
cat("All required R packages present.\n")
RSCRIPT
