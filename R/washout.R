# Act 2 reverse-causation washout. Frail people are often both less active and
# close to death, which would inflate the activity benefit. Dropping everyone
# who died within the first two years and re-estimating on the survivors shows
# how much of the five-year effect survives once that window is removed. The
# propensity weights are refit on the reduced sample, so the comparison is
# fair and not just a reweighting of the original fit.

library(here)
library(WeightIt)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

boot_draws <- 500

# The reverse-causation window: deaths inside the first two years of follow-up.
drop_early <- function(df) dplyr::filter(df, !(event == 1 & time < 24))

rd_stat <- function(df) {
  km_risk_difference(df, ipw(df, adjusters_activity)$weights, months_5yr)$rd
}

dat  <- arm(frame, met_guideline, adjusters_activity)
full <- rd_stat(dat)

wash_dat <- drop_early(dat)
wash     <- rd_stat(wash_dat)
wash_ci  <- boot_ci(wash_dat, rd_stat, boot_draws, 1)

readr::write_csv(
  tibble::tibble(
    sample  = c("full", "washout"),
    rd      = round(c(full, wash), 4),
    ci_low  = c(NA, round(wash_ci[1], 4)),
    ci_high = c(NA, round(wash_ci[2], 4))
  ),
  file.path(dirs$tables, "washout_rd.csv"))

message("Washout drops ", sum(dat$event == 1 & dat$time < 24),
        " deaths in the first two years.")
message("Full five-year risk difference ", round(full, 4), ".")
message("Washout five-year risk difference ", round(wash, 4),
        " (95% CI ", round(wash_ci[1], 4), " to ", round(wash_ci[2], 4), ").")