# 06_robustness.R
# Robustness checks for the Massachusetts synthetic control:
#   (a) in-time placebo: pretend Question 1 took effect in 1988, using only
#       data up to 1992;
#   (b) drop New England neighbours from the donor pool, since cross-border
#       purchases after the tax increase would raise their recorded sales;
#   (c) use every pre-treatment outcome as a predictor and no covariates;
#   (d) treat fiscal 1994, the first full year of the higher tax, as the
#       first treated year;
#   (e) leave-one-out: drop each donor that receives positive weight.
#
# Input : data/clean/panel_cov.csv, output/ma_synth.rds
# Output: output/robustness.rds, output/robustness.tex, output/ma_loo.pdf
#
# Run from the project root:  Rscript R/06_robustness.R

source("R/functions.R")

panel <- fread("data/clean/panel_cov.csv")
donors <- panel[group == "Donor pool", sort(unique(state))]
neighbours <- c("CT", "NH", "RI", "VT")
main <- readRDS("output/ma_synth.rds")$fit

summarise_fit <- function(label, fit, treat_year) {
  top <- fit$weights[weight >= 0.05][order(-weight)]
  data.table(spec = label,
             donors = paste(sprintf("%s (%.2f)", top$state, top$weight), collapse = ", "),
             rmspe_pre = fit$rmspe_pre,
             avg_gap = fit$path[year >= treat_year, mean(gap)],
             gap_2000 = fit$path[year == max(year), gap])
}

fits <- list(
  main = list(fit = main, ty = 1993, label = "Baseline"),
  in_time = list(fit = fit_synth(panel, "MA", donors, 1988, years = 1970:1992),
                 ty = 1988, label = "In-time placebo: 1988 (data to 1992)"),
  no_neighbours = list(fit = fit_synth(panel, "MA", setdiff(donors, neighbours), 1993),
                       ty = 1993, label = "Drop CT, NH, RI, VT from donors"),
  outcomes_only = list(fit = fit_synth(panel, "MA", donors, 1993, spec = NULL),
                       ty = 1993, label = "All pre-period outcomes as predictors"),
  fy1994 = list(fit = fit_synth(panel, "MA", donors, 1994), ty = 1994,
                label = "First treated year 1994")
)
# The in-time placebo's "post" period is 1988-1992, so its 2000 column is the 1992 gap.

# ---- Leave-one-out ----
loo_states <- main$weights[weight >= 0.01, state]
loo <- lapply(loo_states, function(s) fit_synth(panel, "MA", setdiff(donors, s), 1993))
names(loo) <- loo_states
for (s in loo_states) {
  fits[[paste0("loo_", s)]] <- list(fit = loo[[s]], ty = 1993, label = paste("Drop", s))
}

tab <- rbindlist(lapply(fits, function(f) summarise_fit(f$label, f$fit, f$ty)))
print(tab)
saveRDS(list(fits = fits, table = tab), "output/robustness.rds")

writeLines(c("\\begin{tabular}{llccc}", "\\toprule",
             "Specification & Donors (weight $\\geq 0.05$) & Pre RMSPE & Avg.\\ gap & Final gap \\\\",
             "\\midrule",
             tab[, sprintf("%s & %s & %.2f & %.1f & %.1f \\\\", spec, donors, rmspe_pre,
                           avg_gap, gap_2000)],
             "\\bottomrule", "\\end{tabular}"),
           "output/robustness.tex")

# ---- Leave-one-out figure (cf. ADH 2015, Fig. 5) ----
paths <- rbindlist(lapply(loo_states, function(s) loo[[s]]$path[, .(year, synthetic, dropped = s)]))
p <- ggplot() +
  geom_line(data = paths, aes(year, synthetic, group = dropped), colour = "grey65", linewidth = 0.5) +
  geom_line(data = main$path, aes(year, synthetic), linetype = "dashed", linewidth = 0.8) +
  geom_line(data = main$path, aes(year, actual), linewidth = 0.8) +
  geom_vline(xintercept = 1992.5, linetype = "dotted") +
  labs(x = NULL, y = "Packs per capita") + theme_bw()
ggsave("output/ma_loo.pdf", p, width = 6, height = 3.6)
