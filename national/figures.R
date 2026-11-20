# figures.R: four-panel national MPO figure (ND15-ND20, task V-3). Run from the repo root.
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
  mpo_id = ext(v, w)$mpo_id$value, name = ext(v, w)$mpo_name$value, val = ext(v, w)$value$value)))
base_theme = function() theme(plot.title = element_text(face = "bold", size = 7, color = ink, hjust = 0),
  plot.subtitle = element_text(color = muted, size = 6.5), text = element_text(color = ink),
  plot.margin = margin(4, 4, 4, 4))

wrap_name = function(x) x |> str_replace_all("-", "- ") |> str_wrap(13) |> str_replace_all("- (?=[^\n])", "-")
beta = intToUtf8(946)   # Greek beta
tile_map = function(v, sub = NULL){
  e = ext_tbl(v) |> left_join(tiles, by = "mpo_id")
  xr = range(tiles$col); mid = mean(xr); pad = 0.8
  e = e |> mutate(side = if_else(col < mid, "L", "R"),
                  lx = if_else(side == "L", xr[1] - 0.5 - pad, xr[2] + 0.5 + pad),
                  lab = paste0(wrap_name(name), " (", sprintf("%.3f", val), ")"))
  # separate labels vertically if both on one side
  if (e$side[1] == e$side[2] && abs(e$row[1] - e$row[2]) < 4){
    o = order(e$row); e$ly = e$row; e$ly[o[1]] = e$row[o[1]] - 2.5; e$ly[o[2]] = e$row[o[2]] + 2.5
  } else e$ly = e$row
  ggplot() +
    geom_tile(data = blocked, aes(col, row), fill = "white", color = "#8b949e", linewidth = 0.3, width = 1, height = 1) +
    geom_tile(data = filter(tl, !is.na(.data[[v]])), aes(col, row, fill = .data[[v]]), color = "white", linewidth = 0.3, width = 1, height = 1) +
    geom_tile(data = e, aes(col, row), fill = NA, color = "black", linewidth = 0.6, width = 1, height = 1) +
    geom_segment(data = e, aes(x = if_else(side == "L", col - 0.5, col + 0.5), xend = lx, y = row, yend = ly), linewidth = 0.25, color = "black") +
    geom_text(data = e, aes(x = lx, y = ly, label = lab, hjust = if_else(side == "L", 1.05, -0.05)), size = 1.9, color = ink, lineheight = 0.9) +
    scale_fill_gradient(low = hue[[v]], high = pale[[v]], limits = c(lo, 1), name = paste(nm[[v]], "equity index"),
                        guide = guide_colorbar(barwidth = 7, barheight = 0.4, ticks = FALSE, title.position = "top")) +
    coord_equal(xlim = c(xr[1] - 9.5, xr[2] + 9.5), ylim = range(tiles$row) + c(-1.5, 1.5), expand = FALSE) +
    labs(title = paste(nm[[v]], "equity index per metropolitan planning organization"), subtitle = sub,
         caption = if (nrow(blocked)) "Outlined: awaiting CAT data" else NULL) +
    theme_void(base_size = 7) + base_theme() +
    theme(legend.position = "bottom", legend.title = element_text(size = 6.5, color = ink), legend.text = element_text(size = 6, color = muted),
          plot.caption = element_text(size = 6, color = muted, hjust = 0))
}
pfmt = function(p) if (p < 0.001) "p < 0.001" else sprintf("p = %.3f", p)
scatter = function(v){
  m = js$models[[v]]; b = m$beta$value; se = m$se$value; p = m$p$value
  lab = paste0(beta, sprintf(" = %.3f (SE %.3f), ", b, se), pfmt(p))   # paste0 keeps the UTF-8 mark; sprintf drops it in a C locale
  e = ext_tbl(v) |> left_join(d |> select(mpo_id, kg, y = all_of(v)), by = "mpo_id")
  ggplot(d, aes(lkg, .data[[v]])) +
    geom_smooth(method = "lm", formula = y ~ x, se = TRUE, color = ink, fill = "#c9ced4", linewidth = 0.6) +
    geom_point(shape = 21, fill = hue[[v]], color = "white", size = 1.7, stroke = 0.3, alpha = 0.8) +
    geom_point(data = e, aes(log10(kg), y), shape = 21, fill = NA, color = "black", size = 2.6, stroke = 0.6) +
    scale_x_continuous(breaks = log10(c(0.1, 0.2, 0.5, 1, 2)), labels = c("0.1", "0.2", "0.5", "1", "2")) +
    scale_y_continuous(limits = c(lo, 1), breaks = seq(lo, 1, 0.05)) +
    annotate("text", x = max(d$lkg), y = lo + 0.04, label = lab, hjust = 1, vjust = 0, size = 2.3, family = "DejaVu Sans", color = muted) +
    labs(title = paste(nm[[v]], "equity index vs. emissions per resident"), y = paste(nm[[v]], "equity index"),
         x = "On-road PM2.5 emissions per resident, kg, 2022 (log scale)") +
    theme_minimal(base_size = 7) + base_theme() +
    theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "#e6e8eb", linewidth = 0.25),
          axis.text = element_text(color = muted), axis.title = element_text(color = ink))
}
gg = (tile_map("race", "One tile per MPO, arranged nearest its location.") | tile_map("income", "One tile per MPO, arranged nearest its location.")) /
     (scatter("race") | scatter("income")) + plot_layout(heights = c(0.8, 1.1))
dir.create("national/fig", showWarnings = FALSE)
ggsave("national/fig/mpo_national.png", gg, device = ragg::agg_png, width = 7.5, height = 7, dpi = 300, bg = "white")
message("wrote national/fig/mpo_national.png; lower limit ", lo, "; blocked tiles: ", nrow(blocked))
