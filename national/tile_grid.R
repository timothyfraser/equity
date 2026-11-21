# tile_grid.R: one cohesive, US-shaped block of square tiles, one tile per multi-county MPO (task V-2; ND16).
# A tile is an MPO, not a state; tiles touch; no population sizing. Plan: .contract/national/PLAN_VIZ_AND_CAT.md.
#
# Method (V-2b)
#   1. Tiles = LEDGER MPOs with status done/blocked_cat whose centroid lies in the lower-48 + DC outline.
#   2. Density warp. A uniform mask gives the sparse West as many cells per km2 as the dense East, so eastern MPOs
#      are pushed inland. One separable monotone warp is applied to the outline, the state polygons AND the
#      centroids alike: x' = (1 - w) x_norm + w Fx(x), y' = (1 - w) y_norm + w Fy(y), where x_norm is x rescaled to
#      [0, 1] over the outline bbox and Fx is a Gaussian-kernel CDF of the centroid x values rescaled to map
#      [xmin, xmax] onto [0, 1] (same for y). The outline is densified to 10 km first so every vertex is warped by the
#      same functions; x' and y' are mapped back onto the original bbox, so the warped outline keeps its aspect.
#   3. Mask = the warped outline. Square cells; for each grid origin offset the cell size is the one whose count of
#      cells with centre inside the warped outline is the smallest count >= N (lake cells filled, largest
#      4-connected component kept).
#   4. clue::solve_LSAP minimises total squared centroid-to-cell distance (warped space). Surplus cells: dummy rows
#      with cost 0 on boundary cells (fewer than 4 in-mask 4-neighbours) and a large constant elsewhere, then dropped.
#   5. Candidates w x origin are scored by state containment (share of MPOs whose cell centre lies in their own
#      warped state), subject to one block, zero holes and order preservation >= 0.90 both ways.
# Deterministic: no randomness; same input, same output.
suppressPackageStartupMessages({library(dplyr); library(readr); library(sf); library(ggplot2); library(purrr); library(patchwork)})
root = Sys.getenv("EQUITY_ROOT", normalizePath(if (file.exists("index/functions.R")) "." else "..")); setwd(root)
options(tigris_use_cache = TRUE)

# ---- inputs -------------------------------------------------------------------------------------------------------
get_states = function(){
  tigris::states(cb = TRUE, year = 2022, progress_bar = FALSE) |>
    filter(!STUSPS %in% c("AK", "HI", "PR", "VI", "GU", "MP", "AS")) |>
    st_transform(5070) |> st_make_valid() |> select(state = STUSPS) |> arrange(state)
}

get_mask = function(states) states |> st_union() |> st_make_valid()

get_centroids = function(ids, mask){
  map_dfr(ids, function(id){
    f = file.path("index/cache/national/mpo", paste0(id, ".geojson"))
    if (!file.exists(f)){                                 # re-fetch (cached) from inside index/
      owd = setwd(file.path(root, "index")); on.exit(setwd(owd))
      source("functions.R"); source("../national/pilot/pilot_functions.R"); get_mpo_polygon(id)
    }
    g = st_read(f, quiet = TRUE) |> st_make_valid() |> st_transform(5070) |> st_union()
    xy = suppressWarnings(st_coordinates(st_centroid(g)))
    if (!isTRUE(st_intersects(st_centroid(g), g, sparse = FALSE)[1, 1])) xy = suppressWarnings(st_coordinates(st_point_on_surface(g)))
    # a coastal MPO polygon includes water: if the centroid lands off the land outline, use a point on its land part
    if (!isTRUE(st_intersects(st_sfc(st_point(xy[1, 1:2]), crs = 5070), mask, sparse = FALSE)[1, 1])){
      land = suppressWarnings(st_intersection(g, mask))
      if (length(land) && !all(st_is_empty(land))) xy = suppressWarnings(st_coordinates(st_point_on_surface(st_union(land))))
    }
    tibble(mpo_id = id, cx = xy[1, 1], cy = xy[1, 2])
  })
}

