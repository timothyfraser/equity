# proto_tilemap.R: MOCK-UP ONLY (plan: .contract/national/PLAN_VIZ_AND_CAT.md). Not used by the paper.
# Four panels: tile-grid maps of the race and income indices (one tile per multi-county MPO, placed near its
# true location), and index-versus-emissions scatters with a fitted log curve.
suppressPackageStartupMessages({library(dplyr); library(readr); library(sf); library(ggplot2); library(purrr); library(tidyr); library(patchwork); library(stringr)})
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity"); setwd(root)
idx = read_csv("national/index_mpo.csv", show_col_types = FALSE, col_types = cols(mpo_id = "c"))
led = read_csv("national/LEDGER.csv", show_col_types = FALSE, col_types = cols(mpo_id = "c")) %>% filter(status == "done")
# MPO emissions: member-county emissions falling on the MPO's exposed residents (tons PM2.5, 2022)
em = map_dfr(led$mpo_id, function(id) read_csv(file.path("national/out", id, "members.csv"), show_col_types = FALSE) %>%
               summarize(mpo_id = id, emissions = sum(emissions_county * share_county_affected, na.rm = TRUE)))
wide = idx %>% select(mpo_id, mpo_name, type, indicator2, pop_in_mpo) %>% pivot_wider(names_from = type, values_from = indicator2) %>%
  left_join(em, by = "mpo_id") %>% left_join(led %>% select(mpo_id, state), by = "mpo_id") %>% mutate(rate = emissions / pop_in_mpo)

# ---- tile grid: assign each MPO centroid to one cell of a regular grid, minimising total squared displacement
cen = map_dfr(wide$mpo_id, function(id){ g = st_read(file.path("index/cache/national/mpo", paste0(id, ".geojson")), quiet = TRUE) %>% st_make_valid()
  xy = suppressWarnings(st_coordinates(st_centroid(st_transform(st_geometry(g), 5070)))); tibble(mpo_id = id, x = xy[1], y = xy[2]) })
cen = cen %>% left_join(wide %>% select(mpo_id, state), by = "mpo_id") %>%
  mutate(x = case_when(state == "AK" ~ x * 0.35 - 1.2e6, state == "HI" ~ x + 5.2e6, TRUE ~ x),      # inset positions, bottom-left
         y = case_when(state == "AK" ~ y * 0.35 - 0.9e6, state == "HI" ~ y + 1.0e6, TRUE ~ y))
tile_grid = function(cen, ncol = 26, nrow = 16){
  gx = (cen$x - min(cen$x)) / diff(range(cen$x)) * (ncol - 1) + 1
  gy = (cen$y - min(cen$y)) / diff(range(cen$y)) * (nrow - 1) + 1
  cells = expand.grid(col = 1:ncol, row = 1:nrow)
  cost = outer(gx, cells$col, "-")^2 + outer(gy, cells$row, "-")^2
  a = clue::solve_LSAP(cost)
  cen %>% mutate(col = cells$col[a], row = cells$row[a], disp = sqrt(cost[cbind(seq_along(a), a)]))
}
tg = tile_grid(cen); message("tiles: ", nrow(tg), "; mean displacement (cells): ", round(mean(tg$disp), 2), "; max: ", round(max(tg$disp), 2))
d = wide %>% left_join(tg %>% select(mpo_id, col, row, disp), by = "mpo_id")
write_csv(d, "national/proto/proto_tilemap_data.csv")

ink = "#1f2328"; muted = "#59636e"
hue = c(race = "#6a00a8", income = "#b12a90")       # the paper's plasma hues for race and income
tile_map = function(v, title){
  lo = floor(min(d[[v]]) * 20) / 20
  ggplot(d, aes(col, row)) +
    geom_tile(aes(fill = .data[[v]]), color = "white", linewidth = 0.5) +
    geom_text(aes(label = state, color = .data[[v]] < (lo + 1) / 2 + 0.03), size = 1.55, show.legend = FALSE) +
    scale_color_manual(values = c(`TRUE` = "white", `FALSE` = ink)) +
    scale_fill_gradient(low = hue[[v]], high = "#f4eef8", limits = c(lo, 1), name = NULL,
                        guide = guide_colorbar(barwidth = 8, barheight = 0.35, ticks = FALSE)) +
    coord_equal(expand = FALSE) + labs(title = title, subtitle = "one tile per multi-county MPO, placed near its location; darker = less even") +
    theme_void(base_size = 7) + theme(legend.position = "bottom", plot.title = element_text(face = "bold", size = 8, color = ink),
                                      plot.subtitle = element_text(color = muted, size = 6), plot.margin = margin(4, 4, 4, 4))
}
scatter = function(v, title){
  m = lm(reformulate("log(emissions)", v), data = d); s = summary(m)$coefficients
  m2 = lm(reformulate(c("log(emissions)", "log(pop_in_mpo)"), v), data = d); s2 = summary(m2)$coefficients
  lab = sprintf("beta = %.3f (SE %.3f), p = %.3g\nwith log population: beta = %.3f, p = %.3g", s[2, 1], s[2, 2], s[2, 4], s2[2, 1], s2[2, 4])
  lo = floor(min(d[[v]]) * 20) / 20
  ggplot(d, aes(emissions, .data[[v]])) +
    geom_point(shape = 21, fill = hue[[v]], color = "white", size = 1.6, stroke = 0.3, alpha = 0.85) +
    geom_smooth(method = "lm", formula = y ~ log(x), se = TRUE, color = ink, fill = "#c9ced4", linewidth = 0.7) +
    geom_smooth(method = "gam", formula = y ~ s(log(x), k = 5), se = FALSE, color = ink, linewidth = 0.4, linetype = "22") +
    scale_x_log10(labels = scales::label_number(scale_cut = scales::cut_si(""))) + coord_cartesian(ylim = c(lo, 1)) +
    annotate("text", x = max(d$emissions), y = lo + 0.005, label = lab, hjust = 1, vjust = 0, size = 2, color = muted) +
    labs(title = title, x = "MPO on-road PM2.5 emissions, tons, 2022 (log scale)", y = NULL,
         subtitle = "solid: log fit with 95% band; dashed: smooth (GAM)") +
    theme_minimal(base_size = 7) + theme(panel.grid.minor = element_blank(), plot.title = element_text(face = "bold", size = 8, color = ink),
                                         plot.subtitle = element_text(color = muted, size = 6))
}
gg = (tile_map("race", "A  Race/ethnicity equity index") | tile_map("income", "B  Income equity index")) /
     (scatter("race", "C  Race/ethnicity index vs. emissions") | scatter("income", "D  Income index vs. emissions")) + plot_layout(heights = c(1.15, 1))
ggsave("national/proto/proto_tilemap.png", gg, width = 7.5, height = 6.6, dpi = 300, bg = "white")
