# NAT-S1 timing scout (2026-11-20). Incomplete: TIGER host is blocked, so shape stages could not run for DE/VT.

## Step 1 Census API: WORKS
retrieve_census2 via censusapi, key accepted, HTTP ok (no error). Delaware tracts: 262 rows x 38 cols, 2.4 s.

## Step 2 TIGER: BLOCKED from this network
www2.census.gov, www.census.gov, tigerweb.geo.census.gov, services.arcgis.com all return
`CONNECT tunnel failed, response 403` / `HTTP/1.1 403 Forbidden (agent proxy: no rule or network setting allows this host)`.
tigris 2.3.0 reports: "Download failed with both HTTP and FTP ... HTTP: unused argument (retry_on_failure = TRUE)" for
primary_secondary_roads("10",2022), tracts("10",2022), counties("10",2022) (misleading; real cause is the proxy 403).
Reachable: api.census.gov (200), api.cat-apps.com/objects (206). Needs allowlisting of www2.census.gov (TIGER zips) to proceed.

## Step 3 stage x state (seconds / MB on disk as .rds)
| stage | DE (3 co, 262 tr) | VT (14 co, 193 tr) |
|---|---|---|
| census tracts (retrieve_census2) | 2.4 s / 0.018 MB | 1.8 s / 0.013 MB |
| census counties | 1.9 s / 0.001 MB | 1.9 s / 0.002 MB |
| emissions (2020+2025 parquet, by==16, pol 110) | 0.9 s (first download, 2 x ~0.3 MB parquet) / ~0 MB | 0.03 s / ~0 MB |
| counties/tracts/roads shapes (tigris) | BLOCKED | BLOCKED |
| 300 m buffer, get_area_roads, get_all | NOT RUN (no shapes) | NOT RUN |

Census is ~2 s per call regardless of state size (API latency, not volume); tracts file is ~0.07 KB-ish per tract.
Each state needs 2 census calls (tract, county) per year, plus one parquet pair for the entire US (~0.3 MB per year).

### Proxy measurement using existing NY shapes (copied read-only from index/test; NY = 62 counties, 4,900ish tracts)
NY inputs on disk: shapes_roads 8.07 MB, shapes_tracts 1.83 MB, shapes_counties 0.21 MB, buffers300 0.83 MB, area_roads300 1.90 MB.
Ran get_shapes_buffers(dist=300) + get_area_roads on a random 3-county NY subset: finished in roughly 3.5-4 min wall total
(file timestamps; per-stage split lost because output was piped and the run was killed). area_roads300 for the 3 counties = 0.077 MB.
A random 14-county NY subset did NOT finish within the 4 minute stage cap (stopped). get_all was not timed (needed ny14 output).
CAVEAT: sf_use_s2(FALSE) was set; run on 1 CPU at ~99%; NY urban counties (e.g. NYC boroughs, Erie) are far heavier than rural ones,
so this is not a clean per-county number. Treat as: shapes compute is minutes per handful of counties, i.e. O(10-100 s) per county.

## Step 4 loop structure and complexity
- make_shapes.R is NOT a per-county loop at the script level: it calls get_shapes_counties/tracts/roads for the whole state at once
  (get_state() takes one state from the geoids; functions.R:448, 462, 477, 493), then calls get_shapes_buffers and get_area_roads once per distance.
- get_shapes_roads (493-525): st_intersection(all state roads, counties) in one call, then group_by(geoid) st_combine.
- get_shapes_buffers (532-557): st_buffer of the combined multiline per county, then st_intersection with the county polygon inside a grouped mutate (per county).
  It also calls saveRDS(path_shapes_buffers) on a GLOBAL (line ~553): fails unless that global exists; side effect writes a file.
- get_area_roads (687-725): map over counties; for each county, group_by(tract) reframe(st_intersection_faster(tract, buffers_i)), st_make_valid, st_union, st_area.
  Per county, per tract: intersect one tract polygon with the whole county's merged buffer multipolygon. Cost ~ (tracts in county) x (complexity of county buffer).
  Not O(roads x tracts) pairwise, but each tract is clipped against the full-county buffer geometry (heavy for large vertex counts); scales with buffer distance
  only mildly, but dominates runtime. This stage (with get_shapes_buffers) was the slow part in my NY runs.
