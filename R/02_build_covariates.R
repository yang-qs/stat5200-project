# 02_build_covariates.R
# Add the synthetic-control predictors of Abadie, Diamond & Hainmueller (2010)
# to the state-year panel built by 01_clean_and_describe.R.
#
# Input : data/clean/panel.csv
#         data/raw/SAINC.zip                            (BEA, per capita personal income)
#         data/raw/us.1969_2024.20ages.adjusted.txt.gz  (NCI SEER, population by age)
#         data/raw/pcyr1970-2023.txt                    (NIAAA, beer sales by state)
#         Raw files are downloaded if missing.
# Note  : covariates are calendar-year values; cigarette sales are fiscal-year
#         values (year ending June 30). The covariates enter the synthetic control
#         only as multi-year averages, so the half-year offset is immaterial.
# Output: data/clean/panel_cov.csv
#
# Run from the project root:  Rscript R/02_build_covariates.R

library(data.table)

raw_files <- c(
  "data/raw/SAINC.zip" =
    "https://apps.bea.gov/regional/zip/SAINC.zip",
  "data/raw/us.1969_2024.20ages.adjusted.txt.gz" =
    "https://seer.cancer.gov/popdata/yr1969_2024.20ages/us.1969_2024.20ages.adjusted.txt.gz",
  "data/raw/pcyr1970-2023.txt" =
    "https://www.niaaa.nih.gov/sites/default/files/pcyr1970-2023.txt"
)
for (f in names(raw_files)) {
  if (!file.exists(f)) download.file(raw_files[[f]], f, mode = "wb")
}

panel <- fread("data/clean/panel.csv")
# BEA marks Alaska and Hawaii with " *"; the CSV ends with footnote lines.
bea <- fread(cmd = "unzip -p data/raw/SAINC.zip SAINC1__ALL_AREAS_1929_2025.csv",
             colClasses = "character", fill = TRUE)
bea <- bea[LineCode == "3" & as.integer(GeoFIPS) %between% c(1000, 56000)]
bea[, state_name := sub(" \\*$", "", GeoName)]
fips <- bea[, .(fips = as.integer(GeoFIPS) / 1000, state_name)]

# ---- Income: log per capita personal income (BEA SAINC1, line 3) ----
# ADH use log GDP per capita. Nominal dollars are fine here: every state is
# compared over the same years, so a common price deflator cancels out.
bea <- melt(bea, id.vars = "state_name", measure.vars = as.character(1970:2000),
            variable.name = "year", value.name = "income_pc")
bea[, `:=`(year = as.integer(as.character(year)),
           lnincome = log(as.numeric(income_pc)))]
income <- bea[, .(state_name, year, lnincome)]

# ---- Age structure: share of population aged 15-24 (SEER, county level) ----
# Fixed-width layout: year 1-4, state 5-6, age group 17-18, population 19-26.
# Age groups 04 and 05 are ages 15-19 and 20-24. The file has ~20 million
# county rows, so awk cuts it down to 1970-2000 before R reads it.
seer <- fread(cmd = paste(
  "gzcat data/raw/us.1969_2024.20ages.adjusted.txt.gz | awk '{y = substr($0, 1, 4);",
  "if (y >= 1970 && y <= 2000) print y \",\" substr($0, 5, 2) \",\" substr($0, 17, 2)",
  "\",\" substr($0, 19, 8)}'"),
  header = FALSE, col.names = c("year", "state", "age", "pop"))
age <- seer[, .(age15to24 = 100 * sum(pop[age %in% 4:5]) / sum(pop)), by = .(state, year)]
rm(seer)

# ---- Beer: gallons of beer per capita aged 14+ (NIAAA, beverage type 3) ----
niaaa <- fread(cmd = "grep -E '^[0-9]{4} ' data/raw/pcyr1970-2023.txt",
               header = FALSE, sep = "\n", col.names = "line")
# The documented column positions are off by one in this release, so split
# on whitespace: year, FIPS, beverage type, gallons, ethanol, population 14+.
niaaa[, c("year", "fips", "type", "gallons", "ethanol", "pop14") :=
        lapply(tstrsplit(trimws(line), " +")[1:6], as.numeric)]
beer <- niaaa[type == 3 & year %between% c(1970, 2000) & fips <= 56,
              .(fips, year, beer = gallons / pop14)]
beer <- merge(beer, fips, by = "fips")[, fips := NULL]

# ---- Merge ----
panel <- merge(panel, income, by = c("state_name", "year"), all.x = TRUE)
panel <- merge(panel, age, by = c("state", "year"), all.x = TRUE)
panel <- merge(panel, beer, by = c("state_name", "year"), all.x = TRUE)
setorder(panel, state, year)
stopifnot(panel[, .N] == 51 * 31,
          panel[, !anyNA(lnincome) && !anyNA(age15to24) && !anyNA(beer)])
fwrite(panel, "data/clean/panel_cov.csv")

print(panel[state %in% c("CA", "MA") & year %in% c(1975, 1985, 1992),
            .(state, year, packs_pc, price, lnincome, age15to24, beer)])
