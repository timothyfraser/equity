---
name: paper-numbers
description: Add, change, or trace a number that appears in the equity paper. Use when someone asks "where does this number come from", "add a statistic to the paper", "update the results", "the paper says X but the code says Y", or edits results.json.
---

# Numbers in the paper

Every number the paper prints comes from `results/results.json`. Each leaf is

```json
{"value": 0.854, "status": "recomputed", "evidence": "index/runs/variant_A (...; make_results.R)"}
```

The manuscript (in a separate, private repository) fills its numbers from this file, rounded to three decimals.

## Trace a number

1. Search `results/results.json` for the value (or a nearby rounding of it).
2. Read its `evidence`: it names the file and the script that produced it.
3. The block tells you the stage: `table2`, `summary`, `correlations`, `emissions_slopes`, `anova`, `region_slopes`,
   `sensitivity`, `descriptives`, `robustness` come from the New York analysis; `national.*` from `national/`.
   The paper reports the `rerun` variant; others are checks.

## Add or change a number

1. Compute it in code. New York numbers go in `index/make_results.R`; national numbers go in the national script
   that owns them (`national/models.R`, `permutation.R`, `acs_intervals.R`) and reach `results.json` through the
   `J$national` section of `make_results.R`.
2. Write it as a `{value, status, evidence}` leaf. Never type a value into the JSON.
3. Run `bash replicate.sh results compare test`. `compare` must show no unexpected differences.
4. Commit the code and the regenerated `results/results.json` together.

## Do not

- Type a number into `results.json`, a README, or the paper.
- Round inside the JSON. Store full precision; the paper rounds when it prints.
- Change which variant is the headline (`rerun`) or which index is the headline (equal-group). Those are Tim's rulings.