# ---- density warp -------------------------------------------------------------------------------------------------
# monotone map of [lo, hi] onto [0, 1]: Gaussian-kernel CDF of v (bandwidth = bw_mult * bw.nrd0), rescaled at the ends
kernel_cdf = function(v, lo, hi, bw_mult = 1){
  h = bw_mult * bw.nrd0(v)
  f = function(x) vapply(x, function(z) mean(pnorm((z - v) / h)), numeric(1))
  f_lo = f(lo); f_hi = f(hi)
  function(x) (f(x) - f_lo) / (f_hi - f_lo)
}

# warp functions for weight w; bb = outline bbox; cen = centroid tibble (cx, cy). Output in metres over the same bbox.
make_warp = function(cen, bb, w){
  W = bb[["xmax"]] - bb[["xmin"]]; H = bb[["ymax"]] - bb[["ymin"]]
  Fx = kernel_cdf(cen$cx, bb[["xmin"]], bb[["xmax"]]); Fy = kernel_cdf(cen$cy, bb[["ymin"]], bb[["ymax"]])
  list(x = function(x) bb[["xmin"]] + W * ((1 - w) * (x - bb[["xmin"]]) / W + w * Fx(x)),
       y = function(y) bb[["ymin"]] + H * ((1 - w) * (y - bb[["ymin"]]) / H + w * Fy(y)))
}

# apply a warp to every vertex of an sfc (densified beforehand so the warp acts on a fine outline)
warp_sfc = function(g, wp){
  f = function(m){ m[, 1] = wp$x(m[, 1]); m[, 2] = wp$y(m[, 2]); m }
  out = lapply(g, function(p) structure(rapply(unclass(p), f, classes = "matrix", how = "replace"), class = class(p)))
  st_make_valid(st_sfc(out, crs = st_crs(g)))
}

# ---- grid ---------------------------------------------------------------------------------------------------------
# cells whose centre lies inside the mask, for a cell size and an origin offset (fractions of a cell, ox and oy)
cell_origin = function(mask, size, ox = 0, oy = 0){
  bb = st_bbox(mask); c(x0 = bb[["xmin"]] - ox * size, y0 = bb[["ymin"]] - oy * size)
}

mask_cells = function(mask, size, ox = 0, oy = 0){
  bb = st_bbox(mask); o = cell_origin(mask, size, ox, oy)
  cells = expand.grid(col = seq_len(ceiling((bb$xmax - o[["x0"]]) / size)), row = seq_len(ceiling((bb$ymax - o[["y0"]]) / size))) |>
    as_tibble() |> mutate(x = o[["x0"]] + (col - 0.5) * size, y = o[["y0"]] + (row - 0.5) * size)
  inside = lengths(st_intersects(st_as_sf(cells, coords = c("x", "y"), crs = st_crs(mask)), mask)) > 0
  keep = inside | enclosed(cells$col, cells$row, inside)   # a lake cell ringed by land is part of the block
  cells = cells[keep, ]
  cells[largest_component(cells$col, cells$row), ]          # an island cell cut off by a 4-step gap is dropped
}

largest_component = function(col, row){
  key = paste(col, row); id = rep(0L, length(key)); comp = 0L
  for (i in seq_along(key)) if (id[i] == 0L){
    comp = comp + 1L; id[i] = comp; stack = i
    while (length(stack)){
      j = stack[1]; stack = stack[-1]
      nb = match(paste(col[j] + c(1, -1, 0, 0), row[j] + c(0, 0, 1, -1)), key); nb = nb[!is.na(nb) & id[nb] == 0L]
      id[nb] = comp; stack = c(stack, nb)
    }
  }
  id == as.integer(names(which.max(table(id))))
}

# TRUE for cells of the full (col, row) lattice that are not in `occ` and cannot reach the outside by 4-steps
enclosed = function(col, row, occ){
  box = expand.grid(col = (min(col) - 1):(max(col) + 1), row = (min(row) - 1):(max(row) + 1))
  bkey = paste(box$col, box$row); okey = paste(col, row)[occ]
  empty = !bkey %in% okey; out = rep(FALSE, nrow(box)); out[1] = TRUE; stack = 1
  while (length(stack)){
    j = stack[1]; stack = stack[-1]
    nb = match(paste(box$col[j] + c(1, -1, 0, 0), box$row[j] + c(0, 0, 1, -1)), bkey); nb = nb[!is.na(nb) & empty[nb] & !out[nb]]
    out[nb] = TRUE; stack = c(stack, nb)
  }
  hole = bkey[empty & !out]
  paste(col, row) %in% hole
}