- st_intersection_faster (564-585): st_intersects index, then per-x st_intersection with only the hit y features; since y here is length 1 (one merged buffer per county) the prefilter does nothing.
- get_shapes_tracts_by_exposure (591) and _loop (652) are unused by the paper path (loop references global `geoids`, and uses `buffer_i = tracts %>% filter(geoid == i)` which looks like a bug).

## Step 5 extrapolation (low confidence; shape stage could not be measured on real DE/VT)
Measured-ish: census 2 calls x ~2 s per state (51 states ~ 3.5 min total, ~0 MB: ~0.07 MB per 1,000 tracts... NY tracts 0.39 MB, 62 counties).
Emissions: one national parquet per year, 0.3 MB; negligible.
Shape/area stage: from the NY 3-county proxy ~ 70-80 s per county at 300 m (upper bound, includes startup and heavy urban counties; 14 counties > 240 s = >17 s per county).
Using 20-80 s/county: 3,143 counties = 17-70 CPU-hours at 300 m, single distance. Five distances (100,300,500,1000,2000) multiply by roughly 5 (buffers are rebuilt each time): 85-350 CPU-hours. 
The buffer+area stage dominates; census, emissions, get_all are seconds. Disk: area_roads300 ~ 0.6 MB per NY county (1.9 MB/62 counties = 0.03 MB; but 3-county file 0.077 MB = 0.026 MB/county) -> ~100 MB per distance nationally;
roads ~0.13 MB/county (NY 8.07 MB/62) -> ~400 MB nationally; tracts ~0.03 MB/county -> ~100 MB. Raw TIGER downloads (roads, tracts) are larger (primary_secondary_roads zip per state, tracts cb zip per state), not measured.
Worst-case batches: TX 254 counties, GA 159 counties: at 20-80 s per county = 1.4-5.6 h (TX), 0.9-3.5 h (GA) per distance, so batch by state and run states in parallel (4 CPUs here).

## What must change to run nationally (functions.R)
- get_state (448): takes ONE state from geoids via data/states.rds (relative path); a multi-state geoid vector returns several rows and breaks tigris calls in get_shapes_counties (462), get_shapes_tracts (477), get_shapes_roads (493). Need a per-state loop or a state parameter.
- get_shapes_buffers (532): remove the global saveRDS(path_shapes_buffers) side effect (~line 553); add dist/state paths.
- get_area_roads (687): already per county; make it resumable per county (checkpoint, cache), parallel via furrr/future; cap geometry complexity.
- get_county_group_values (803), get_all (1540), get_overall (1607): get_overall hardwires data/regions_ny_data.rds and test/area_roads<dist>.rds, run_ny.R paths; get_county_group_values uses a read_rds(path_census_counties) global default; need state-scoped paths and a region table for 3,143 counties.
- retrieve_census2 (167): one state, one year per call; loop over 51 FIPS x tract/county. retrieve_emissions (386) is retired (API_PROXY); use cat_bulk.R retrieve_emissions_bulk (national file, filter by geoid).
- get_emissions_interpolated (775): fine.

## Failures with exact text
- TIGER: `Error : Download failed with both HTTP and FTP; check your internet connection or the status of the Census Bureau website at https://www2.census.gov/geo/tiger/ or ftp://ftp2.census.gov/geo/tiger/.` plus `i HTTP: unused argument (retry_on_failure = TRUE)`; curl: `CONNECT tunnel failed, response 403` (agent proxy: no rule or network setting allows this host).
- NY 14-county proxy: no output in 4 min (stopped by timeout).
Scratch: /tmp/claude-0/-home-user/06edb19c-d93a-534a-a308-3e58a733c5b6/scratchpad/nat/s1/ (step12.R, step3a.R, step3b.R, step3c.R, out/).
