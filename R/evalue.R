# Act 2 E-value. How strong an unmeasured confounder would have to be, on the
# risk-ratio scale, to explain away the activity effect. Reads the weighted
# five-year arm risks, forms the risk ratio, and reports the E-value for the
# estimate and for the confidence limit nearest the null.

library(here)
library(WeightIt)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

boot_draws <- 500

e_value <- function(rr) {
  r <- if (rr < 1) 1 / rr else rr
  r + sqrt(r * (r - 1))
}

rr_stat <- function(df) {
  r <- km_risk_difference(df, ipw(df, adjusters_activity)$weights, months_5yr)
  r$risk_treated / r$risk_control
}

dat <- arm(frame, met_guideline, adjusters_activity)
rr  <- rr_stat(dat)
ci  <- boot_ci(dat, rr_stat, boot_draws, 1)

near    <- if (rr < 1) ci[2] else ci[1]
crosses <- (rr < 1 && near >= 1) || (rr > 1 && near <= 1)
ev_pt   <- e_value(rr)
ev_ci   <- if (crosses) 1 else e_value(near)

readr::write_csv(
  tibble::tibble(measure = c("risk_ratio", "e_value_estimate", "e_value_limit"),
                 value = round(c(rr, ev_pt, ev_ci), 3)),
  file.path(dirs$tables, "evalue.csv"))

message("Risk ratio ", round(rr, 3), " at five years.")
message("E-value ", round(ev_pt, 2), " for the estimate and ",
        round(ev_ci, 2), " for the confidence limit.")
