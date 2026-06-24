# Act 2, inverse-probability weighting estimate (ATT) of the activity effect
# on five-year mortality. Weighting delivers balance, the risk difference is
# read off the weighted survival curve, the interval from a refit bootstrap.

library(here)
library(ggplot2)
library(WeightIt)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

boot_draws <- 500

control_ess <- function(w) {
  cw <- w$weights[w$treat == 0]
  sum(cw)^2 / sum(cw^2)
}

rd_stat <- function(df) {
  km_risk_difference(df, ipw(df, adjusters_activity)$weights, months_5yr)$rd
}

dat <- arm(frame, met_guideline, adjusters_activity)
w   <- ipw(dat, adjusters_activity)
rd  <- km_risk_difference(dat, w$weights, months_5yr)$rd
ci  <- boot_ci(dat, rd_stat, boot_draws, 1)

ggsave(file.path(dirs$figures, "love_weighting.png"), balance_plot(w),
       width = 7, height = 5, dpi = 150)
readr::write_csv(
  tibble::tibble(months = months_5yr, rd = round(rd, 4),
                 ci_low = round(ci[1], 4), ci_high = round(ci[2], 4)),
  file.path(dirs$tables, "weighting_rd.csv"))

message("Weighted ", nrow(dat), " participants, control effective size ",
        round(control_ess(w)), ".")
message("Weighted five-year mortality risk difference ", round(rd, 4),
        " (95% CI ", round(ci[1], 4), " to ", round(ci[2], 4), ").")
