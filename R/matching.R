# Act 2, propensity-score matching estimate of the activity effect on
# five-year mortality. Matching delivers balance, the risk difference is read
# off the matched survival curve so late cycles keep their censored survivors.

library(here)
library(ggplot2)
library(MatchIt)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

matched_fit <- function(df) {
  matchit(reformulate(adjusters_activity, "treat"), data = df,
          method = "nearest", caliper = 0.2, estimand = "ATT")
}

dat <- arm(frame, met_guideline, adjusters_activity)

# Seed covers tie breaking in nearest matching.
set.seed(1)
m  <- matched_fit(dat)
md <- match.data(m, weights = "wt")
rd <- km_risk_difference(md, md$wt, months_5yr)$rd

ggsave(file.path(dirs$figures, "love_matching.png"), balance_plot(m),
       width = 7, height = 5, dpi = 150)
readr::write_csv(tibble::tibble(months = months_5yr, rd = round(rd, 4)),
                 file.path(dirs$tables, "matching_rd.csv"))

message("Matched ", sum(m$weights > 0), " of ", nrow(dat), " participants.")
message("Matched five-year mortality risk difference ", round(rd, 4), ".")
