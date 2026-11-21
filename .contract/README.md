# .contract: how the 2026 revision was planned, decided, and checked

This folder is the paper trail for the 2026 revision. It is not needed to run the code. It is here so a reader can
see why each analytic choice was made, who made it, and what evidence each step produced.

The national extension and the uncertainty checks were written with Claude Code (Anthropic) under Tim Fraser's
direction. We worked to a written contract: a plan, a list of decisions only Tim could make, and a receipt for every
finished step. That way the analysis does not depend on trusting whoever, or whatever, typed the code.

| File | What it holds |
|---|---|
| [`national/CONTRACT.yaml`](national/CONTRACT.yaml) | Decisions ND1-ND45: each analytic choice, who ruled on it, and the reason. Start here. |
| [`national/STATE.md`](national/STATE.md) | The running log: what was done, in order, and what was left open. |
| [`national/PLAN_NATIONAL.md`](national/PLAN_NATIONAL.md) | The original plan for the MPO extension, including the staged pilot (one MPO, then three, then ten). |
| [`national/PLAN_SCALING_UP.md`](national/PLAN_SCALING_UP.md), [`national/PLAN_VIZ_AND_CAT.md`](national/PLAN_VIZ_AND_CAT.md) | Plans for the national section, the figure, and the uncertainty checks. |
| [`national/receipts/`](national/receipts/) | One receipt per finished step: what changed, the checks run, and their results. |
| [`national/scouts/`](national/scouts/) | Short investigations done before a decision (data availability, method options). |
| [`national/CAT_2022_RUN_REQUEST_37.md`](national/CAT_2022_RUN_REQUEST_37.md), [`national/CAT_ORDERS_HANDOFF.md`](national/CAT_ORDERS_HANDOFF.md) | The CAT model runs ordered to fill counties that had no 2022 data. |

The pilot report for the MPO extension, with its pass/fail checks, is
[`../national/pilot/PILOT_REPORT.md`](../national/pilot/PILOT_REPORT.md).

Some files mention `paper_equity`, the private repository that holds the manuscript. Its numbers come from
[`../results/results.json`](../results/results.json) in this repository.
