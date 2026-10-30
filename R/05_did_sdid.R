# 05_did_sdid.R
# Compare the synthetic control estimates with two-way fixed effects DiD,
# an event study, and synthetic DiD (Arkhangelsky et al. 2021), for both
# California (first treated year 1989) and Massachusetts (1993).
#
# With one treated state, cluster-robust standard errors are unreliable
# (Conley & Taber 2011), so every DiD estimate also gets a permutation
# p-value from reassigning treatment to each donor state.
#
# Input : data/clean/panel_cov.csv, output/ca_synth.rds, output/ma_synth.rds
# Output: output/did_results.rds, output/main_results.tex,
#         output/elasticity.tex, output/ma_event_study.pdf
#
# Run from the project root:  Rscript R/05_did_sdid.R

source("R/functions.R")
library(fixest)
library(synthdid)
set.seed(5200)

panel <- fread("data/clean/panel_cov.csv")
donors <- panel[group == "Donor pool", sort(unique(state))]
cases <- list(CA = 1989, MA = 1993)

#' TWFE DiD of `outcome` on a treated-after indicator, state and year FE.
twfe <- function(dat, treated, treat_year, outcome = "packs_pc") {
  dat <- copy(dat)[, d := as.integer(state == treated & year >= treat_year)]
  feols(as.formula(paste(outcome, "~ d | state + year")), data = dat, cluster = ~state)
}

#' Permutation p-value: share of units whose |estimate| is at least the treated one's.
perm_p <- function(estimates, treated) mean(abs(estimates) >= abs(estimates[treated]))

results <- list()
for (tr in names(cases)) {
  ty <- cases[[tr]]
  dat <- panel[state %in% c(tr, donors)]
  dat[, `:=`(log_packs = log(packs_pc), log_price = log(price))]
  units <- c(tr, donors)

  # ---- TWFE DiD in levels, with permutation inference ----
  fit <- twfe(dat, tr, ty)
  perm <- sapply(units, function(s) coef(twfe(dat[state != tr | s == tr], s, ty))["d"])
  names(perm) <- units

  # ---- Log specifications: implied price elasticity of demand ----
  # The ratio of the DiD effect on log sales to the DiD effect on log price
  # is a Wald (IV) estimate of the price elasticity.
  b_qty <- coef(twfe(dat, tr, ty, "log_packs"))["d"]
  b_price <- coef(twfe(dat, tr, ty, "log_price"))["d"]

  # ---- Synthetic DiD, plus SC and DiD from the same package for comparison ----
  dat[, treated := as.integer(state == tr & year >= ty)]
  pm <- panel.matrices(as.data.frame(dat[, .(state, year, packs_pc, treated)]))
  est <- list(sdid = synthdid_estimate(pm$Y, pm$N0, pm$T0),
              sc = sc_estimate(pm$Y, pm$N0, pm$T0),
              did = did_estimate(pm$Y, pm$N0, pm$T0))
  # Placebo variance: the only option with a single treated unit.
  se <- sapply(est, function(e) sqrt(vcov(e, method = "placebo")))

  scm <- readRDS(sprintf("output/%s_synth.rds", tolower(tr)))
  results[[tr]] <- list(
    twfe = coef(fit)["d"], twfe_se = se(fit)["d"], twfe_perm_p = perm_p(perm, tr),
    sdid = as.numeric(est$sdid), sdid_se = se[["sdid"]],
    sc_pkg = as.numeric(est$sc), sc_pkg_se = se[["sc"]],
    did_pkg = as.numeric(est$did), did_pkg_se = se[["did"]],
    scm = scm$fit$path[year >= ty, mean(gap)], scm_p = scm$placebo$p_value,
    scm_p_neg = scm$placebo$p_value_neg,
    b_qty = b_qty, b_price = b_price, elasticity = b_qty / b_price,
    sdid_weights = synthdid_controls(est$sdid)
  )
}
saveRDS(results, "output/did_results.rds")
str(lapply(results, function(r) r[setdiff(names(r), "sdid_weights")]))

# ---- Table: average post-treatment effect by estimator ----
fmt <- function(x, s, p = NULL) {
  c(sprintf("%.1f", x), if (!is.null(s)) sprintf("(%.1f)", s) else "",
    if (!is.null(p)) sprintf("[%.3f]", p) else "")
}
row_block <- function(label, key, se_key = NULL, p_key = NULL) {
  cells <- sapply(results, function(r) fmt(r[[key]], if (!is.null(se_key)) r[[se_key]],
                                          if (!is.null(p_key)) r[[p_key]]))
  c(sprintf("%s & %s & %s \\\\", label, cells[1, 1], cells[1, 2]),
    sprintf(" & %s & %s \\\\", cells[2, 1], cells[2, 2]),
    if (any(cells[3, ] != "")) sprintf(" & %s & %s \\\\", cells[3, 1], cells[3, 2]))
}
writeLines(c("\\begin{tabular}{lcc}", "\\toprule",
             " & California (1989) & Massachusetts (1993) \\\\", "\\midrule",
             row_block("Two-way FE DiD", "twfe", "twfe_se", "twfe_perm_p"),
             "\\addlinespace",
             row_block("Synthetic control (ADH predictors)", "scm", NULL, "scm_p"),
             "\\addlinespace",
             row_block("Synthetic control (outcomes only)", "sc_pkg", "sc_pkg_se"),
             "\\addlinespace",
             row_block("Synthetic DiD", "sdid", "sdid_se"),
             "\\bottomrule", "\\end{tabular}"),
           "output/main_results.tex")

writeLines(c("\\begin{tabular}{lcc}", "\\toprule",
             " & California & Massachusetts \\\\", "\\midrule",
             sprintf("DiD on log sales & %.3f & %.3f \\\\", results$CA$b_qty, results$MA$b_qty),
             sprintf("DiD on log price & %.3f & %.3f \\\\", results$CA$b_price, results$MA$b_price),
             sprintf("Implied price elasticity & %.2f & %.2f \\\\",
                     results$CA$elasticity, results$MA$elasticity),
             "\\bottomrule", "\\end{tabular}"),
           "output/elasticity.tex")

# ---- Event study for Massachusetts (reference year 1992) ----
dat <- panel[state %in% c("MA", donors)]
dat[, rel := fifelse(state == "MA", year - 1993, -1000)]
es <- feols(packs_pc ~ i(rel, ref = c(-1, -1000)) | state + year, data = dat, cluster = ~state)
ct <- as.data.table(coeftable(es), keep.rownames = "term")
ct[, rel := as.integer(sub("rel::", "", term))]
ct <- rbind(ct, data.table(rel = -1, Estimate = 0, `Std. Error` = 0), fill = TRUE)
p <- ggplot(ct, aes(rel + 1993, Estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_vline(xintercept = 1992.5, linetype = "dotted") +
  geom_pointrange(aes(ymin = Estimate - 1.96 * `Std. Error`,
                      ymax = Estimate + 1.96 * `Std. Error`), size = 0.25) +
  labs(x = NULL, y = "Effect on packs per capita") + theme_bw()
ggsave("output/ma_event_study.pdf", p, width = 6, height = 3.6)
