# tile_grid.R: one cohesive, US-shaped block of square tiles, one tile per multi-county MPO (task V-2; ND16).
# A tile is an MPO, not a state; tiles touch; no population sizing. Plan: .contract/national/PLAN_VIZ_AND_CAT.md.
#
# Method
#   1. Tiles = LEDGER MPOs with status done/blocked_cat whose centroid lies in the lower-48 + DC outline.
#   2. Mask = lower-48 + DC (tigris cb states 2022), EPSG:5070. Square cells; the cell size is the one whose count of
#      cells with centre inside the outline is the smallest count >= N tiles.
#   3. Each MPO gets a target position (in cell units). Plain = its centroid. The shipped design blends the centroid
#      with a density-equalised ("rank") position: MPOs are split into grid rows by north-south rank so each row gets
#      exactly as many MPOs as the mask has cells in that row, then laid out west-to-east by rank along that row.
#      This pulls the dense East outward and lets the sparse West fill the empty interior.
#   4. clue::solve_LSAP minimises total squared target-to-cell distance. Surplus cells: dummy rows with cost 0 on
#      boundary cells (fewer than 4 in-mask 4-neighbours) and a large constant elsewhere, then dropped.
# Deterministic: no randomness; same input, same output.
suppressPackageStartupMessages({library(dplyr); library(readr); library(sf); library(ggplot2); library(purrr); library(patchwork)})
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity"); setwd(root)
options(tigris_use_cache = TRUE)

# ---- inputs -------------------------------------------------------------------------------------------------------
get_mask = function(){
  st = tigris::states(cb = TRUE, year = 2022, progress_bar = FALSE)
  st |> filter(!STUSPS %in% c("AK", "HI", "PR", "VI", "GU", "MP", "AS")) |>
    st_transform(5070) |> st_make_valid() |> st_union() |> st_make_valid()
}

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