# smallest in-mask cell count >= n, searched on a 1 km lattice around sqrt(area / n); ties go to the larger cell
pick_size = function(mask, n, ox = 0, oy = 0){
  guess = sqrt(as.numeric(st_area(mask)) / n)
  sizes = seq(round(guess * 0.88 / 1e3) * 1e3, round(guess * 1.08 / 1e3) * 1e3, by = 1e3)
  tibble(size = sizes, k = map_int(sizes, ~ nrow(mask_cells(mask, .x, ox, oy)))) |>
    filter(k >= n) |> arrange(k, desc(size)) |> slice(1)
}

n_in_mask_neighbours = function(cells){
  key = paste(cells$col, cells$row)
  (paste(cells$col + 1, cells$row) %in% key) + (paste(cells$col - 1, cells$row) %in% key) +
    (paste(cells$col, cells$row + 1) %in% key) + (paste(cells$col, cells$row - 1) %in% key)
}

# ---- the function -------------------------------------------------------------------------------------------------
# cen: tibble mpo_id, cx, cy (EPSG:5070 metres, unwarped) plus wx, wy (warped); mask: warped outline (sfc);
# big: dummy cost off the boundary.
get_tile_grid = function(cen, mask, size, ox = 0, oy = 0, big = 1e6, wstates = NULL, lambda = 0){
  n = nrow(cen); o = cell_origin(mask, size, ox, oy)
  cells = mask_cells(mask, size, ox, oy) |> arrange(row, col)
  k = nrow(cells); stopifnot(k >= n)
  cen = cen |> arrange(mpo_id) |> mutate(gx = (wx - o[["x0"]]) / size + 0.5, gy = (wy - o[["y0"]]) / size + 0.5)
  cost = outer(cen$gx, cells$col, "-")^2 + outer(cen$gy, cells$row, "-")^2
  # state penalty (V-2c): extra cost lambda when the cell centre is not inside the MPO's own warped state
  if (lambda > 0 && !is.null(wstates)){
    hit = st_intersects(st_as_sf(cells, coords = c("x", "y"), crs = st_crs(wstates)), wstates)
    cell_state = vapply(hit, function(i) if (length(i)) wstates$state[i[1]] else NA_character_, character(1))
    cost = cost + lambda * outer(cen$state, cell_state, function(a, b) as.numeric(is.na(b) | a != b))
  }
  if (k > n){
    edge = n_in_mask_neighbours(cells) < 4
    cost = rbind(cost, matrix(ifelse(edge, 0, big), nrow = k - n, ncol = k, byrow = TRUE))
  }
  a = as.integer(clue::solve_LSAP(cost))[seq_len(n)]
  cen |> mutate(col = cells$col[a], row = cells$row[a], px = cells$x[a], py = cells$y[a],
                disp_cells = sqrt((gx - col)^2 + (gy - row)^2)) |>
    select(mpo_id, state, col, row, cx, cy, px, py, disp_cells) |>
    structure(size = size, origin = o, cells = cells)
}

# TRUE where the tile's cell centre lies inside the MPO's own (warped) state polygon
state_ok = function(tg, wstates){
  pts = st_as_sf(tg, coords = c("px", "py"), crs = st_crs(wstates))
  hit = st_intersects(pts, wstates)
  map2_lgl(hit, tg$state, ~ tg_in(.x, .y, wstates$state))
}
tg_in = function(idx, st, names) st %in% names[idx]

