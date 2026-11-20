# NAT-S2: nationwide county groupings obtainable from this machine (2026-11-20)

Bottom line: the official federal sources (census.gov, ers.usda.gov, bea.gov, BTS/ArcGIS) are ALL blocked by the proxy. The only county-to-CBSA/CSA delineation I could obtain is a LEGACY copy (NBER crosswalk, ~2013-2018 OMB vintage, not 2023) bundled in the CRAN package `totalcensus` 0.6.6. Commuting zones, BEA Economic Areas and MPO boundaries were NOT obtainable.

Denominator: areas.parquet has 3,150 non-PR county rows (3,143 expected; the 7 extra are legacy/changed codes, not diagnosed; CT = 8 old counties). Coverage below is counted over those 3,150 rows; population shares use usdata `county_complete` pop_2019 (8 counties have no pop).

## Comparison table

| # | Grouping | Source URL | Reachable | Format / vintage | Regions | Counties covered | Median / min / max counties per region | New York | Licence |
|---|---|---|---|---|---|---|---|---|---|
| 1a | CBSA (metro+micro), legacy | CRAN `totalcensus_0.6.6.tar.gz` (dict_cbsa), origin nber.org cbsa-fips-county-crosswalk | YES via cran.r-project.org (origin hosts blocked) | .RData, OMB ~2013-2018 (NOT 2023) | 917 (1,167 metro + 641 micro counties) | 1,808 of 3,150 (57%); 94.2% of pop | 1 / 1 / 29 | 17+ CBSAs in NY, mostly single-county; NYC CBSA is 12 counties spanning 3 REDC regions (NYC, Long Island, Hudson Valley) and 3 states | CRAN package licence (check DESCRIPTION); public-domain OMB data |
| 1b | CBSA + rest-of-state nonmetro (complete partition) | derived from 1a | derived | xwalk_cbsa_plus_rest_of_state.csv | 962 (917 CBSA + 45 state remainders) | 3,150 (100%) | 1 / 1 / 126 | 27 regions (26 CBSAs + 1 nonmetro remainder of 10 counties); does NOT resemble REDC 10: 15 are single-county | derived |
| 2 | CSA (combined) | same file (CSA column) | YES (same) | legacy | 166 CSAs | 1,150 of 3,150 (36.5%); 76% of pop | 5 / 2 / 40 | NY CSAs partial; as complete partition (CSA > CBSA > rest of state) 614 regions nationally, NY 16 | same |
| 2b | CSA>CBSA>rest-of-state | derived | derived | xwalk_csa_cbsa_rest_of_state.csv | 614 | 3,150 (100%) | 2 / 1 / 126 | 16 regions | derived |
| 3 | USDA ERS Commuting Zones 2020 | ers.usda.gov (+ /media/ file) | NO (403 CONNECT) | xlsx | ~ 600-700 expected | not obtained | not obtained | not obtained | USDA public domain, cite ERS |
| 4 | BEA Economic Areas | apps.bea.gov/regional/docs/econlist.cfm | NO (403) | - | 179 EAs (published figure, unverified here) | not obtained | not obtained | not obtained | BEA public domain |
| 5 | MPO boundaries (BTS NTAD) | geodata.bts.gov, services.arcgis.com, hub.arcgis.com, data.bts.gov | NO (all 403) | ArcGIS FeatureServer / GeoJSON | ~ 400+ MPOs (published, unverified) | not obtained; overlap, county/pop coverage NOT computed | - | - | NTAD open data; cite BTS NTAD |
| 6a | Census divisions | `areas.parquet` `division` column (CAT registry) | YES | xwalk_census_division.csv | 10 (9 divisions + DC row) | 3,150 (100%) | 322 / 3 / 619 | NY sits in Middle Atlantic with NJ, PA (1 region) | public domain |
| 6b | States | areas.parquet `state` | YES | xwalk_state.csv | 51 | 3,150 | 62 / 1 / 254 | NY = 1 region (REDC would be 10) | public domain |
| 7 | NOAA climate divisions | - | not tried | not county-nested (sub-county polygons) | - | - | - | unsuitable | - |
| 7 | PUMAs | - | not tried | not county-nested (can split or span counties) | - | - | - | unsuitable | - |

