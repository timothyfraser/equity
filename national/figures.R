# figures.R: four-panel national (U-4 layout, ND24-ND25) MPO figure (ND15-ND20, task V-3). Run from the repo root.
# Output: national/fig/mpo_national.png. Every printed number comes from national/results_national.json
# or national/tables/mpo_wide.csv.
suppressPackageStartupMessages({library(ragg); library(dplyr); library(readr); library(ggplot2); library(patchwork); library(jsonlite); library(stringr)})
root = Sys.getenv("EQUITY_ROOT", getwd()); setwd(root)
wide = read_csv("national/tables/mpo_wide.csv", show_col_types = FALSE, col_types = cols(mpo_id = "c"))
tiles = read_csv("national/tables/mpo_tiles.csv", show_col_types = FALSE, col_types = cols(mpo_id = "c")) |> select(mpo_id, col, row)
js = read_json("national/results_national.json")
d = wide |> mutate(kg = emissions_rate_mpo * 1000, lkg = log10(kg))   # lm on log10(kg) = same fit as y ~ log(kg)
tl = tiles |> left_join(d |> select(mpo_id, race, income), by = "mpo_id")
blocked = tl |> filter(is.na(race))

ink = "#1f2328"; muted = "#59636e"
hue = c(race = "#6a00a8", income = "#b12a90"); pale = c(race = "#f4eef8", income = "#f8eef4")
nm = c(race = "Race/ethnicity", income = "Income")
lo = floor(min(d$race, d$income) * 20) / 20; lo = min(lo, 0.70)   # shared scale, 0.70-1.00 unless data fall below
ext = function(v, w) js$extremes[[v]][[w]]
ext_tbl = function(v) bind_rows(lapply(c("min", "max"), function(w) tibble(
  mpo_id = ext(v, w)$mpo_id$value, name = ext(v, w)$mpo_name$value, state = ext(v, w)$state$value, val = ext(v, w)$value$value)))
base_theme = function() theme(plot.title = element_text(face = "bold", size = 7, color = ink, hjust = 0),
  plot.subtitle = element_text(color = muted, size = 6.5), text = element_text(color = ink),
  plot.margin = margin(4, 4, 4, 4))

wrap_name = function(x) x |> str_replace_all("-", "- ") |> str_wrap(28) |> str_replace_all("- (?=[^\n])", "-")
beta = intToUtf8(946)   # Greek beta

# Tile text colour: whichever of white / ink has the higher WCAG contrast against the tile's ACTUAL fill
# colour (the same palette and limits as the map's fill scale), so no hand-picked cut-off.
rel_lum = function(col){
  rgb = grDevices::col2rgb(col) / 255
  lin = ifelse(rgb <= 0.03928, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4)
  as.numeric(0.2126 * lin[1, ] + 0.7152 * lin[2, ] + 0.0722 * lin[3, ])
}
text_col = function(fill){
  l = rel_lum(fill); l_ink = rel_lum(ink)
  if_else((1.05) / (l + 0.05) > (l + 0.05) / (l_ink + 0.05), "white", ink)
}