# ---- acceptance metrics ------------------------------------------------------------------------------------------
grid_checks = function(tg){
  key = paste(tg$col, tg$row)
  # 4-connected components (flood fill)
  seen = rep(FALSE, nrow(tg)); comp = 0
  for (i in seq_len(nrow(tg))) if (!seen[i]){
    comp = comp + 1; stack = i; seen[i] = TRUE
    while (length(stack)){
      j = stack[1]; stack = stack[-1]
      nb = match(paste(tg$col[j] + c(1, -1, 0, 0), tg$row[j] + c(0, 0, 1, -1)), key); nb = nb[!is.na(nb) & !seen[nb]]
      seen[nb] = TRUE; stack = c(stack, nb)
    }
  }
  # enclosed empty cells: empty cells in the padded bbox not reachable from outside
  box = expand.grid(col = (min(tg$col) - 1):(max(tg$col) + 1), row = (min(tg$row) - 1):(max(tg$row) + 1))
  bkey = paste(box$col, box$row); empty = !bkey %in% key; out = rep(FALSE, nrow(box))
  out[1] = TRUE; stack = 1
  while (length(stack)){
    j = stack[1]; stack = stack[-1]
    nb = match(paste(box$col[j] + c(1, -1, 0, 0), box$row[j] + c(0, 0, 1, -1)), bkey); nb = nb[!is.na(nb) & empty[nb] & !out[nb]]
    out[nb] = TRUE; stack = c(stack, nb)
  }
  pairs = combn(nrow(tg), 2)
  ord = function(g, t){ dg = sign(g[pairs[1, ]] - g[pairs[2, ]]); dt = sign(t[pairs[1, ]] - t[pairs[2, ]])
    c(strict = mean(dg[dt != 0] == dt[dt != 0]), not_reversed = mean(dg * dt >= 0)) }
  ew = ord(tg$cx, tg$col); ns = ord(tg$cy, tg$row)
  tibble(n = nrow(tg), components = comp, enclosed_empty = sum(empty & !out),
         disp_mean = mean(tg$disp_cells), disp_max = max(tg$disp_cells),
         ew_strict = ew[["strict"]], ew_not_reversed = ew[["not_reversed"]],
         ns_strict = ns[["strict"]], ns_not_reversed = ns[["not_reversed"]])
}

