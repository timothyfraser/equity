# compare_results.R: compare a rerun's results.json with the paper's, number by number.
#
# Usage, from the repo root:
#   Rscript scripts/compare_results.R [reference.json] [rerun.json]
# Defaults: reference = results.json as committed at HEAD (the paper's numbers); rerun = results/results.json.
# `bash replicate.sh compare` runs this after `bash replicate.sh results`.
#
# Prints, for every number the two files share, whether it matches at three decimals (the precision the paper
# prints), and lists the ones that do not. Also prints the CAT manifest each file was built from: CAT is a live
# database, so a rerun pulls the latest release and New York numbers can move. Exits 0 either way; this is a
# report, not a test.
suppressMessages(library(jsonlite))
args = commandArgs(trailingOnly = TRUE)
ref_path = if (length(args) >= 1) args[1] else {
  tmp = tempfile(fileext = ".json")
  status = system2("git", c("show", "HEAD:results/results.json"), stdout = tmp)
  if (!identical(status, 0L)) stop("Could not read results/results.json at HEAD; pass the reference file explicitly")
  tmp
}
new_path = if (length(args) >= 2) args[2] else "results/results.json"

# Flatten to path -> value for every leaf {value, status, evidence} that holds a single number
leaves = function(x, path = character()){
  if (is.list(x) && !is.null(x$value) && length(x$value) == 1 && is.numeric(x$value))
    return(setNames(x$value, paste(path, collapse = ".")))
  if (is.list(x)) {
    nm = names(x); if (is.null(nm)) nm = as.character(seq_along(x))   # JSON arrays have no names
    return(unlist(unname(Map(function(v, k) leaves(v, c(path, k)), x, nm))))
  }
  NULL
}
ref = read_json(ref_path); new = read_json(new_path)
a = leaves(ref); b = leaves(new)
shared = intersect(names(a), names(b))
d = data.frame(leaf = shared, paper = unname(a[shared]), rerun = unname(b[shared]))
d$match_3dp = round(d$paper, 3) == round(d$rerun, 3)
d$block = sub("\\..*$", "", d$leaf)

cat("Paper:  ", ref$`_meta`$emissions$manifest, " (equity commit ", substr(ref$`_meta`$equity_git_sha, 1, 7), ")\n", sep = "")
cat("Rerun:  ", new$`_meta`$emissions$manifest, " (equity commit ", substr(new$`_meta`$equity_git_sha, 1, 7), ")\n", sep = "")
cat("National MPO results use CAT manifest ", ref$national$cat_manifest$value, "\n\n", sep = "")
cat(sprintf("%d numbers compared; %d match at three decimals; %d differ.\n", nrow(d), sum(d$match_3dp), sum(!d$match_3dp)))
only_ref = setdiff(names(a), names(b)); only_new = setdiff(names(b), names(a))
if (length(only_ref)) cat(sprintf("%d numbers only in the paper's file (e.g. the author-only audit variants published and fix_only).\n", length(only_ref)))
if (length(only_new)) cat(sprintf("%d numbers only in the rerun.\n", length(only_new)))
by_block = aggregate(cbind(n = 1, differ = !match_3dp) ~ block, data = d, FUN = sum)
cat("\nBy block:\n"); print(by_block, row.names = FALSE)
bad = d[!d$match_3dp, ]
if (nrow(bad)) {
  bad$diff = bad$rerun - bad$paper
  bad = bad[order(-abs(bad$diff)), ]
  cat("\nLargest differences (up to 25):\n")
  print(head(bad[, c("leaf", "paper", "rerun", "diff")], 25), row.names = FALSE, digits = 4)
}
