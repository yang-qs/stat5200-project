# STAT 5200 Final Project: Massachusetts' 1992 Tobacco Control Initiative

Did Massachusetts' Question 1 (1992), a 25-cent cigarette tax increase that funded the
Massachusetts Tobacco Control Program, reduce per-capita cigarette sales? The project first
replicates Abadie, Diamond & Hainmueller (2010, *JASA*) for California's Proposition 99, then
applies the same synthetic control design to Massachusetts and compares it with two-way fixed
effects DiD and synthetic DiD (Arkhangelsky et al. 2021, *AER*).

The report is `report/main.pdf`.

## Main results

| | California (1989) | Massachusetts (1993) |
|---|---|---|
| Synthetic control, average gap (packs per capita) | -17.8 | -18.5 |
| Synthetic control, gap in 2000 | -24.3 | -29.3 |
| Permutation p-value (post/pre RMSPE ratio, 39 states) | 0.026 | 0.077 |
| TWFE DiD | -27.4 | -19.3 |
| Synthetic DiD (placebo SE) | -15.2 (9.9) | -16.9 (10.8) |

## Data

| File | Source | In git? |
|---|---|---|
| `data/raw/tax_burden_tobacco_1970_2019.csv` | CDC STATE System, *The Tax Burden on Tobacco, 1970–2019* (Orzechowski & Walker), [dataset `7nwe-3aj9`](https://data.cdc.gov/Policy/The-Tax-Burden-on-Tobacco-1970-2019/7nwe-3aj9). Sales, price and tax by state and fiscal year (ending June 30). | yes |
| `data/raw/pcyr1970-2023.txt` | NIAAA, apparent per capita alcohol consumption by state (Surveillance Report #122). Used for beer per capita. | yes |
| `data/raw/SAINC.zip` | BEA regional accounts, table SAINC1 (per capita personal income). | no, downloaded (17 MB) |
| `data/raw/us.1969_2024.20ages.adjusted.txt.gz` | NCI SEER county population by 5-year age group. Used for the share aged 15–24. | no, downloaded (78 MB) |

Raw files are never edited. Each script downloads a missing raw file from the URL listed at its top.
BEA and SEER revise their files, so a fresh download can differ slightly from the vintage used here
(BEA release of August 2026, SEER 1969–2024 release, NIAAA file updated March 2025).

## Layout

```
run_all.R                       runs every script in order, then writes output/session_info.txt
R/functions.R                   synthetic control fit, placebo test, tables and plots (no side effects)
R/01_clean_and_describe.R       raw CDC CSV -> state-year panel, donor pool, descriptive table, trend figure
R/02_build_covariates.R         adds log income, share aged 15-24 and beer per capita -> data/clean/panel_cov.csv
R/03_replicate_california.R     synthetic California and placebo inference (replication of ADH 2010)
R/04_massachusetts_scm.R        synthetic Massachusetts and placebo inference
R/05_did_sdid.R                 TWFE DiD, event study, synthetic DiD, implied price elasticity
R/06_robustness.R               in-time placebo, no-neighbour donor pool, alternative predictors,
                                alternative timing, leave-one-out
data/raw/                       untouched downloaded data
data/clean/                     generated analysis panels (not in git)
output/                         generated tables (.tex), figures (.pdf) and fitted objects (.rds)
report/main.tex                 the report; it reads tables and figures from output/
```

## Reproduce

Requires R (tested with 4.2.3) and the packages `data.table`, `ggplot2`, `Synth`, `fixest`
and `synthdid` (GitHub only: `remotes::install_github("synth-inference/synthdid")`). Exact
package versions are in `output/session_info.txt`.

From the project root:

```
Rscript run_all.R                # about 15 minutes
cd report && latexmk -pdf main.tex
```

Every script also runs on its own (`Rscript R/04_massachusetts_scm.R`), provided the scripts
before it have been run. All paths are relative to the project root. The DiD script sets a
seed (5200) for the synthdid placebo standard errors; the other scripts are deterministic.

## Conventions

- Fiscal 1993 is Massachusetts' first treated year (the tax rose in January 1993), the same
  convention ADH use for California's January 1989 increase. `R/06_robustness.R` checks 1994.
- Donor pool: the 38 states of ADH (2010). DC, states with large tobacco programs (AZ, CA, FL,
  MA, OR) and states with tax increases of 50 cents or more in 1989–2000 (AK, HI, MD, MI, NJ, NY,
  WA) are excluded.
