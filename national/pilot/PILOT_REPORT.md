# MPO pilot report (P0-P4), 2026-11-20

The staged pilot from `.contract/national/PLAN_NATIONAL.md` section 12. PM2.5 (pollutant 110), 300 m buffers, 2022, emissions interpolated piecewise between the nearest CAT years. Every number below comes from `national/pilot/out/*` (regenerate with the commands at the end).

## Verdict

The method works on all three MPOs and reproduces the paper exactly where it should. I recommend one more stage on edge cases (P5) before the national run; see the end of this report.

## Stages

| Stage | MPO | Result |
|---|---|---|
| P0 | Capital District REDC region (paper's cached inputs) | **Pass.** The new unit function reproduces `results.json` `table2.rerun` for all five indices; max difference 3.3e-16. |
| P1 | Capital Region Transportation Council (NY, 36197300) | **Pass.** Fresh downloads equal the paper's cached inputs: census tables identical, exposed-area shares within 1.0e-10, emissions identical; whole-county index fresh vs cached within 1.6e-13. 4 counties, Saratoga partial (61 of 65 tracts). 27 s. |
| P2 | Durham Chapel Hill Carrboro MPO (NC, 37198001) | **Pass.** 3 counties, 2 partial (Chatham 4 of 19 tracts, Orange 34 of 42). 17 s. |
| P3 | Louisville/Jefferson County KY-IN MPO (21197300) | **Pass.** 5 counties in 2 states, none partial. 31 s. |

Checks passed for every MPO: one polygon; each member county has 2022 emissions; exposed residents no more than population; group emission shares and population shares each sum to 1; indices in [0, 1].

## Indices (method C: MPO tracts, tract-sum population)

| MPO | race | income | edu | age | overall | race, population-weighted |
|---|---|---|---|---|---|---|
| Capital Region (NY) | 0.923 | 0.961 | 0.972 | 0.970 | 0.957 | 0.966 |
| Durham Chapel Hill Carrboro (NC) | 0.922 | 0.958 | 0.974 | 0.931 | 0.946 | 0.974 |
| Louisville KY-IN | 0.920 | 0.976 | 0.963 | 0.990 | 0.962 | 0.978 |

## What the comparison shows

1. **ACS tract sums equal county tables** for every group in all three MPOs (effect exactly 0). Tract-sum population is safe to use nationally.
2. **Partial counties matter, so tract membership is needed.** Treating Durham's MPO as its three whole counties gives race 0.940; using only the MPO's tracts gives 0.922 (-0.018). Age moves -0.013 and education +0.014. For the Capital Region the change is -0.003 on race. Louisville has no partial county, so its change is 0.
3. **Small race groups drive the equal-group race index**, as the planner warned. Each MPO has 3-5 of the 10 race groups under 1,000 residents; Durham has one group absent and its smallest present group has 30 people. The three race scores land within 0.003 of each other (0.920-0.923), while the population-weighted scores spread wider (0.966-0.978). The under-1,000 marker on the chart (ND10) is needed.
4. **Outside New York, 2022 emissions are mostly a straight line between 2020 and 2025.** All three Durham counties and four of five Louisville counties have only those two CAT years. This should be stated in the paper.
5. **Speed:** 5.6-6.8 s per member county including downloads, so the national run fits in hours, not days.

## Not yet tested (proposed P5)

- Connecticut: ACS 2022 and TIGER use planning regions, CAT uses the old counties.
- A county with no 2025 CAT run (45 counties), and the Alaska and South Dakota county renames.
- A county with no exposed residents (currently `NaN`, which poisons the region).
- A very large MPO (New York Metropolitan Transportation Council, about 10 counties and 4,000+ tracts) and a very small one.

## Reproduce

```bash
Rscript national/pilot/p0_math_check.R
for id in 36197300 37198001 21197300; do Rscript national/pilot/run_pilot_mpo.R $id; done
Rscript national/pilot/p1_compare_cache.R 36197300
Rscript national/pilot/p4_compare.R
```
