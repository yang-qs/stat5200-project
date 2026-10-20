# STAT 5200 Final Project: Massachusetts' 1992 Tobacco Control Initiative

Does Massachusetts' Question 1 (1992) — a 25-cent cigarette tax increase that funded the
Massachusetts Tobacco Control Program — reduce per-capita cigarette sales? The project first
replicates Abadie, Diamond & Hainmueller (2010, *JASA*) for California's Proposition 99 and then
applies the same synthetic control design (plus DiD / synthetic DiD as comparisons) to Massachusetts.

## Data
CDC STATE System, *The Tax Burden on Tobacco, 1970–2019* (Orzechowski & Walker), dataset
[`7nwe-3aj9`](https://data.cdc.gov/Policy/The-Tax-Burden-on-Tobacco-1970-2019/7nwe-3aj9).
Downloaded automatically by `R/01_clean_and_describe.R` if `data/raw/` is empty.
Values are by fiscal year ending June 30.

## Layout
```
R/01_clean_and_describe.R   raw CSV -> state-year panel, descriptive statistics, trend figure
data/raw/                   untouched downloaded data
data/clean/panel.csv        analysis panel (generated)
output/                     tables and figures (generated)
```

## Reproduce
From this directory: `Rscript R/01_clean_and_describe.R` (needs `data.table`, `ggplot2`).
