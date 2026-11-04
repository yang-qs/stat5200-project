# run_all.R
# Reproduce every table and figure in the report, in order.
# Run from the project root:  Rscript run_all.R
# Total run time is roughly 15 minutes, most of it the placebo loops and the
# SEER population file in step 02.

scripts <- c("R/01_clean_and_describe.R", "R/02_build_covariates.R",
             "R/03_replicate_california.R", "R/04_massachusetts_scm.R",
             "R/05_did_sdid.R", "R/06_robustness.R",
             "R/07_replication_comparison.R")
for (s in scripts) {
  cat("\n==== ", s, " ====\n")
  # Each script runs in a fresh environment so none depends on another's objects.
  source(s, local = new.env(), echo = FALSE)
}

writeLines(capture.output(sessionInfo()), "output/session_info.txt")