# ---- grid ---------------------------------------------------------------------------------------------------------
# cells whose centre lies inside the mask, for a given cell size (origin = mask bbox min corner)
mask_cells = function(mask, size){
  bb = st_bbox(mask)
  cells = expand.grid(col = seq_len(ceiling((bb$xmax - bb$xmin) / size)), row = seq_len(ceiling((bb$ymax - bb$ymin) / size))) |>
    as_tibble() |> mutate(x = bb$xmin + (col - 0.5) * size, y = bb$ymin + (row - 0.5) * size)
  inside = st_intersects(st_as_sf(cells, coords = c("x", "y"), crs = 5070), mask, sparse = FALSE)[, 1]
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

# smallest in-mask cell count >= n, searched over cell sizes on a 1 km lattice; ties go to the larger cell
pick_size = function(mask, n, sizes = seq(60e3, 400e3, by = 5e3)){
  bb = st_bbox(mask); area = as.numeric(st_area(mask))
  guess = sqrt(area / n)
  coarse = tibble(size = sizes, k = map_int(sizes, ~ nrow(mask_cells(mask, .x))))
  fine_sizes = seq(round(guess * 0.85 / 1e3) * 1e3, round(guess * 1.1 / 1e3) * 1e3, by = 1e3)
  fine = tibble(size = fine_sizes, k = map_int(fine_sizes, ~ nrow(mask_cells(mask, .x))))
  bind_rows(coarse, fine) |> distinct(size, .keep_all = TRUE) |> filter(k >= n) |> arrange(k, desc(size)) |> slice(1)
}

n_in_mask_neighbours = function(cells){
  key = paste(cells$col, cells$row)
  (paste(cells$col + 1, cells$row) %in% key) + (paste(cells$col - 1, cells$row) %in% key) +
    (paste(cells$col, cells$row + 1) %in% key) + (paste(cells$col, cells$row - 1) %in% key)
}

# density-equalised target: row capacities from the mask, rows filled by north-south rank, columns by west-east rank
rank_targets = function(cen, cells){
  a = rank_layout(cen, cells)
  b = rank_layout(cen |> rename(gx = gy, gy = gx), cells |> rename(col = row, row = col)) |> rename(tcol = trow, trow = tcol)
  a |> select(mpo_id, tcol_a = tcol, trow_a = trow) |> left_join(b |> select(mpo_id, tcol_b = tcol, trow_b = trow), by = "mpo_id") |>
    transmute(mpo_id, tcol = (tcol_a + tcol_b) / 2, trow = (trow_a + trow_b) / 2)
}

# one separable rank layout: rows filled by `gy` rank to the mask's row capacities, then each row by `gx` rank
rank_layout = function(cen, cells){
  cap = cells |> count(row) |> arrange(row)                  # cells per grid row, south to north
  n = nrow(cen); k = nrow(cells)
  # scale capacities to n tiles (surplus k - n removed from rows proportionally, largest remainders)
  quota = cap$n * n / k; base = floor(quota); extra = n - sum(base)
  base[order(-(quota - base), cap$row)[seq_len(extra)]] = base[order(-(quota - base), cap$row)[seq_len(extra)]] + 1
  cen = cen |> arrange(gy, gx, mpo_id) |> mutate(trow = rep(cap$row, base))
  cen |> group_by(trow) |> arrange(gx, gy, mpo_id, .by_group = TRUE) |>
    mutate(tcol = {cs = sort(cells$col[cells$row == trow[1]]); m = n()
                   cs[pmax(1, pmin(length(cs), round((seq_len(m) - 0.5) / m * length(cs) + 0.5)))]}) |>
    ungroup()
}

# ---- the function -------------------------------------------------------------------------------------------------
# cen: tibble mpo_id, cx, cy (EPSG:5070 metres); mask: sfc polygon (EPSG:5070); alpha: 0 = plain geographic targets,
# 1 = fully density-equalised targets; big: dummy cost off the boundary.
get_tile_grid = function(cen, mask, alpha = 0.5, size = NULL, big = 1e6){
  n = nrow(cen)
  if (is.null(size)) size = pick_size(mask, n)$size
  bb = st_bbox(mask)
  cells = mask_cells(mask, size) |> arrange(row, col)
  k = nrow(cells); stopifnot(k >= n)
  cen = cen |> arrange(mpo_id) |> mutate(gx = (cx - bb$xmin) / size + 0.5, gy = (cy - bb$ymin) / size + 0.5)
  rk = rank_targets(cen, cells) |> select(mpo_id, tcol, trow)
  cen = cen |> left_join(rk, by = "mpo_id") |> mutate(tx = (1 - alpha) * gx + alpha * tcol, ty = (1 - alpha) * gy + alpha * trow)
  cost = outer(cen$tx, cells$col, "-")^2 + outer(cen$ty, cells$row, "-")^2
  if (k > n){
    edge = n_in_mask_neighbours(cells) < 4
    dummy = matrix(ifelse(edge, 0, big), nrow = k - n, ncol = k, byrow = TRUE)
    cost = rbind(cost, dummy)
  }
  a = as.integer(clue::solve_LSAP(cost))[seq_len(n)]
  cen |> mutate(col = cells$col[a], row = cells$row[a],
                disp_cells = sqrt((gx - col)^2 + (gy - row)^2)) |>
    select(mpo_id, col, row, cx, cy, disp_cells) |>
    structure(size = size, cells = cells)
}

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
  mask = get_mask()
  cen = get_centroids(led$mpo_id, mask)
  inside = st_intersects(st_as_sf(cen, coords = c("cx", "cy"), crs = 5070), mask, sparse = FALSE)[, 1]
  if (any(!inside)) message("dropped (centroid outside lower-48 + DC): ", paste(cen$mpo_id[!inside], collapse = ", "))
  cen = cen[inside, ]
  sz = pick_size(mask, nrow(cen)); message("tiles: ", nrow(cen), "; cell size: ", sz$size / 1e3, " km; in-mask cells: ", sz$k)

  # compare designs: plain geographic (alpha 0) against density-equalised blends
  alphas = c(0, 0.25, 0.5, 0.75, 1)
  runs = map(alphas, ~ get_tile_grid(cen, mask, alpha = .x, size = sz$size))
  cmp = map2_dfr(alphas, runs, ~ grid_checks(.y) |> mutate(alpha = .x, .before = 1))
  print(cmp, width = Inf)
  write_csv(cmp, file.path(Sys.getenv("TILE_CMP_DIR", tempdir()), "tile_grid_compare.csv"))

  alpha_ship = as.numeric(Sys.getenv("TILE_ALPHA", "0"))
  tg = runs[[match(alpha_ship, alphas)]]
  dir.create("national/tables", showWarnings = FALSE); dir.create("national/fig", showWarnings = FALSE)
  tg |> arrange(mpo_id) |> mutate(cx = round(cx, 1), cy = round(cy, 1), disp_cells = round(disp_cells, 4)) |>
    write_csv("national/tables/mpo_tiles.csv")

  # check figure: left the outline with centroids, right the tile block (NY MPOs darker)
  ny = led$mpo_id[led$state == "NY"]
  ink = "#1f2328"; muted = "#59636e"
  pts = cen |> mutate(ny = mpo_id %in% ny)
  left = ggplot() + geom_sf(data = mask, fill = "#f2f3f5", color = muted, linewidth = 0.25) +
    geom_point(data = pts, aes(cx, cy, color = ny), size = 0.9) + scale_color_manual(values = c(`FALSE` = "#8a9099", `TRUE` = ink), guide = "none") +
    coord_sf(crs = 5070, datum = NA) + labs(title = "MPO centroids", x = NULL, y = NULL) + theme_void(base_size = 8) +
    theme(plot.title = element_text(face = "bold", color = ink))
  til = tg |> mutate(ny = mpo_id %in% ny)
  right = ggplot(til, aes(col, row)) + geom_tile(aes(fill = ny), color = "white", linewidth = 0.4 / ggplot2::.pt) +
    scale_fill_manual(values = c(`FALSE` = "#d4d7dc", `TRUE` = "#59636e"), guide = "none") + coord_equal() +
    labs(title = sprintf("Tile grid (%d MPOs; dark = New York)", nrow(til))) + theme_void(base_size = 8) +
    theme(plot.title = element_text(face = "bold", color = ink))
  ggsave("national/fig/tile_grid_check.png", left | right, width = 10, height = 3.8, dpi = 200, bg = "white")
}
