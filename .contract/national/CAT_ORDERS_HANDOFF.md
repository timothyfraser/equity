# Hand-off to the CAT dashboard session: 61 county runs for 2022

Paste everything below the line into Tim's local CAT session (catdashboard repo). Written 2026-11-20 by the equity-paper session, which cannot place orders: it has no CAT sign-in token, and peer messaging cannot reach a session on Tim's machine.

---

**Task: place and publish 61 default-input Cloud MOVES county runs for year 2022, then rebuild the public objects.**

Why: the equity paper's national MPO ranking (repo `timothyfraser/equity`, `national/LEDGER.md`) and its New York case study need a 2022 value for every county. In the published cube (manifest `MANIFEST-e2ccfae4.tsv`) these 61 counties have none: 37 have only a 2020 run (nothing to interpolate 2022 from), and 24 New York counties lack 2022 (the paper interpolates them). No Puerto Rico (Tim, 2026-11-20).

Counties (year 2022, default inputs, no custom tables):

```
35035 35055 46031 46041 46051 46061 46071 46081 46089 46101 46109 46119 46129 51029 51041 51051 51065 51077 51091 51115 51133 51173 51199 51678 51740 51760 51810 54015 54025 54035 54045 54055 54065 54075 54085 54095 54105 36019 36025 36027 36031 36033 36039 36041 36047 36053 36057 36059 36063 36069 36075 36077 36081 36083 36087 36091 36093 36105 36111 36113 36121
```

| geoid | county | state | why |
|---|---|---|---|
| 35035 | Otero County | NM | only a 2020 run |
| 35055 | Taos County | NM | only a 2020 run |
| 46031 | Corson County | SD | only a 2020 run |
| 46041 | Dewey County | SD | only a 2020 run |
| 46051 | Grant County | SD | only a 2020 run |
| 46061 | Hanson County | SD | only a 2020 run |
| 46071 | Jackson County | SD | only a 2020 run |
| 46081 | Lawrence County | SD | only a 2020 run |
| 46089 | McPherson County | SD | only a 2020 run |
| 46101 | Moody County | SD | only a 2020 run |
| 46109 | Roberts County | SD | only a 2020 run |
| 46119 | Sully County | SD | only a 2020 run |
| 46129 | Walworth County | SD | only a 2020 run |
| 51029 | Buckingham County | VA | only a 2020 run |
| 51041 | Chesterfield County | VA | only a 2020 run |
| 51051 | Dickenson County | VA | only a 2020 run |
| 51065 | Fluvanna County | VA | only a 2020 run |
| 51077 | Grayson County | VA | only a 2020 run |
| 51091 | Highland County | VA | only a 2020 run |
| 51115 | Mathews County | VA | only a 2020 run |
| 51133 | Northumberland County | VA | only a 2020 run |
| 51173 | Smyth County | VA | only a 2020 run |
| 51199 | York County | VA | only a 2020 run |
| 51678 | Lexington city | VA | only a 2020 run |
| 51740 | Portsmouth city | VA | only a 2020 run |
| 51760 | Richmond city | VA | only a 2020 run |
| 51810 | Virginia Beach city | VA | only a 2020 run |
| 54015 | Clay County | WV | only a 2020 run |
| 54025 | Greenbrier County | WV | only a 2020 run |
| 54035 | Jackson County | WV | only a 2020 run |
| 54045 | Logan County | WV | only a 2020 run |
| 54055 | Mercer County | WV | only a 2020 run |
| 54065 | Morgan County | WV | only a 2020 run |
| 54075 | Pocahontas County | WV | only a 2020 run |
| 54085 | Ritchie County | WV | only a 2020 run |
| 54095 | Tyler County | WV | only a 2020 run |
| 54105 | Wirt County | WV | only a 2020 run |
| 36019 | Clinton | NY | New York 2022 missing |
| 36025 | Delaware | NY | New York 2022 missing |
| 36027 | Dutchess | NY | New York 2022 missing |
| 36031 | Essex | NY | New York 2022 missing |
| 36033 | Franklin | NY | New York 2022 missing |
| 36039 | Greene | NY | New York 2022 missing |
| 36041 | Hamilton | NY | New York 2022 missing |
| 36047 | Kings | NY | New York 2022 missing |
| 36053 | Madison | NY | New York 2022 missing |
| 36057 | Montgomery | NY | New York 2022 missing |
| 36059 | Nassau | NY | New York 2022 missing |
| 36063 | Niagara | NY | New York 2022 missing |
| 36069 | Ontario | NY | New York 2022 missing |
| 36075 | Oswego | NY | New York 2022 missing |
| 36077 | Otsego | NY | New York 2022 missing |
| 36081 | Queens | NY | New York 2022 missing |
| 36083 | Rensselaer | NY | New York 2022 missing |
| 36087 | Rockland | NY | New York 2022 missing |
| 36091 | Saratoga | NY | New York 2022 missing |
| 36093 | Schenectady | NY | New York 2022 missing |
| 36105 | Sullivan | NY | New York 2022 missing |
| 36111 | Ulster | NY | New York 2022 missing |
| 36113 | Warren | NY | New York 2022 missing |
| 36121 | Wyoming | NY | New York 2022 missing |

Steps (follow your repo's own procedure where it differs; Tim approved placing all 61 at once):
1. For each geoid, skip it if an order for that county and 2022 already exists (`GET /cat-api/orders?geoid=<g>&year=2022`). Otherwise `POST /cat-api/orders` with body `{"geoid": "<g>", "year": 2022}` (header `X-Movesai-Auth: Bearer <token>`, never `Authorization`). Record each order id in a list.
2. When each run finishes, publish it: `POST /cat-api/orders/<id>/publish` with `{"if_absent": true}`. A 409 `publish_sanity_block` goes to Tim, not overridden.
3. Run the publish-queue drain (`cat-drain-publish-queue`) so `detail/<geoid>.parquet`, `year/2022.parquet` and a new `MANIFEST-*.tsv` are published.
4. Check: `curl -s https://api.cat-apps.com/objects/LATEST` names a manifest newer than `MANIFEST-e2ccfae4.tsv`, and `year/2022.parquet` has `by == 16` rows for pollutant 110 for all 61 geoids.
5. Tell Tim the new manifest name and any county that failed or was blocked.

After that, the equity session runs `bash national/run_national.sh` (it picks up every MPO that was blocked) and rebuilds the New York results.
