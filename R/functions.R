# functions.R
# Shared helpers for the synthetic control, placebo and DiD analyses.
# Sourced by the numbered scripts; defines functions only, no side effects.

library(data.table)
library(Synth)
library(ggplot2)

#' Predictor specification in the style of Abadie, Diamond & Hainmueller (2010).
#'
#' Covariates are averaged over the last nine pre-treatment years (beer over
#' the last five, as beer data in ADH start in 1984); lagged outcomes are taken
#' at 1975, 1980 and the last pre-treatment year.
#' @param treat_year first treated (fiscal) year.
#' @param lags years of lagged per-capita sales used as predictors.
adh_spec <- function(treat_year, lags = c(1975, 1980, treat_year - 1)) {
  list(
    predictors = c("lnincome", "price", "age15to24"),
    time_predictors = (treat_year - 9):(treat_year - 1),
    special = c(list(list("beer", (treat_year - 5):(treat_year - 1), "mean")),
                lapply(lags, function(y) list("packs_pc", y, "mean")))
  )
}

#' Fit one synthetic control.
#'
#' @param panel data.table with columns state, year, packs_pc and the predictors.
#' @param treated state abbreviation of the treated unit.
#' @param donors character vector of donor state abbreviations.
#' @param treat_year first treated year.
#' @param spec predictor specification from adh_spec(); NULL uses every
#'   pre-treatment outcome as a predictor and no covariates.
#' @param years years kept for the fit and the plot.
#' @return list with the weights, the yearly path (actual, synthetic, gap),
#'   the predictor balance table and pre/post RMSPE.
fit_synth <- function(panel, treated, donors, treat_year, spec = adh_spec(treat_year),
                      years = 1970:2000) {
  dat <- as.data.frame(panel[state %in% c(treated, donors) & year %in% years])
  dat$unit <- match(dat$state, sort(unique(dat$state)))
  id <- function(s) unique(dat$unit[dat$state %in% s])
  pre <- years[years < treat_year]

  if (is.null(spec)) {
    # dataprep() requires a regular predictor; the pre-period mean of the
    # outcome is a linear combination of the yearly lags, so it adds nothing.
    spec <- list(predictors = "packs_pc", time_predictors = pre,
                 special = lapply(pre, function(y) list("packs_pc", y, "mean")))
  }
  dp <- dataprep(
    foo = dat, predictors = spec$predictors, predictors.op = "mean",
    time.predictors.prior = spec$time_predictors, special.predictors = spec$special,
    dependent = "packs_pc", unit.variable = "unit", unit.names.variable = "state",
    time.variable = "year", treatment.identifier = id(treated),
    controls.identifier = id(donors), time.optimize.ssr = pre, time.plot = years
  )
  # Synth prints optimizer progress to stdout; keep the logs readable.
  # The interior-point solver (ipop) occasionally fails on a placebo unit
  # (Rhode Island in the Massachusetts design); retry with looser tolerances.
  invisible(capture.output(so <- tryCatch(
    synth(dp, verbose = FALSE),
    error = function(e) synth(dp, verbose = FALSE, Margin.ipop = 0.005,
                              Sigf.ipop = 5, Bound.ipop = 6)
  )))

  w <- data.table(state = dat$state[match(as.integer(rownames(so$solution.w)), dat$unit)],
                  weight = as.numeric(so$solution.w))
  synthetic <- as.numeric(dp$Y0plot %*% so$solution.w)
  path <- data.table(year = years, actual = as.numeric(dp$Y1plot), synthetic = synthetic)
  path[, gap := actual - synthetic]
  balance <- data.table(predictor = rownames(dp$X1), treated = as.numeric(dp$X1),
                        synthetic = as.numeric(dp$X0 %*% so$solution.w),
                        donor_mean = rowMeans(dp$X0))
  rmspe <- function(g) sqrt(mean(g^2))
  list(treated = treated, weights = w, path = path, balance = balance,
       rmspe_pre = path[year < treat_year, rmspe(gap)],
       rmspe_post = path[year >= treat_year, rmspe(gap)])
}

