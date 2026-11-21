# V-2c receipt (orchestrator): state penalty test, and the shipped tile grid

- Added an optional state penalty to `get_tile_grid()` (`lambda`: extra squared-cell cost when a cell centre is outside the MPO's own warped state). Searched lambda in {0, 2, 4, 8} x w in {0.55, 0.7} x 9 grid origins.
- Best per (w, lambda), all one block with zero enclosed holes:

| w | lambda | state share | NY in NY | FL in FL | E-W order | N-S order | mean disp | max disp |
|---|---|---|---|---|---|---|---|---|
| 0.55 | 0 | 0.183 | 2 | 7 | 0.977 | 0.952 | 3.16 | 5.92 |
| 0.55 | 8 | 0.353 | 3 | 7 | 0.961 | 0.956 | 3.14 | 6.63 |
| 0.70 | 0 | 0.214 | 3 | 7 | 0.981 | 0.956 | 2.70 | 6.13 |
| 0.70 | 4 | 0.362 | 4 | 2 | 0.972 | 0.959 | 2.54 | 5.66 |
| 0.70 | 8 | 0.438 | 4 | 2 | 0.963 | 0.956 | 2.55 | 5.66 |

- Rejected lambda > 0 by eye: at w 0.70, lambda 8 the New York Metropolitan Transportation Council tile moved into the New England corner, and Florida kept only 2 of 11 tiles. The worst misplacement for the most populous MPO outweighs the containment gain.
- Shipped: w = 0.70, lambda = 0, origin (2/3, 2/3), 203 km cells, 224 tiles (the V-2b layout). NYMTC at col 21, row 9 (Mid-Atlantic coast). Deterministic.
- The 60% state-containment target in the brief was unrealistic at this resolution: one cell is about 200 km, larger than CT, RI, NH and much of NJ, so their MPOs cannot sit inside their own state. Full comparison: `national/tables/tile_grid_compare.csv`.
