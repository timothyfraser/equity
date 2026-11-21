# .contract: how the 2026 revision was planned, decided, and checked

This folder is the paper trail for the 2026 revision. It is not needed to run the code. It is here so a reader can
see why each analytic choice was made, who made it, and what evidence each step produced.

The national extension and the uncertainty checks were written with Claude Code (Anthropic) under Tim Fraser's
direction. We worked to a written contract: a plan, a list of decisions only Tim could make, and a receipt for every
finished step, so each choice can be checked against its reason and its evidence.

| File | What it holds |
|---|---|
| [`national/CONTRACT.yaml`](national/CONTRACT.yaml) | Decisions ND1-ND45: each analytic choice, who ruled on it, and the reason. Start here. |
| [`national/STATE.md`](national/STATE.md) | The running log: what was done, in order, and what was left open. |
| [`national/PLAN_NATIONAL.md`](national/PLAN_NATIONAL.md) | The original plan for the MPO extension, including the staged pilot (one MPO, then three, then ten). |
| [`national/PLAN_SCALING_UP.md`](national/PLAN_SCALING_UP.md), [`national/PLAN_VIZ_AND_CAT.md`](national/PLAN_VIZ_AND_CAT.md) | Plans for the national section, the figure, and the uncertainty checks. |
| [`national/receipts/`](national/receipts/) | One receipt per finished step: what changed, the checks run, and their results. |
| [`national/scouts/`](national/scouts/) | Short investigations done before a decision (data availability, method options). |
| [`national/CAT_2022_RUN_REQUEST_37.md`](national/CAT_2022_RUN_REQUEST_37.md), [`national/CAT_ORDERS_HANDOFF.md`](national/CAT_ORDERS_HANDOFF.md) | The CAT model runs ordered to fill counties that had no 2022 data. |

Beyond this folder, the checks a reader can rerun are:

- [`../results/results.json`](../results/results.json), written by `index/make_results.R`; the manuscript's numbers
  are filled from it.
- [`../index/tests/`](../index/tests/): the index on hand-computed cases; the matrix version of the index against the
  paper's values; the permutation test's margins and its two extreme cases; the ACS draws with zero margins, zero
  cells, and fixed seeds. The 2025 paper's region-level results ship as a fixture, and the tests confirm that the
  2025 (legacy) formula reproduces them.
- An author-only audit in `index/make_results.R` (it needs the private manuscript repository) compares the rerun
  with the values printed in the 2025 version of the paper and records the result in `_meta.checks`.

The pilot report for the MPO extension, with its pass/fail checks, is
[`../national/pilot/PILOT_REPORT.md`](../national/pilot/PILOT_REPORT.md).

Some files mention `paper_equity`, the private repository that holds the manuscript. Its numbers come from
[`../results/results.json`](../results/results.json) in this repository.
