# V-2b receipt: density-warped tile grid (2026-11-20)

Status: **partial, stopped at the 15-minute box.** The warp is implemented and every machine check passes, but state
containment is **21.4%, far below the 60% target**, and upstate New York still partly sits over the warped Great Lakes.
Not accepted by eye. Not committed (orchestrator commits).

## Files (owned, overwritten)
- `national/tile_grid.R`: kept the previous agent's tile set, water-centroid fix, lake-filled mask, largest component,
  boundary-dummy LSAP and checks. Replaced the centroid-only rank pre-step with `kernel_cdf`, `make_warp`, `warp_sfc`
  (one separable monotone warp applied to the outline, the state polygons and the centroids; outline simplified 2 km
  then densified 10 km; warped coordinates mapped back onto the original bbox so the aspect is kept). `mask_cells` and
  `pick_size` take grid origin offsets; `state_ok` tests the tile's cell centre against the MPO's own warped state
  (LEDGER `state`). Fx, Fy = Gaussian-kernel CDF of centroid x / y (bandwidth `bw.nrd0`), rescaled so
  [xmin, xmax] -> [0, 1]. Parse check passes. Run time ~110 s.
- `national/tables/mpo_tiles.csv`: 224 rows, `mpo_id, col, row, cx, cy, disp_cells, w, state_ok`.
- `national/fig/tile_grid_check.png`: left outline + centroids; right tiles (light grey, alpha 0.8, white 0.4 pt
  borders, NY darker) over thin warped state lines.

## Comparison (all 45 candidates: 1 component, 0 enclosed empty cells)
share = state containment; FL/NY = tiles inside own state (of 11 FL, 8 NY); disp in cells; order = strict pairwise.