tile_map = function(v, sub = NULL){
  xr = range(tiles$col); rr = range(tiles$row); med_row = median(tiles$row)
  # shared 0.70-1.00 scale; fill colour of every tile computed from the same palette the legend uses
  pal = scales::col_numeric(c(hue[[v]], pale[[v]]), domain = c(lo, 1))
  t = tl |> filter(!is.na(.data[[v]])) |> mutate(fill = pal(.data[[v]]), tcol = text_col(fill)) |>
    left_join(wide |> select(mpo_id, state), by = "mpo_id")
  # Extremes + the on-the-line case (ND33): label ABOVE the block if the tile is above the median row, else BELOW.
  hw = 3.6   # half label width in columns at this panel size (labels about 7 columns wide); clamps labels inside the panel
  ty = js$typical[[v]]
  tp = tibble(mpo_id = ty$mpo_id$value, name = ty$mpo_name$value, state = ty$state$value, val = ty$value$value)
  e = bind_rows(ext_tbl(v) |> mutate(kind = "extreme"), tp |> mutate(kind = "typical")) |> left_join(tiles, by = "mpo_id") |>
    mutate(above = row > med_row, lab = paste0(wrap_name(paste0(name, ", ", state)), "\n(", sprintf("%.3f", val), ")"),
           lx = pmin(pmax(col, xr[1] - 0.5 + hw), xr[2] + 0.5 - hw), gap = 2 * hw + 0.3)
  # the typical case goes to the other side if its side would collide with an extreme's label there
  ti = which(e$kind == "typical"); ex = e[e$kind == "extreme", ]
  if (any(ex$above == e$above[ti] & abs(ex$lx - e$lx[ti]) < e$gap[ti])) e$above[ti] = !e$above[ti]
  # on each side, spread labels apart (sorted by column), then shift the group back inside the panel
  spread = function(x, gap, lo_b, hi_b){
    o = order(x); y = x[o]
    for (i in seq_along(y)[-1]) y[i] = max(y[i], y[i - 1] + gap)
    if (max(y) > hi_b) y = y - (max(y) - hi_b)
    if (min(y) < lo_b) y = y + (lo_b - min(y))
    x[o] = y; x
  }
  for (sd in c(TRUE, FALSE)){ i = which(e$above == sd); if (length(i) > 1) e$lx[i] = spread(e$lx[i], e$gap[i][1], xr[1] - 0.5 + hw, xr[2] + 0.5 - hw) }
  e = e |> group_by(above) |> mutate(stag = (rank(col, ties.method = "first") - 1) * 0.35) |> ungroup() |>
    mutate(ly = if_else(above, rr[2] + 1.6, rr[1] - 1.6), y0 = if_else(above, row + 0.5, row - 0.5),
           y1 = if_else(above, ly - 0.8 - stag, ly + 0.8 + stag))
  ee = e |> filter(kind == "extreme"); et = e |> filter(kind == "typical")
  # reserve the same label bands above and below on every map, so the two maps come out the same size
  y_lo = rr[1] - 2.5; y_hi = rr[2] + 2.5   # leader ends just short of the text
  ggplot() +
    geom_tile(data = t, aes(col, row, fill = .data[[v]]), color = "white", linewidth = 0.3, width = 1, height = 1) +
    geom_text(data = t, aes(col, row, label = state, color = I(tcol)), size = 1.25, lineheight = 0.9) +   # 1.25 mm = about 3.6 pt: fits two letters in a square tile with the maps side by side
    geom_tile(data = blocked, aes(col, row), fill = "white", color = "#8b949e", linewidth = 0.35, width = 0.82, height = 0.82) +
    geom_tile(data = ee, aes(col, row), fill = NA, color = "black", linewidth = 0.6, width = 1, height = 1) +
    geom_tile(data = et, aes(col, row), fill = NA, color = "black", linewidth = 0.6, linetype = "22", width = 1, height = 1) +   # on-the-line case: dashed outline
    # leader runs along the white gap at the tile's right edge (x = col + 0.5), so it never covers a state label,
    # then turns to the label; no halo needed
    geom_segment(data = e, aes(x = col + 0.5, xend = col + 0.5, y = y0, yend = y1), linewidth = 0.3, color = "black") +
    geom_segment(data = e, aes(x = col + 0.5, xend = lx, y = y1, yend = y1), linewidth = 0.3, color = "black") +
    geom_text(data = e, aes(x = lx, y = ly, label = lab), size = 1.7, color = ink, lineheight = 0.9, vjust = 0.5) +
    scale_fill_gradient(low = hue[[v]], high = pale[[v]], limits = c(lo, 1), name = paste(nm[[v]], "equity index"),
                        guide = guide_colorbar(barwidth = 7, barheight = 0.4, ticks = FALSE, title.position = "top")) +
    # no side padding: the block fills the width; 3 rows above and below hold the extremes labels
    # square tiles (Tim, 2026-11-20: "Make each tile a square in the map, not a rectangle")
    coord_fixed(ratio = 1, xlim = xr + c(-0.5, 0.5), ylim = c(y_lo, y_hi), expand = FALSE, clip = "off") +   # labels near an edge may run into the margin
    labs(title = paste(nm[[v]], "equity index per metropolitan planning organization"), subtitle = sub,
         caption = if (nrow(blocked)) "Outlined: awaiting CAT data" else NULL) +
    theme_void(base_size = 7) + base_theme() +
    theme(legend.position = "bottom", legend.title = element_text(size = 6.5, color = ink), legend.text = element_text(size = 6, color = muted),
          plot.caption = element_text(size = 6, color = muted, hjust = 0))
}
pfmt = function(p) if (p < 0.001) "p < 0.001" else sprintf("p = %.3f", p)
scatter = function(v){
  m = js$models[[v]]; b = m$beta$value; lo95 = m$ci_low$value; hi95 = m$ci_high$value; p = m$p$value
  # Tim 2026-11-20: ordinary standard errors, reported as a 95% CI
  f3 = function(x) if (x != 0 && abs(x) < 0.0005) sprintf("%.4f", x) else sprintf("%.3f", x)   # a bound that rounds to 0 at 3 dp shows 4 dp
  lab = paste0(beta, " = ", f3(b), " (95% CI ", f3(lo95), " to ", f3(hi95), "), ", pfmt(p))   # paste0 keeps the UTF-8 mark; sprintf drops it in a C locale
  e = ext_tbl(v) |> left_join(d |> select(mpo_id, kg, y = all_of(v)), by = "mpo_id")
  ty = js$typical[[v]]; et = d |> filter(mpo_id == ty$mpo_id$value) |> mutate(y = .data[[v]])
  ggplot(d, aes(lkg, .data[[v]])) +
    geom_smooth(method = "lm", formula = y ~ x, se = TRUE, color = ink, fill = "#c9ced4", linewidth = 0.6) +
    geom_point(shape = 21, fill = hue[[v]], color = "white", size = 1.7, stroke = 0.3, alpha = 0.8) +
    geom_point(data = e, aes(log10(kg), y), shape = 21, fill = NA, color = "black", size = 2.6, stroke = 0.6) +
    geom_point(data = et, aes(log10(kg), y), shape = 23, fill = NA, color = "black", size = 3.4, stroke = 0.6) +   # on-the-line case: open diamond
    scale_x_continuous(breaks = log10(c(0.1, 0.2, 0.5, 1, 2)), labels = c("0.1", "0.2", "0.5", "1", "2")) +
    scale_y_continuous(expand = expansion(mult = c(0.04, 0.12)), breaks = scales::breaks_pretty(6)) +   # data extent, headroom for the annotation
    annotate("text", x = max(d$lkg), y = Inf, label = lab, hjust = 1, vjust = 1.4, size = 2.0, family = "DejaVu Sans", color = muted) +
    labs(title = paste(nm[[v]], "equity index vs. emissions per resident"), y = paste(nm[[v]], "equity index"),
         x = "On-road PM2.5 emissions per resident, kg, 2022 (log scale)") +
    theme_minimal(base_size = 7) + base_theme() +
    theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#e6e8eb", linewidth = 0.25),
          axis.text = element_text(color = muted), axis.title = element_text(color = ink))
}
sub = "One tile per MPO, arranged nearest its location."
# maps side by side on top, scatters side by side below (Tim, 2026-11-20)
# ND34: map column (race above income) on the left, about 62% of the width; scatter column on the right
gg = (tile_map("race", sub) / tile_map("income", sub) | scatter("race") / scatter("income")) + plot_layout(widths = c(0.62, 0.38))
dir.create("national/fig", showWarnings = FALSE)
ggsave("national/fig/mpo_national.png", gg, device = ragg::agg_png, width = 7.5, height = 8.8, dpi = 500, bg = "white")
message("wrote national/fig/mpo_national.png; lower limit ", lo, "; blocked tiles: ", nrow(blocked))
