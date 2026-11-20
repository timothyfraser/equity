# figures.R: ranked charts of multi-county MPOs from national/index_mpo.csv (written by national/ledger.R build).
# Usage (repo root): Rscript national/figures.R
# Writes national/fig/mpo_rank_overall.png, national/fig/mpo_rank_race.png, national/tables/mpo_index.csv.
# Bar = equal-group index (the paper's headline, ND3); dot = population-weighted companion on the same row,
# so the small-group effect (ND10) is visible. Worst at the top. New York MPOs in bold.
suppressPackageStartupMessages({library(dplyr); library(readr); library(ggplot2); library(tidyr); library(stringr)})
root = Sys.getenv("EQUITY_ROOT", "/home/user/equity"); setwd(root)
dir.create("national/fig", showWarnings = FALSE); dir.create("national/tables", showWarnings = FALSE)
idx = read_csv("national/index_mpo.csv", show_col_types = FALSE, col_types = cols(mpo_id = "c"))
ledger = read_csv("national/LEDGER.csv", show_col_types = FALSE, col_types = cols(mpo_id = "c"))
tab = idx %>% select(mpo_id, mpo_name, type, indicator2, indicator_pw, n_groups, race_groups_lt_1000, pop_in_mpo) %>%
  left_join(ledger %>% select(mpo_id, state, n_counties, n_states), by = "mpo_id")
write_csv(tab, "national/tables/mpo_index.csv")

ink = "#1f2328"; muted = "#59636e"; grid = "#e6e8eb"; bar = "#9aa7b4"; bar_ny = "#2f5d8a"; dot = "#c4501c"
rank_plot = function(ty, label){
  d = tab %>% filter(type == ty) %>%
    mutate(name = str_trunc(str_replace(mpo_name, " Metropolitan Planning Organization$", " MPO"), 46),
           name = paste0(name, " (", state, ")"), ny = state == "NY") %>%
    arrange(desc(indicator2)) %>% mutate(name = factor(name, levels = name))
  lo = floor(min(c(d$indicator2, d$indicator_pw), na.rm = TRUE) * 20) / 20
  ggplot(d, aes(y = name)) +
    geom_segment(aes(x = lo, xend = indicator2, yend = name, color = ny), linewidth = 1.6, lineend = "round") +
    geom_point(aes(x = indicator_pw, shape = "Population-weighted"), color = dot, size = 1.1) +
    scale_color_manual(values = c(`FALSE` = bar, `TRUE` = bar_ny), labels = c(`FALSE` = "Equal-group index (other MPOs)", `TRUE` = "Equal-group index (New York MPOs)"), name = NULL) +
    scale_shape_manual(values = c("Population-weighted" = 16), name = NULL) +
    scale_x_continuous(limits = c(lo, 1), expand = expansion(c(0, 0.01)), breaks = seq(lo, 1, by = 0.05)) +
    labs(x = paste0(label, " (axis starts at ", sprintf("%.2f", lo), "; 1 = perfectly even)"), y = NULL,
         title = paste0(label, ", ", nrow(d), " multi-county MPOs, least even at top")) +
    theme_minimal(base_size = 7) +
    theme(text = element_text(color = ink), axis.text.y = element_text(size = 4.2, color = ifelse(levels(d$name) %in% d$name[d$ny], ink, muted),
                                                                        face = ifelse(levels(d$name) %in% d$name[d$ny], "bold", "plain")),
          axis.text.x = element_text(color = muted), panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
          panel.grid.major.x = element_line(color = grid, linewidth = 0.3), legend.position = "top", plot.title.position = "plot",
          plot.title = element_text(size = 8, face = "bold"))
}
h = function(n) max(6, 0.075 * n + 1.2)
n = nrow(filter(tab, type == "overall"))
ggsave("national/fig/mpo_rank_overall.png", rank_plot("overall", "Overall equity index"), width = 6.5, height = h(n), dpi = 300, bg = "white")
ggsave("national/fig/mpo_rank_race.png", rank_plot("race", "Race/ethnicity equity index"), width = 6.5, height = h(n), dpi = 300, bg = "white")
message("MPOs charted: ", n)