| w | ox | oy | cell km | cells | share | FL | NY | disp mean | disp max | E-W | N-S |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 186 | 226 | 0.085 | 2 | 0 | 5.31 | 9.30 | 0.972 | 0.934 |
| 0 | 0 | 1/3 | 185 | 228 | 0.089 | 3 | 0 | 5.38 | 9.26 | 0.970 | 0.932 |
| 0 | 0 | 2/3 | 186 | 226 | 0.076 | 1 | 0 | 5.37 | 9.35 | 0.967 | 0.929 |
| 0 | 1/3 | 0 | 185 | 226 | 0.080 | 3 | 0 | 5.29 | 8.91 | 0.965 | 0.921 |
| 0 | 1/3 | 1/3 | 187 | 224 | 0.098 | 6 | 0 | 5.22 | 9.16 | 0.966 | 0.932 |
| 0 | 1/3 | 2/3 | 187 | 224 | 0.085 | 4 | 0 | 5.36 | 9.10 | 0.967 | 0.924 |
| 0 | 2/3 | 0 | 187 | 224 | 0.076 | 4 | 0 | 5.32 | 8.90 | 0.960 | 0.919 |
| 0 | 2/3 | 1/3 | 184 | 226 | 0.071 | 2 | 0 | 5.60 | 9.22 | 0.970 | 0.917 |
| 0 | 2/3 | 2/3 | 186 | 224 | 0.071 | 1 | 0 | 5.50 | 9.02 | 0.969 | 0.924 |
| 0.25 | 0 | 0 | 195 | 224 | 0.103 | 6 | 0 | 4.33 | 7.57 | 0.967 | 0.937 |
| 0.25 | 0 | 1/3 | 190 | 224 | 0.089 | 4 | 1 | 4.52 | 7.96 | 0.973 | 0.930 |
| 0.25 | 0 | 2/3 | 193 | 224 | 0.116 | 7 | 0 | 4.37 | 7.26 | 0.967 | 0.934 |
| 0.25 | 1/3 | 0 | 190 | 227 | 0.116 | 5 | 1 | 4.40 | 7.48 | 0.970 | 0.944 |
| 0.25 | 1/3 | 1/3 | 189 | 232 | 0.107 | 3 | 1 | 4.14 | 7.30 | 0.971 | 0.944 |
| 0.25 | 1/3 | 2/3 | 191 | 226 | 0.112 | 4 | 0 | 4.50 | 7.44 | 0.974 | 0.942 |
| 0.25 | 2/3 | 0 | 193 | 225 | 0.107 | 6 | 0 | 4.39 | 7.40 | 0.968 | 0.937 |
| 0.25 | 2/3 | 1/3 | 190 | 227 | 0.098 | 3 | 0 | 4.43 | 7.64 | 0.972 | 0.937 |
| 0.25 | 2/3 | 2/3 | 193 | 225 | 0.103 | 6 | 0 | 4.42 | 7.21 | 0.968 | 0.929 |
| 0.4 | 0 | 0 | 197 | 224 | 0.125 | 7 | 1 | 3.85 | 6.75 | 0.973 | 0.939 |
| 0.4 | 0 | 1/3 | 193 | 225 | 0.103 | 5 | 1 | 4.00 | 6.92 | 0.974 | 0.942 |
| 0.4 | 0 | 2/3 | 193 | 224 | 0.085 | 0 | 1 | 4.09 | 7.18 | 0.977 | 0.936 |
| 0.4 | 1/3 | 0 | 195 | 224 | 0.134 | 8 | 1 | 3.88 | 7.47 | 0.973 | 0.940 |
| 0.4 | 1/3 | 1/3 | 192 | 229 | 0.121 | 5 | 1 | 3.87 | 6.67 | 0.975 | 0.944 |
| 0.4 | 1/3 | 2/3 | 194 | 224 | 0.103 | 1 | 1 | 4.01 | 6.93 | 0.978 | 0.932 |
| 0.4 | 2/3 | 0 | 193 | 226 | 0.121 | 6 | 1 | 3.93 | 6.75 | 0.976 | 0.946 |
| 0.4 | 2/3 | 1/3 | 193 | 228 | 0.121 | 6 | 1 | 3.75 | 6.90 | 0.969 | 0.952 |
| 0.4 | 2/3 | 2/3 | 196 | 226 | 0.125 | 3 | 1 | 3.73 | 6.58 | 0.973 | 0.947 |
| 0.55 | 0 | 0 | 199 | 225 | 0.134 | 3 | 1 | 3.41 | 6.21 | 0.978 | 0.945 |
| 0.55 | 0 | 1/3 | 198 | 225 | 0.156 | 7 | 2 | 3.38 | 6.25 | 0.977 | 0.951 |
| 0.55 | 0 | 2/3 | 200 | 225 | 0.143 | 5 | 2 | 3.22 | 6.88 | 0.975 | 0.948 |
| 0.55 | 1/3 | 0 | 198 | 224 | 0.134 | 4 | 2 | 3.26 | 5.68 | 0.978 | 0.944 |
| 0.55 | 1/3 | 1/3 | 196 | 229 | 0.170 | 7 | 2 | 3.15 | 6.08 | 0.983 | 0.953 |
| 0.55 | 1/3 | 2/3 | 200 | 224 | 0.129 | 5 | 2 | 3.40 | 6.74 | 0.975 | 0.950 |
| 0.55 | 2/3 | 0 | 196 | 225 | 0.134 | 0 | 1 | 3.47 | 6.25 | 0.983 | 0.948 |
| 0.55 | 2/3 | 1/3 | 198 | 226 | 0.183 | 7 | 2 | 3.16 | 5.92 | 0.977 | 0.952 |
| 0.55 | 2/3 | 2/3 | 199 | 224 | 0.152 | 6 | 1 | 3.31 | 7.01 | 0.974 | 0.946 |
| 0.7 | 0 | 0 | 202 | 224 | 0.156 | 6 | 1 | 3.00 | 5.79 | 0.978 | 0.944 |
| 0.7 | 0 | 1/3 | 201 | 224 | 0.152 | 2 | 1 | 2.98 | 6.55 | 0.979 | 0.947 |
| 0.7 | 0 | 2/3 | 203 | 226 | 0.205 | 8 | 3 | 2.72 | 6.45 | 0.979 | 0.953 |
| 0.7 | 1/3 | 0 | 200 | 224 | 0.147 | 4 | 2 | 2.94 | 6.00 | 0.980 | 0.947 |
| 0.7 | 1/3 | 1/3 | 201 | 226 | 0.156 | 3 | 2 | 2.96 | 6.51 | 0.977 | 0.952 |
| 0.7 | 1/3 | 2/3 | 201 | 225 | 0.174 | 8 | 2 | 2.94 | 5.96 | 0.978 | 0.950 |
| 0.7 | 2/3 | 0 | 200 | 224 | 0.165 | 3 | 1 | 2.89 | 6.42 | 0.981 | 0.957 |
| 0.7 | 2/3 | 1/3 | 199 | 231 | 0.205 | 2 | 2 | 2.54 | 5.66 | 0.982 | 0.960 |
| **0.7** | **2/3** | **2/3** | 203 | 224 | **0.214** | 7 | 3 | 2.70 | 6.13 | 0.981 | 0.956 |

