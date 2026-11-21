# tests/run_all.R -- run every index/tests/test_*.R, each in its own Rscript process.
# Purpose: one command that says whether the index code and the uncertainty code still pass their tests.
# Each test file is run from index/ (the tests source functions.R and uncertainty_*.R by relative path),
# in a fresh process so one file's globals cannot leak into the next. One line per file, then a total.
# Exits 1 if any file fails (non-zero exit status from Rscript), 0 otherwise.
# How to run, from the repo root:   Rscript index/tests/run_all.R
args = commandArgs(FALSE)
here = dirname(normalizePath(sub("^--file=", "", args[grep("^--file=", args)][1])))
index_dir = dirname(here)
files = sort(list.files(here, pattern = "^test_.*\\.R$"))
setwd(index_dir)
rscript = file.path(R.home("bin"), "Rscript")
n_bad = 0L; n_skip_all = 0L
for(f in files){
  t0 = proc.time()[["elapsed"]]
  out = suppressWarnings(system2(rscript, file.path("tests", f), stdout = TRUE, stderr = TRUE))
  status = attr(out, "status"); if(is.null(status)) status = 0L
  npass = sum(grepl("^PASS", out)); nfail = sum(grepl("^FAIL", out)); nskip = sum(grepl("^SKIP", out))
  n_skip_all = n_skip_all + nskip
  secs = proc.time()[["elapsed"]] - t0
  cat(sprintf("%-4s %-32s %3d PASS %2d FAIL %2d SKIP  %5.1f s\n", if(status == 0L) "OK" else "FAIL", f, npass, nfail, nskip, secs))
  if(status != 0L){ n_bad = n_bad + 1L; cat(paste0("     ", utils::tail(out, 5)), sep = "\n") }
}
cat(sprintf("%d test files, %d failing, %d checks skipped (fixtures a fresh clone does not have; see SKIP lines)\n",
            length(files), n_bad, n_skip_all))
if(n_skip_all > 0L) cat("Run `bash replicate.sh ny` (and `national`) to create them, then rerun the tests.\n")
quit(status = if(n_bad > 0L) 1L else 0L)
