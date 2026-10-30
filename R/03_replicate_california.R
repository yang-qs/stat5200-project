# 03_replicate_california.R
# Replicate Abadie, Diamond & Hainmueller (2010): synthetic California and
# placebo-in-space inference for Proposition 99 (first treated year 1989).
# Targets from the paper: weights on UT, NV, MT, CO, CT; a gap of about
# 26 packs by 2000; permutation p-value 1/39.
#
# Input : data/clean/panel_cov.csv
# Output: output/ca_synth.rds, output/ca_balance.tex,
#         output/ca_path.pdf, output/ca_placebo.pdf
#
# Run from the project root:  Rscript R/03_replicate_california.R

source("R/functions.R")

panel <- fread("data/clean/panel_cov.csv")
donors <- panel[group == "Donor pool", sort(unique(state))]
run_case(panel, "CA", donors, treat_year = 1989, tag = "ca", treated_label = "California")
