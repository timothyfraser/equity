# Where each figure and table comes from

Back to the [README](../README.md). Every number in the paper is in [`results/results.json`](../results/results.json),
written by [`index/make_results.R`](../index/make_results.R).

| In the paper | File | Made by | Numbers in `results.json` |
|---|---|---|---|
| Figure 1, research design flowchart | drawn by hand | none | none |
| Figure 2, step-by-step index calculation | drawn by hand | none | none |
| Figure 3, Albany County roads and exposure zones | `index/test/map.png` | `index/run_ny.R` | none |
| Figure 4, regional variation in equity | `index/test/lines_overall.png` | `index/run_ny.R` | `table2.rerun`, `summary.rerun` |
| Figure 5, emissions vs. racial equity by region | `index/test/twoway_bars.png` | `index/run_ny.R` | `correlations.rerun` |
| Figures 6 and 7, race and income equity by region | `index/test/bars_race.png`, `bars_income.png` | `index/run_ny.R` | `anova.rerun`, `region_slopes.rerun` |
| Figure 8, MPOs across the United States | `national/fig/mpo_national.png` | `national/figures.R` | `national.*` |
| Figures B1 and B2, age and education equity | `index/test/bars_age.png`, `bars_edu.png` | `index/run_ny.R` | `anova.rerun`, `region_slopes.rerun` |
| Figures C1 and C2, sensitivity to zone radius and pollutant | `index/test/sensitivity_scatterplot.png`, `sensitivity_distance_pollutant.png` | `index/run_ny.R` | `sensitivity.rerun` |
| Figure C3, emissions vs. equity across regions | `index/test/slopes_by_type.png` | `index/run_ny.R` | `emissions_slopes.rerun` |
| Table 1 and Table A1, literature review | written by hand | none | none |
| Table 2, equity index scores by region | none (typeset from JSON) | `index/make_results.R` | `table2.rerun` |
| Table A2, descriptive statistics | none (typeset from JSON) | `index/make_results.R` | `descriptives.rows` |
| Uncertainty results (permutation, ACS intervals) | `index/runs/uncertainty/*.csv`, `national/tables/mpo_*.csv` | `index/runs/uncertainty/*.R`, `national/permutation.R`, `national/acs_intervals.R` | `robustness.*`, `national.permutation`, `national.acs` |

Each number in `results.json` is stored as `{"value": ..., "status": ..., "evidence": ...}`, where `evidence` names
the file and script that produced it. Table A2's rows (`descriptives.rows`) hold `mean_pct` and `sd_pct` with one
status and evidence per row.
