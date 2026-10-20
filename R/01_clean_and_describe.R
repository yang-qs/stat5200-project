# 01_clean_and_describe.R
# Build a state-year panel from the CDC "Tax Burden on Tobacco" data and
# compute descriptive statistics for the project proposal (HW4, Q1).
#
# Input : data/raw/tax_burden_tobacco_1970_2019.csv
#         (CDC STATE System, dataset 7nwe-3aj9; Orzechowski & Walker)
# Note  : O&W data are by fiscal year ending June 30, so a tax change
#         effective January 1993 first appears in the 1994 observation.
# Output: data/clean/panel.csv, output/desc_stats.tex, output/trends.pdf
#
# Run from the project root:  Rscript R/01_clean_and_describe.R

library(data.table)
library(ggplot2)

raw_path <- "data/raw/tax_burden_tobacco_1970_2019.csv"
if (!file.exists(raw_path)) {
  dir.create(dirname(raw_path), recursive = TRUE, showWarnings = FALSE)
  download.file("https://data.cdc.gov/api/views/7nwe-3aj9/rows.csv?accessType=DOWNLOAD",
                raw_path, mode = "wb")
}
dir.create("data/clean", showWarnings = FALSE)
dir.create("output", showWarnings = FALSE)

# ---- Reshape long -> wide (one row per state-year) ----
raw <- fread(raw_path)
measure_names <- c(
  "Cigarette Consumption (Pack Sales Per Capita)"         = "packs_pc",
  "Average Cost per pack"                                 = "price",
  "State Tax per pack"                                    = "state_tax",
  "Federal and State Tax per pack"                        = "total_tax"
)
raw <- raw[SubMeasureDesc %in% names(measure_names)]
raw[, var := measure_names[SubMeasureDesc]]
panel <- dcast(raw, LocationAbbr + LocationDesc + Year ~ var, value.var = "Data_Value")
setnames(panel, c("LocationAbbr", "LocationDesc", "Year"), c("state", "state_name", "year"))
# The published "tax as % of retail price" series has recording errors
# (e.g., MA 1993 = 89.3%, MN 1989 = 83.8%), so recompute it from its components.
panel[, tax_share := 100 * total_tax / price]
panel[, total_tax := NULL]

# ---- Analysis sample ----
# Donor pool follows Abadie, Diamond & Hainmueller (2010): drop DC, states that
# adopted large tobacco-control programs (CA, MA, AZ, OR, FL), and states that
# raised cigarette taxes by >= 50 cents in 1989-2000 (AK, HI, MD, MI, NJ, NY, WA).
excluded <- c("DC", "CA", "MA", "AZ", "OR", "FL", "AK", "HI", "MD", "MI", "NJ", "NY", "WA")
panel[, group := fifelse(state == "MA", "Massachusetts",
                 fifelse(state == "CA", "California",
                 fifelse(state %in% excluded, "Excluded", "Donor pool")))]
panel <- panel[year <= 2000]
stopifnot(panel[group == "Donor pool", uniqueN(state)] == 38)
fwrite(panel, "data/clean/panel.csv")

# ---- Descriptive statistics: MA vs donor pool, pre (1970-92) vs post (1993-2000) ----
panel[, period := fifelse(year <= 1992, "1970--1992", "1993--2000")]
vars <- c(packs_pc = "Packs per capita", price = "Retail price (\\$/pack)",
          state_tax = "State tax (\\$/pack)", tax_share = "Tax share of price (\\%)")
desc <- panel[group %in% c("Massachusetts", "Donor pool"),
              lapply(.SD, function(x) sprintf("%.2f (%.2f)", mean(x), sd(x))),
              by = .(group, period), .SDcols = names(vars)]
desc <- melt(desc, id.vars = c("group", "period"))
desc <- dcast(desc, variable ~ group + period, value.var = "value")
desc[, variable := vars[as.character(variable)]]
print(desc)

tex <- c("\\begin{tabular}{lcccc}", "\\toprule",
         " & \\multicolumn{2}{c}{Massachusetts} & \\multicolumn{2}{c}{Donor pool (38 states)} \\\\",
         "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
         " & 1970--92 & 1993--2000 & 1970--92 & 1993--2000 \\\\", "\\midrule",
         desc[, sprintf("%s & %s & %s & %s & %s \\\\", variable,
                        `Massachusetts_1970--1992`, `Massachusetts_1993--2000`,
                        `Donor pool_1970--1992`, `Donor pool_1993--2000`)],
         "\\bottomrule", "\\end{tabular}")
writeLines(tex, "output/desc_stats.tex")

# Raw DiD of means, as a first look (not a causal estimate)
m <- panel[group %in% c("Massachusetts", "Donor pool"), .(packs = mean(packs_pc)), by = .(group, period)]
m <- dcast(m, group ~ period, value.var = "packs")
cat("\nMean packs per capita:\n"); print(m)
did <- (m[group == "Massachusetts", `1993--2000`] - m[group == "Massachusetts", `1970--1992`]) -
       (m[group == "Donor pool", `1993--2000`] - m[group == "Donor pool", `1970--1992`])
cat("Naive DiD estimate:", round(did, 2), "packs per capita\n")

# ---- Figure: per-capita sales, MA and CA vs donor-pool average ----
avg <- panel[group == "Donor pool", .(packs_pc = mean(packs_pc)), by = year][, group := "Donor-pool average"]
fig_dat <- rbind(panel[group %in% c("Massachusetts", "California"), .(year, packs_pc, group)], avg)
p <- ggplot(fig_dat, aes(year, packs_pc, linetype = group, colour = group)) +
  geom_line(linewidth = 0.8) +
  geom_vline(xintercept = c(1988.5, 1992.5), linetype = "dotted") +
  annotate("text", x = c(1988.3, 1992.7), y = 40, hjust = c(1, 0), size = 3,
           label = c("Prop. 99 (CA)", "Question 1 (MA)")) +
  scale_colour_manual(values = c("grey40", "black", "#1f5fa8")) +
  labs(x = NULL, y = "Cigarette sales (packs per capita)", colour = NULL, linetype = NULL) +
  theme_bw() + theme(legend.position = "bottom")
ggsave("output/trends.pdf", p, width = 6.5, height = 3.6)
