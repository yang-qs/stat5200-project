# 07_replication_comparison.R
# Side-by-side comparison of the California replication with the published
# numbers in Abadie, Diamond & Hainmueller (2010, JASA), for the replication
# presentation. The published values are typed in from the paper (Table 1,
# Table 2, Section 3.3 and the text around Figure 8).
#
# Input : output/ca_synth.rds (written by 03_replicate_california.R)
# Output: output/ca_compare_balance.tex, output/ca_compare_weights.tex,
#         output/ca_compare_summary.tex, output/ca_ratio.pdf
#
# Run from the project root:  Rscript R/07_replication_comparison.R

source("R/functions.R")

ca <- readRDS("output/ca_synth.rds")
fit <- ca$fit
pl <- ca$placebo

# ---- Published values (ADH 2010) ----
# Table 1. Income: log GDP per capita in 1997 dollars per the table, log
# personal income per the text; price in cents; beer in gallons per capita.
paper_balance <- data.table(
  label = c("Ln(income per capita)", "Retail price", "Share aged 15--24 (\\%)",
            "Beer per capita (gal.)", "Packs per capita, 1975",
            "Packs per capita, 1980", "Packs per capita, 1988"),
  pred = c("lnincome", "price", "age15to24", "beer", "1975", "1980", "1988"),
  paper_real = c(10.08, 89.42, 17.40, 24.28, 127.10, 120.20, 90.10),
  paper_synth = c(9.86, 89.41, 17.40, 24.20, 126.99, 120.43, 91.62)
)
# Table 2: donors with positive weight.
paper_weights <- data.table(state = c("UT", "NV", "MT", "CO", "CT"),
                            paper = c(0.334, 0.234, 0.199, 0.164, 0.069))

# ---- Balance: paper vs replication ----
bal <- copy(fit$balance)
bal[, pred := fcase(grepl("beer", predictor), "beer",
                   grepl("packs_pc", predictor), sub(".*\\.([0-9]{4})$", "\\1", predictor),
                   default = predictor)]
# Report the replication price in cents, like the paper.
bal[pred == "price", `:=`(treated = 100 * treated, synthetic = 100 * synthetic)]
cmp <- merge(paper_balance, bal[, .(pred, treated, synthetic)], by = "pred", sort = FALSE)
writeLines(c("\\begin{tabular}{lcccc}", "\\toprule",
             " & \\multicolumn{2}{c}{ADH (2010)} & \\multicolumn{2}{c}{Replication} \\\\",
             "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
             " & California & Synthetic & California & Synthetic \\\\", "\\midrule",
             cmp[, sprintf("%s & %.2f & %.2f & %.2f & %.2f \\\\",
                           label, paper_real, paper_synth, treated, synthetic)],
             "\\bottomrule", "\\end{tabular}"),
           "output/ca_compare_balance.tex")

# ---- Weights: paper vs replication ----
w <- merge(paper_weights, fit$weights[weight >= 0.005, .(state, replication = weight)],
           by = "state", all = TRUE)
w[is.na(w)] <- 0
w <- w[order(-(paper + replication))]
writeLines(c("\\begin{tabular}{lcc}", "\\toprule",
             "State & ADH (2010) & Replication \\\\", "\\midrule",
             w[, sprintf("%s & %s & %s \\\\", state,
                         fifelse(paper > 0, sprintf("%.3f", paper), "--"),
                         fifelse(replication > 0, sprintf("%.3f", replication), "--"))],
             "\\bottomrule", "\\end{tabular}"),
           "output/ca_compare_weights.tex")

# ---- Headline numbers ----
post <- fit$path[year >= 1989]
mspe_ratio <- pl$stats[state == "CA", ratio^2]
rows <- c(
  sprintf("Pre-1989 MSPE & about 3 & %.1f \\\\", fit$rmspe_pre^2),
  sprintf("Gap in 2000 (packs) & about $-26$ & $%.1f$ \\\\", post[year == 2000, gap]),
  sprintf("Average gap 1989--2000 (packs) & almost $-20$ & $%.1f$ \\\\", post[, mean(gap)]),
  sprintf("Average gap, \\%% of synthetic & about $-25$\\%% & $%.0f$\\%% \\\\",
          100 * post[, mean(gap) / mean(synthetic)]),
  sprintf("Post/pre MSPE ratio & about 130 & %.0f \\\\", mspe_ratio),
  sprintf("Rank of California among 39 & 1 & %d \\\\", as.integer(pl$stats[state == "CA", rank])),
  sprintf("Permutation $p$-value & $1/39 = 0.026$ & $%.3f$ \\\\", pl$p_value)
)
writeLines(c("\\begin{tabular}{lcc}", "\\toprule", " & ADH (2010) & Replication \\\\",
             "\\midrule", rows, "\\bottomrule", "\\end{tabular}"),
           "output/ca_compare_summary.tex")

# ---- Ratio of post/pre MSPE (cf. ADH Figure 8) ----
st <- copy(pl$stats)[, `:=`(mspe_ratio = ratio^2, is_ca = state == "CA")]
st[, state := factor(state, levels = state[order(-mspe_ratio)])]
p <- ggplot(st, aes(state, mspe_ratio, fill = is_ca)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = c("grey70", "black"), guide = "none") +
  labs(x = NULL, y = "Post/pre MSPE ratio") +
  theme_bw() + theme(axis.text.x = element_text(size = 6, angle = 90, vjust = 0.5))
ggsave("output/ca_ratio.pdf", p, width = 6, height = 3.6)
