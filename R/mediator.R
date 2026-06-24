# Act 2 mediator sensitivity. BMI may sit on the pathway from activity to death,
# so the main estimate leaves it out. Both estimates here run on the same
# participants with measured BMI, one without BMI in the propensity model and
# one with it, so the pair brackets the effect.

library(here)
library(WeightIt)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

boot_draws <- 500

# BMI enters only here, as the mediator under test. Every other script keeps it out.
adjusters_bmi <- c(adjusters_activity, "bmi")

rd_base <- function(df) {
  km_risk_difference(df, ipw(df, adjusters_activity)$weights, months_5yr)$rd
}

rd_with_bmi <- function(df) {
  km_risk_difference(df, ipw(df, adjusters_bmi)$weights, months_5yr)$rd
}

# Shared sample. Carrying BMI as a column drops the BMI-missing rows once, so the
# two fits differ only by the propensity model and not by who is in it.
dat <- arm(frame, met_guideline, adjusters_bmi)

base    <- rd_base(dat)
withbmi <- rd_with_bmi(dat)
ci_base    <- boot_ci(dat, rd_base, boot_draws, 1)
ci_withbmi <- boot_ci(dat, rd_with_bmi, boot_draws, 1)

readr::write_csv(
  tibble::tibble(adjustment = c("base", "with_bmi"),
                 months = months_5yr,
                 rd = round(c(base, withbmi), 4),
                 ci_low = round(c(ci_base[1], ci_withbmi[1]), 4),
                 ci_high = round(c(ci_base[2], ci_withbmi[2]), 4)),
  file.path(dirs$tables, "mediator_rd.csv"))

message("Mediator sensitivity on ", nrow(dat),
        " participants with measured body mass index.")
message("Base five-year risk difference ", round(base, 4),
        " (95% CI ", round(ci_base[1], 4), " to ", round(ci_base[2], 4), ").")
message("With BMI five-year risk difference ", round(withbmi, 4),
        " (95% CI ", round(ci_withbmi[1], 4), " to ", round(ci_withbmi[2], 4), ").")
