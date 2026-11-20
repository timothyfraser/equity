# ledger.R: the national MPO ledger.
#   Rscript national/ledger.R list            -> (re)write national/mpo_list.csv from BTS NTAD (411 MPOs)
#   Rscript national/ledger.R todo <MANIFEST> -> print MPO IDs to (re)process under this CAT manifest
#   Rscript national/ledger.R build           -> write national/LEDGER.csv, national/LEDGER.md, national/index_mpo.csv
# An MPO is (re)processed when it has no status, its status is error, or it was done/blocked under an
# older CAT manifest (so blocked MPOs are picked up automatically once new CAT runs are published).
# single_county MPOs are never rerun (their membership does not depend on CAT).
suppressPackageStartupMessages({library(dplyr); library(readr); library(purrr); library(jsonlite); library(tidyr)})
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity"); setwd(root)
args = commandArgs(trailingOnly = TRUE); mode = args[1]
read_status = function(){
  f = list.files("national/out", pattern = "^status.json$", recursive = TRUE, full.names = TRUE)
  map_dfr(f, function(p){ s = fromJSON(p, simplifyVector = FALSE)
    tibble(mpo_id = s$mpo_id, status = s$status, n_counties = s$n_counties %||% NA, n_states = s$n_states %||% NA,
           blocking = paste(map_chr(s$blocking, ~paste0(.x$geoid, " ", .x$reason)), collapse = "; "),
           dropped = paste(map_chr(s$dropped, ~paste0(.x$geoid, " ", .x$reason)), collapse = "; "),
           manifest = s$manifest %||% NA, message = s$message %||% NA, finished_utc = s$finished_utc %||% NA, seconds = s$seconds %||% NA) })
}
`%||%` = function(a, b) if(is.null(a)) b else a
if(mode == "list"){
  url = paste0("https://services.arcgis.com/xOi1kZaI0eWDREZv/arcgis/rest/services/NTAD_Metropolitan_Planning_Organizations/FeatureServer/0/query",
               "?where=1%3D1&outFields=MPO_ID,MPO_NAME,STATE&returnGeometry=false&f=json&resultRecordCount=2000")
  d = fromJSON(url)$features$attributes %>% as_tibble() %>% transmute(mpo_id = MPO_ID, mpo_name = MPO_NAME, state = STATE) %>% arrange(mpo_id)
  stopifnot(nrow(d) > 400, !anyDuplicated(d$mpo_id))
  write_csv(d, "national/mpo_list.csv"); message(nrow(d), " MPOs")
} else if(mode == "todo"){
  man = args[2]; ids = read_csv("national/mpo_list.csv", show_col_types = FALSE, col_types = "ccc")$mpo_id
  st = if(dir.exists("national/out")) read_status() else tibble(mpo_id = character(), status = character(), manifest = character())
  x = tibble(mpo_id = ids) %>% left_join(st, by = "mpo_id") %>%
    filter(is.na(status) | status == "error" | (status %in% c("done", "blocked_cat") & manifest != man))
  cat(x$mpo_id, sep = "\n")
} else if(mode == "build"){
  lst = read_csv("national/mpo_list.csv", show_col_types = FALSE, col_types = "ccc")
  L = lst %>% left_join(read_status(), by = "mpo_id") %>% mutate(status = coalesce(status, "pending")) %>% arrange(status, mpo_id)
  write_csv(L, "national/LEDGER.csv")
  idx = list.files("national/out", pattern = "^indices.csv$", recursive = TRUE, full.names = TRUE) %>%
    map_dfr(~read_csv(.x, show_col_types = FALSE, col_types = cols(mpo_id = "c")))
  if(nrow(idx) > 0){
    idx = idx %>% semi_join(L %>% filter(status == "done"), by = "mpo_id")
    write_csv(idx, "national/index_mpo.csv")
  }
  cnt = L %>% count(status)
  blk = L %>% filter(status == "blocked_cat") %>% separate_rows(blocking, sep = "; ") %>%
    mutate(geoid = substr(blocking, 1, 5), reason = sub("^\\S+ ", "", blocking)) %>%
    group_by(geoid, reason) %>% summarize(mpos = paste(mpo_name, collapse = "; "), .groups = "drop") %>% arrange(geoid)
  md = c("# National MPO ledger", "",
         sprintf("Generated %s UTC by `national/ledger.R build`. CAT manifest(s): %s.", format(Sys.time(), "%Y-%m-%d %H:%M", tz = "UTC"),
                 paste(na.omit(unique(L$manifest)), collapse = ", ")), "",
         "Rerun `bash national/run_national.sh` at any time. It processes every MPO with no status or an error, and every done or blocked MPO whose CAT manifest is older than the current one, so blocked MPOs are picked up as soon as new CAT runs are published.", "",
         "| status | MPOs |", "|---|---|", sprintf("| %s | %d |", cnt$status, cnt$n), "",
         "## Blocked: counties with no CAT value for 2022", "",
         "| county | reason | MPOs waiting on it |", "|---|---|---|", sprintf("| %s | %s | %s |", blk$geoid, blk$reason, blk$mpos), "",
         "## Errors", "", sprintf("- %s %s: %s", L$mpo_id[L$status == "error"], L$mpo_name[L$status == "error"], L$message[L$status == "error"]))
  writeLines(md, "national/LEDGER.md"); print(cnt)
}