Off-spec probe (origin 0, not shipped; scratch script only), to see whether a stronger warp reaches 60%:

| wx | wy | share | FL | NY | disp mean | E-W | N-S |
|---|---|---|---|---|---|---|---|
| 0.85 | 0.85 | 0.246 | 8 | 3 | 2.25 | 0.984 | 0.963 |
| 1 | 1 | 0.299 | 3 | 2 | 1.98 | 0.981 | 0.963 |
| 0.7 | 0 | 0.156 | 7 | 2 | 3.31 | 0.982 | 0.936 |
| 1 | 0 | 0.272 | 9 | 4 | 2.42 | 0.988 | 0.946 |
| 1 | 0.4 | 0.259 | 9 | 2 | 2.18 | 0.985 | 0.956 |

Share rises with w but tops out near 30% even at w = 1: **a separable (x-then-y) warp cannot reach 60%.** It
equalises the x and y marginals, not the joint density, so the dense North-East corner (east in x but north in y,
where Fy compresses) still gets too few cells.

## Acceptance (shipped: w = 0.70, origin offset 2/3, 2/3 of a cell; cell 203 km in warped space; 224 cells)
- One 4-connected block: **yes** (1). Zero enclosed empty cells: **yes** (0).
- Deterministic: **yes**, two full runs, md5 `5a656302b8238f71fb13a9853cb8b0ad` both times.
- State containment: **21.4%** (target >= 60%: **not met**). FL 7/11, NY 3/8, ME 1/1, MA 2/5, CT 0/6, NH 0/2, RI 0/1.
- Order preserved: E-W **98.1%**, N-S **95.6%** (strict pairs). Displacement: mean **2.70**, max **6.13** cells
  (was 5.28 / 9.30 in V-2).
- Eye check of the PNG: **Florida** now shows as a 2-cell protrusion at the bottom right (better than V-2, still a
  stub). **New England/Maine** reads as a tall column at the top right: recognisable. **New York**: 3 tiles sit in
  warped NY east of the Great Lakes (correct); 4 (36196500, 36197401, 36197402, 36197700) still sit at cols 13-15
  along the warped Michigan/Lake Huron outline, i.e. over the Great Lakes, and NYC (36198201) lands near
  Delaware/Maryland. **Not accepted by eye.**

## Exact next step
Replace the separable warp with a joint (2-D) density warp so the North-East corner gains cells: e.g. a
Gastner-Newman / `cartogram::cartogram_cont` contiguous cartogram of the states weighted by MPO count (+1 so empty
states keep area), then warp the centroids by barycentric interpolation within their state (or move each centroid by
its state's centroid shift). Rasterize the cartogrammed outline as the mask and rerun the same 9 origin offsets.
Alternative cheaper probe: add `state_ok` to the LSAP cost (penalty for a cell outside the MPO's warped state) and
see whether order preservation stays >= 90%.

Cleanup: no processes or containers started; comparison CSV, run-1 CSV and the probe script in the session scratchpad
(`/tmp/claude-0/-home-user/06edb19c-d93a-534a-a308-3e58a733c5b6/scratchpad/v2b/`) only.