#' Placebo-in-space inference (Abadie, Diamond & Hainmueller 2010, Sec. 4).
#'
#' Reassigns treatment to every donor in turn, using the remaining donors as
#' its pool. The p-value is the rank of the treated unit's post/pre RMSPE
#' ratio among all units, divided by the number of units. The one-sided
#' p-value for a reduction ranks the signed statistic mean post gap / pre RMSPE.
#' @return list with the gap paths of all units, the RMSPE table and the p-values.
placebo_test <- function(panel, treated, donors, treat_year, spec = adh_spec(treat_year)) {
  units <- c(treated, donors)
  fits <- lapply(units, function(s) {
    fit_synth(panel, s, setdiff(units, s), treat_year, spec)
  })
  gaps <- rbindlist(lapply(fits, function(f) f$path[, .(state = f$treated, year, gap)]))
  stats <- rbindlist(lapply(fits, function(f) {
    data.table(state = f$treated, rmspe_pre = f$rmspe_pre, rmspe_post = f$rmspe_post,
               avg_gap = f$path[year >= treat_year, mean(gap)])
  }))
  stats[, `:=`(ratio = rmspe_post / rmspe_pre, signed = avg_gap / rmspe_pre)]
  stats[, rank := frank(-ratio)]
  list(gaps = gaps, stats = stats,
       p_value = stats[state == treated, rank] / nrow(stats),
       p_value_neg = stats[, mean(signed <= signed[state == treated])])
}

#' Write the predictor balance table (cf. ADH 2010, Table 1) as LaTeX.
write_balance <- function(fit, file, treated_label) {
  labels <- c(lnincome = "Ln(per capita income)", price = "Retail price (\\$/pack)",
              age15to24 = "Share aged 15--24 (\\%)", beer = "Beer per capita (gal.)")
  bal <- copy(fit$balance)
  bal[, label := fifelse(grepl("beer", predictor), labels["beer"], labels[predictor])]
  lag <- grepl("packs_pc", bal$predictor)
  bal[lag, label := paste0("Packs per capita, ", sub(".*\\.([0-9]{4})$", "\\1", predictor))]
  writeLines(c("\\begin{tabular}{lccc}", "\\toprule",
               sprintf(" & %s & Synthetic & Donor average \\\\", treated_label), "\\midrule",
               bal[, sprintf("%s & %.2f & %.2f & %.2f \\\\", label, treated, synthetic, donor_mean)],
               "\\bottomrule", "\\end{tabular}"), file)
}

#' Plot actual vs synthetic per-capita sales.
plot_path <- function(fit, treat_year, treated_label, file) {
  long <- melt(fit$path, id.vars = "year", measure.vars = c("actual", "synthetic"))
  p <- ggplot(long, aes(year, value, linetype = variable)) +
    geom_line(linewidth = 0.8) +
    geom_vline(xintercept = treat_year - 0.5, linetype = "dotted") +
    scale_linetype_manual(values = c("solid", "dashed"),
                          labels = c(treated_label, paste("Synthetic", treated_label))) +
    labs(x = NULL, y = "Packs per capita", linetype = NULL) +
    theme_bw() + theme(legend.position = "bottom")
  ggsave(file, p, width = 6, height = 3.6)
}

#' Plot the treated gap against placebo gaps. Placebos whose pre-period MSPE
#' exceeds `cutoff` times the treated unit's are dropped, as in ADH Fig. 5-7.
plot_placebo <- function(pl, treated, treat_year, file, cutoff = 5) {
  mspe_tr <- pl$stats[state == treated, rmspe_pre^2]
  keep <- pl$stats[rmspe_pre^2 <= cutoff * mspe_tr & state != treated, state]
  p <- ggplot(pl$gaps[state %in% keep], aes(year, gap, group = state)) +
    geom_line(colour = "grey75", linewidth = 0.4) +
    geom_line(data = pl$gaps[state == treated], colour = "black", linewidth = 0.9) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    geom_vline(xintercept = treat_year - 0.5, linetype = "dotted") +
    labs(x = NULL, y = "Gap in packs per capita") + theme_bw()
  ggsave(file, p, width = 6, height = 3.6)
}

#' Fit the synthetic control and placebo test for one treated state and save
#' every output under output/<tag>_*.
run_case <- function(panel, treated, donors, treat_year, tag, treated_label) {
  fit <- fit_synth(panel, treated, donors, treat_year)
  pl <- placebo_test(panel, treated, donors, treat_year)
  saveRDS(list(fit = fit, placebo = pl), sprintf("output/%s_synth.rds", tag))
  write_balance(fit, sprintf("output/%s_balance.tex", tag), treated_label)
  plot_path(fit, treat_year, treated_label, sprintf("output/%s_path.pdf", tag))
  plot_placebo(pl, treated, treat_year, sprintf("output/%s_placebo.pdf", tag))

  cat("\nSynthetic", treated_label, "weights:\n")
  print(fit$weights[weight >= 0.001][order(-weight)])
  cat("Pre-period RMSPE:", round(fit$rmspe_pre, 2), "\n")
  cat("Gap in 2000:", round(fit$path[year == 2000, gap], 1), "packs\n")
  cat("Average post-period gap:", round(fit$path[year >= treat_year, mean(gap)], 1), "packs\n")
  cat("Permutation p-value:", round(pl$p_value, 3),
      "(one-sided for a reduction:", round(pl$p_value_neg, 3), ")\n")
  invisible(list(fit = fit, placebo = pl))
}
