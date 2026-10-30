# 04_massachusetts_scm.R
# Synthetic control estimate of the effect of Massachusetts' Question 1.
# The 25-cent tax took effect in January 1993, so fiscal year 1993 (ending
# June 1993) is the first treated year, the same convention ADH use for
# California's January 1989 tax increase.
#
# Input : data/clean/panel_cov.csv
# Output: output/ma_synth.rds, output/ma_balance.tex,
#         output/ma_path.pdf, output/ma_placebo.pdf
#
# Run from the project root:  Rscript R/04_massachusetts_scm.R

source("R/functions.R")

panel <- fread("data/clean/panel_cov.csv")
donors <- panel[group == "Donor pool", sort(unique(state))]
run_case(panel, "MA", donors, treat_year = 1993, tag = "ma", treated_label = "Massachusetts")
