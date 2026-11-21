---
name: replicate
description: Rerun, reproduce, or verify the equity paper's results and figures. Use when someone says "replicate", "reproduce the paper", "rerun the analysis", "do the numbers still hold", "regenerate the figures", "check results.json", or opens a fresh clone and wants to know it works.
---

# Replicate the paper

The paper's numbers live in `results/results.json`; its figures in `index/test/*.png` and
`national/fig/mpo_national.png`. Replication means regenerating them from public data and checking the numbers
against the committed copy.

## Steps

1. **Install** (once): `bash setup.sh` on Ubuntu 24.04. Elsewhere, see `docs/REPLICATION.md#requirements`.
2. **Run the default stages** from the repo root:
   ```bash
   bash replicate.sh            # ny uncertainty results compare test
   ```
   No API key needed. Add `national` (`bash replicate.sh all`) only if asked: it needs `CENSUS_API_KEY` and takes
   hours on a first run.
3. **Read the `compare` output.** It lists how many numbers match the paper at three decimals and the largest
   differences, and prints the CAT manifest behind each file.
4. **Check the tests line**: `4 test files, 0 failing`.

## Reading a difference

- **Default run**: New York uses the frozen inputs in `index/data/cat_MANIFEST-e2ccfae4/`, so every number should
  match (0 differ). Any difference is a regression.
- **`EMISSIONS=live`, small New York differences**: expected. CAT is a live database; a live rerun pulls the latest
  release. Report the manifests and the size of the largest differences. Do not "fix" the numbers.
- **Same manifest, any difference**: a real regression. Find the commit that changed the method (`git log -p
  index/functions.R`) and report it before touching anything.
- **`national.*` differs** after a `national` run: compare `national/LEDGER.csv` statuses and the manifest in
  `results.json` (`national.cat_manifest`).

## Do not

- Edit anything in `index/test/`, `index/runs/`, `national/out/` or `results/` by hand.
- Commit a rerun's `results/results.json` or figures unless Tim asked for the paper's numbers to be updated.
  `git checkout -- index/test index/runs results national` restores the paper's copies.
- Commit raw CAT emissions (`index/test/emissions_*` are gitignored for that reason), or edit the frozen New York
  copy in `index/data/cat_MANIFEST-e2ccfae4/` (ND46).
