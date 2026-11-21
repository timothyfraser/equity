#!/usr/bin/env bash
# check.sh: repository checks. Run from anywhere; exits 1 if any check fails.
#
#   bash scripts/check.sh              # everything, including the unit tests (needs the R packages from setup.sh)
#   bash scripts/check.sh --static     # skip the unit tests (base R and Python only; what CI's first job runs)
#
# Checks
#   1. every R file parses
#   2. every shell script parses (bash -n)
#   3. results/results.json and national/results_*.json are valid JSON, and every results.json leaf has
#      value, status, and evidence
#   4. every relative link in the documentation points to a file that exists
#   5. no machine-specific paths (/home/user, C:\Users) in code or top-level docs
#   6. no secrets: no tracked .env files, no API-key-shaped strings, no login-gated Cornell GitHub links
#   7. the unit tests pass (Rscript index/tests/run_all.R)
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
ok()   { printf "OK    %s\n" "$1"; }
bad()  { printf "FAIL  %s\n" "$1"; fail=1; }

# 1. R parses
r_files=$(git ls-files '*.R')
if Rscript -e 'f = commandArgs(TRUE); bad = character(); for (x in f) tryCatch(invisible(parse(file = x)), error = function(e) bad <<- c(bad, paste0(x, ": ", conditionMessage(e)))); if (length(bad)) { writeLines(bad); quit(status = 1) }' $r_files; then
  ok "R parses ($(echo "$r_files" | wc -l) files)"
else bad "R parse errors above"; fi

# 2. shell scripts parse
sh_bad=0
for f in $(git ls-files '*.sh'); do bash -n "$f" || { echo "  $f"; sh_bad=1; }; done
[ $sh_bad -eq 0 ] && ok "shell scripts parse" || bad "shell parse errors above"

# 3-5. JSON, links, machine paths (Python, standard library only)
if python3 -I - <<'PY'
import json, os, re, subprocess, sys
bad = []
# 3. JSON
for f in ["results/results.json"] + sorted(p for p in os.listdir("national") if p.startswith("results_") and p.endswith(".json")):
    path = f if "/" in f else os.path.join("national", f)
    try:
        d = json.load(open(path))
    except Exception as e:
        bad.append(f"invalid JSON {path}: {e}"); continue
    if path == "results/results.json":
        def walk(x, where):
            if isinstance(x, dict):
                if "value" in x and not isinstance(x["value"], dict) and not {"status", "evidence"} <= set(x):
                    bad.append(f"results.json leaf without status/evidence: {where}")
                for k, v in x.items():
                    if k != "value": walk(v, f"{where}.{k}")
            elif isinstance(x, list):
                for i, v in enumerate(x): walk(v, f"{where}[{i}]")
        walk(d, "")
# 4. relative links in docs
tracked = subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.split()
docs = [f for f in tracked if f.endswith(".md") and (
    f.count("/") == 0 or f.startswith(("docs/", ".claude/", "results/")) or
    f in ("index/README.md", "national/README.md", ".contract/README.md",
          "index/test/EMISSIONS_SOURCES.md"))]
link = re.compile(r"\]\(([^)\s]+)\)")
for f in docs:
    text = open(f).read()
    text = re.sub(r"```.*?```", "", text, flags=re.S)   # ignore code blocks
    for target in link.findall(text):
        if re.match(r"^(https?:|mailto:|#)", target): continue
        path = target.split("#")[0]
        full = os.path.normpath(os.path.join(os.path.dirname(f), path))
        if not os.path.exists(full):
            bad.append(f"broken link in {f}: {target}")
# 5. machine paths in code and top-level docs
code = [f for f in tracked if f.endswith((".R", ".sh", ".py")) and f != "scripts/check.sh"] + docs
for f in code:
    for n, line in enumerate(open(f, errors="replace"), 1):
        if "/home/user" in line or "C:\\Users" in line:
            bad.append(f"machine path {f}:{n}")
if bad:
    print("\n".join("  " + b for b in bad)); sys.exit(1)
print(f"  {len(docs)} docs, {len(code)} files scanned")
PY
then ok "JSON valid, results leaves complete, doc links resolve, no machine paths"
else bad "JSON, link, or path problems above"; fi

# 6. secrets and login-gated links
sec=0
if git ls-files | grep -E '(^|/)\.env$|secret/\.env' >/dev/null; then echo "  tracked .env file"; sec=1; fi
if git grep -nIE '(brk_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|CENSUS_API_KEY=[0-9a-f]{40})' -- . >/dev/null; then
  git grep -nIE '(brk_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|CENSUS_API_KEY=[0-9a-f]{40})' -- . | cut -c1-80; sec=1; fi
if git grep -nI 'github.coecis.cornell.edu' -- . ':!CLAUDE.md' ':!.contract' ':!scripts/check.sh' >/dev/null; then
  git grep -nI 'github.coecis.cornell.edu' -- . ':!CLAUDE.md' ':!.contract' ':!scripts/check.sh' | cut -c1-120; sec=1; fi
[ $sec -eq 0 ] && ok "no secrets or login-gated links" || bad "secret or login-gated link above"

# 7. tests
if [ "${1:-}" != "--static" ]; then
  if Rscript index/tests/run_all.R; then ok "unit tests"; else bad "unit tests"; fi
fi

[ $fail -eq 0 ] && echo "All checks passed." || echo "Some checks failed."
exit $fail
