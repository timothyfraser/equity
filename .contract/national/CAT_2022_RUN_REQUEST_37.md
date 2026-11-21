# Request to the CAT data stream: 2022 runs for 37 counties with only a 2020 run

From: the equity paper's national MPO extension (`timothyfraser/equity`, branch `dev`). Requested by Tim, 2026-11-20 ("You can just request the CAT runs. 37-county CAT runs are not hard."). This is a brief for the catdashboard session, which owns Cloud MOVES runs and the published emissions objects. This session cannot submit runs: it has no service-account key and no signed-in account token.

Same procedure as `paper_equity/.contract/r0/CAT_2022_RUN_REQUEST.md` (the 24 New York counties).

## What is missing

In the published cube (manifest `MANIFEST-e2ccfae4.tsv`, `year/2020.parquet` to `year/2025.parquet`, pollutant 110 checked), these 37 counties have a 2020 county total and nothing later. Every other county has at least one year on each side of 2022, so 2022 can be interpolated. These cannot. Several are in multi-county MPOs: Richmond city and Chesterfield (Richmond Area MPO) and Virginia Beach and Portsmouth (Hampton Roads TPO).

| geoid | county | state | CAT years published |
|---|---|---|---|
| 35035 | Otero County | NM | 2020 |
| 35055 | Taos County | NM | 2020 |
| 46031 | Corson County | SD | 2020 |
| 46041 | Dewey County | SD | 2020 |
| 46051 | Grant County | SD | 2020 |
| 46061 | Hanson County | SD | 2020 |
| 46071 | Jackson County | SD | 2020 |
| 46081 | Lawrence County | SD | 2020 |
| 46089 | McPherson County | SD | 2020 |
| 46101 | Moody County | SD | 2020 |
| 46109 | Roberts County | SD | 2020 |
| 46119 | Sully County | SD | 2020 |
| 46129 | Walworth County | SD | 2020 |
| 51029 | Buckingham County | VA | 2020 |
| 51041 | Chesterfield County | VA | 2020 |
| 51051 | Dickenson County | VA | 2020 |
| 51065 | Fluvanna County | VA | 2020 |
| 51077 | Grayson County | VA | 2020 |
| 51091 | Highland County | VA | 2020 |
| 51115 | Mathews County | VA | 2020 |
| 51133 | Northumberland County | VA | 2020 |
| 51173 | Smyth County | VA | 2020 |
| 51199 | York County | VA | 2020 |
| 51678 | Lexington city | VA | 2020 |
| 51740 | Portsmouth city | VA | 2020 |
| 51760 | Richmond city | VA | 2020 |
| 51810 | Virginia Beach city | VA | 2020 |
| 54015 | Clay County | WV | 2020 |
| 54025 | Greenbrier County | WV | 2020 |
| 54035 | Jackson County | WV | 2020 |
| 54045 | Logan County | WV | 2020 |
| 54055 | Mercer County | WV | 2020 |
| 54065 | Morgan County | WV | 2020 |
| 54075 | Pocahontas County | WV | 2020 |
| 54085 | Ritchie County | WV | 2020 |
| 54095 | Tyler County | WV | 2020 |
| 54105 | Wirt County | WV | 2020 |

## What is needed

1. Default-input county-scale MOVES runs, **year 2022**, for the 37 geoids above (same kind of run as the existing granddata county-years, no custom inputs; `platform/docs/internal/BULK_RUNS.md` or its successor).
2. Publish each finished run into granddata (PLATFORM.md D28).
3. Rebuild and publish `detail/<geoid>.parquet` for the 37 counties and `year/2022.parquet` (plus `year/2022-by8.parquet`) with a new manifest.

If it is no harder to batch, adding the 24 New York counties from the earlier request in the same run gives the paper exact 2022 values for all 62 New York counties.

## How we will know it is done

```bash
curl -s "https://api.cat-apps.com/objects/LATEST?t=$(date +%s)"   # newer than MANIFEST-e2ccfae4.tsv
curl -s -o y2022.parquet https://api.cat-apps.com/objects/year/2022.parquet
# each of the 37 geoids has by=16 rows for pollutant 110 in year 2022
```

## What happens on our side afterwards

Run `bash national/run_national.sh` from the `equity` repo root. It reads the new manifest from `LATEST`, downloads that manifest's year files into a fresh cache folder, and reprocesses every MPO whose last run used an older manifest, including every `blocked_cat` MPO in `national/LEDGER.md`. Nothing else needs changing. Richmond Area MPO (51197401) is the check: its two blocking counties should then show `emis_method = exact` in `national/out/51197401/members.csv`.