# ---- script -------------------------------------------------------------------------------------------------------
if (sys.nframe() == 0L){
  led = read_csv("national/LEDGER.csv", show_col_types = FALSE, col_types = cols(mpo_id = "c", .default = "c")) |>
    filter(status %in% c("done", "blocked_cat"), state != "PR")
  states = get_states(); mask = get_mask(states)
  cen = get_centroids(led$mpo_id, mask)
  inside = st_intersects(st_as_sf(cen, coords = c("cx", "cy"), crs = 5070), mask, sparse = FALSE)[, 1]
  if (any(!inside)) message("dropped (centroid outside lower-48 + DC): ", paste(cen$mpo_id[!inside], collapse = ", "))
  cen = cen[inside, ] |> left_join(led |> select(mpo_id, state), by = "mpo_id")
  bb = st_bbox(mask)
  # simplify (2 km) then densify (10 km) once; every candidate warps these same vertices
  mask_d = mask |> st_simplify(dTolerance = 2e3) |> st_segmentize(10e3)
  states_d = states |> st_simplify(dTolerance = 2e3) |> st_segmentize(10e3)

  # V-2b searched w in {0, .25, .4, .55, .7} (lambda 0); best w were .55 and .7. V-2c adds the state penalty lambda.
  # lambda > 0 tested 2026-11-20 (receipt V-2c): containment rose to 0.44 at lambda 8, but the NYC metro tile moved
  # into New England, so the shipped grid uses lambda = 0 (V-2b layout). Set lambdas = c(0, 2, 4, 8) to rerun the test.
  ws = c(0.55, 0.7); offs = c(0, 1/3, 2/3); lambdas = c(0)
  grid = expand.grid(oy = offs, ox = offs, w = ws, lambda = lambdas) |> as_tibble() |> select(w, lambda, ox, oy)
  runs = pmap(grid, function(w, lambda, ox, oy){
    wp = make_warp(cen, bb, w)
    wmask = warp_sfc(mask_d, wp); wst = st_sf(state = states_d$state, geometry = warp_sfc(st_geometry(states_d), wp))
    cw = cen |> mutate(wx = wp$x(cx), wy = wp$y(cy))
    sz = pick_size(wmask, nrow(cw), ox, oy)
    tg = get_tile_grid(cw, wmask, sz$size, ox, oy, wstates = wst, lambda = lambda)
    tg$state_ok = state_ok(tg, wst)
    list(tg = tg, wmask = wmask, wst = wst, size = sz$size, k = sz$k)
  })
  cmp = map2_dfr(seq_len(nrow(grid)), runs, function(i, r){
    tg = r$tg
    grid[i, ] |> mutate(size_km = r$size / 1e3, cells = r$k, state_share = mean(tg$state_ok),
                        n_FL = sum(tg$state == "FL"), FL_ok = sum(tg$state_ok[tg$state == "FL"]),
                        NY_ok = sum(tg$state_ok[tg$state == "NY"]), n_NY = sum(tg$state == "NY")) |>
      bind_cols(grid_checks(tg) |> select(-n))
  })
  print(cmp, n = Inf, width = Inf)
  write_csv(cmp, file.path(Sys.getenv("TILE_CMP_DIR", tempdir()), "tile_grid_compare.csv"))

  best = cmp |> mutate(i = row_number()) |>
    filter(components == 1, enclosed_empty == 0, ew_strict >= 0.9, ns_strict >= 0.9) |>
    arrange(desc(state_share), disp_mean, lambda, w, ox, oy) |> slice(1)
  stopifnot(nrow(best) == 1)
  r = runs[[best$i]]; tg = r$tg
  message(sprintf("chosen: w = %.2f, lambda = %g, ox = %.3f, oy = %.3f, cell %g km, state share %.3f", best$w, best$lambda, best$ox, best$oy, best$size_km, best$state_share))
  dir.create("national/tables", showWarnings = FALSE); dir.create("national/fig", showWarnings = FALSE)
  tg |> arrange(mpo_id) |> mutate(cx = round(cx, 1), cy = round(cy, 1), disp_cells = round(disp_cells, 4), w = best$w, lambda = best$lambda) |>
    select(mpo_id, col, row, cx, cy, disp_cells, w, lambda, state_ok) |>
    write_csv("national/tables/mpo_tiles.csv")

  # check figure: left the outline with centroids, right the tile block over the warped state lines (NY darker)
  ink = "#1f2328"; muted = "#59636e"
  pts = cen |> mutate(ny = state == "NY")
  left = ggplot() + geom_sf(data = mask, fill = "#f2f3f5", color = muted, linewidth = 0.25) +
    geom_point(data = pts, aes(cx, cy, color = ny), size = 0.9) + scale_color_manual(values = c(`FALSE` = "#8a9099", `TRUE` = ink), guide = "none") +
    coord_sf(crs = 5070, datum = NA) + labs(title = "MPO centroids", x = NULL, y = NULL) + theme_void(base_size = 8) +
    theme(plot.title = element_text(face = "bold", color = ink))
  o = attr(tg, "origin"); s = r$size
  to_cells = function(g) st_set_crs((st_set_crs(g, NA) - c(o[["x0"]], o[["y0"]])) / s + c(0.5, 0.5), NA)
  wst_cells = st_sf(geometry = to_cells(st_geometry(r$wst)))
  til = tg |> mutate(ny = state == "NY")
  right = ggplot() + geom_sf(data = wst_cells, fill = NA, color = "#9aa0a8", linewidth = 0.2) +
    geom_tile(data = til, aes(col, row, fill = ny), color = "white", linewidth = 0.4 / ggplot2::.pt, alpha = 0.8) +
    scale_fill_manual(values = c(`FALSE` = "#c9cdd3", `TRUE` = "#3d444d"), guide = "none") + coord_sf(datum = NA) +
    labs(title = sprintf("Tile grid (%d MPOs; w = %.2f; dark = New York; lines = warped states)", nrow(til), best$w), x = NULL, y = NULL) +
    theme_void(base_size = 8) + theme(plot.title = element_text(face = "bold", color = ink))
  ggsave("national/fig/tile_grid_check.png", left | right, width = 11, height = 4.2, dpi = 200, bg = "white")
}
