# Act 2 positive control. Current versus never smoking on five-year mortality,
# run through the same matching and weighting machinery as the activity effect
# and scored the same way. A clear positive risk difference confirms the
# pipeline detects a real effect.

library(here)
library(MatchIt)
library(WeightIt)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

dat <- arm(frame, case_when(smoke == "current" ~ 1L, smoke == "never" ~ 0L),
           adjusters_smoking)

matched_rd <- function(df) {
  set.seed(1)
  m  <- matchit(reformulate(adjusters_smoking, "treat"), data = df,
                method = "nearest", caliper = 0.2, estimand = "ATT")
  md <- match.data(m, weights = "wt")
  km_risk_difference(md, md$wt, months_5yr)$rd
}

weighted_rd <- function(df) {
  km_risk_difference(df, ipw(df, adjusters_smoking)$weights, months_5yr)$rd
}

mr <- matched_rd(dat)
wr <- weighted_rd(dat)

readr::write_csv(
  tibble::tibble(estimator = c("matched", "weighted"),
                 months = months_5yr, rd = round(c(mr, wr), 4)),
  file.path(dirs$tables, "positive_control_rd.csv"))

message("Positive control on ", nrow(dat), " current and never smokers.")
message("Matched five-year mortality risk difference ", round(mr, 4), ".")
message("Weighted five-year mortality risk difference ", round(wr, 4), ".")