## NY detail
REDC: 62 counties, 10 regions (regions_ny_data.rds). CBSA+rest gives 27 regions; the only close analogue is Rochester CBSA (6 counties, all Finger Lakes) and Albany CBSA (5 counties, Capital District / Mohawk Valley). The NYC CBSA (12 counties) merges three REDC regions. The 10-county nonmetro remainder spans North Country (3), Southern Tier (3), and four other REDC regions. So CBSA-based regions are NOT comparable to the REDC definition, and CBSAs are far smaller than REDC regions in many places (median nationally 1 county).

## Blocked hosts (403 "CONNECT tunnel failed")
www2.census.gov, www.census.gov, www.ers.usda.gov, www.bea.gov, apps.bea.gov, geodata.bts.gov, services.arcgis.com, hub.arcgis.com, data.bts.gov, www.bts.gov, catalog.data.gov, www.nber.org, www.dot.gov, data.cdc.gov, www.openstreetmap.org, zenodo.org, osf.io, www.huduser.gov, www.fcc.gov, www.eia.gov, opendata.arcgis.com, www.arcgis.com, data-usdot.opendata.arcgis.com, www.fhwa.dot.gov.
Reachable: api.cat-apps.com, cran.r-project.org, pypi.org, raw.githubusercontent.com, api.github.com (search ok; github.com root returns 400), api.census.gov (reachable but the data endpoints 302 to missing_key.html: needs a Census API key; I did not look for one). With a key, api.census.gov can return the CURRENT county-within-CBSA and CSA hierarchy (`for=county:*&in=metropolitan statistical area/micropolitan statistical area:*&in=state (or part):*`, ACS 2023), which would fix the vintage problem for CBSA/CSA.
Not tried: GitHub raw mirrors of CZ/EA/MPO files (guessing repo names is unreliable; api.github.com code search needs auth).

## Recommendation
(a) Complete partition for a national map: there is no reachable fully-complete source. Best available now: CBSA + rest-of-state nonmetro (xwalk_cbsa_plus_rest_of_state.csv), but 917 CBSAs is far finer than NY's 10 REDC regions, and it rests on a legacy delineation. If the evenness index needs regions of REDC-like size (tens of counties), ERS Commuting Zones 2020 or BEA Economic Areas (179, complete, county-nested, but blocked here) are better fits; ask Tim/infra to allow ers.usda.gov and apps.bea.gov, or fetch them from his machine. Fallback: states (51) or Census divisions are complete but coarse. Do not pick the legacy NBER file for publication without re-checking against the 2023 OMB list1_2023.xlsx.
(b) MPO companion analysis: sound idea, partial coverage by construction (MPOs cover urbanized areas of 50k+ plus planning boundaries, not rural counties; boundaries are not county-aligned and can overlap or span counties). Needs the BTS NTAD MPO layer (blocked here); compute county-to-MPO by largest overlap and report county and population coverage, and treat uncovered counties as "outside MPO". Use the CBSA file as a stand-in only for orientation: metro CBSAs hold 1,167 counties and roughly the same footprint as MPO-covered areas.

## Files (all in /tmp/claude-0/-home-user/06edb19c-d93a-534a-a308-3e58a733c5b6/scratchpad/nat/s2/; columns geoid, region_id, region_name)
- xwalk_cbsa_nber_legacy.csv (1,808 rows, CBSA only; legacy vintage)
- xwalk_cbsa_plus_rest_of_state.csv (3,150 rows; complete)
- xwalk_csa_cbsa_rest_of_state.csv (3,150 rows; complete)
- xwalk_census_division.csv, xwalk_state.csv (3,150 rows each)
- build script: /tmp/claude-0/-home-user/06edb19c-d93a-534a-a308-3e58a733c5b6/scratchpad/nat/s2_build.R; CRAN tarballs in s2/pk/ (data only read with R load(), never executed).
Caveat: 72 Puerto Rico rows in the dict were dropped (PR excluded); several CBSAs span states, so region ids are CBSA-wide while counts per state may be smaller.
