# Act 2 negative-control outcome. Activity has no plausible causal path to
# accidental death, leading-cause code 004, so its effect there should sit near
# zero once the confounders are balanced. A clear effect would flag residual
# confounding. Other-cause deaths are censored, so this reads cause-specific
# risk, which is sparse, so it is expected a wide interval around a small estimate.

library(here)
library(WeightIt)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

cause      <- "004"
boot_draws <- 500

control_arm <- function(df) {
  study(df) |>
    transmute(treat = met_guideline, time = follow_months,
              event = as.integer(died == 1 & ucod == cause),
              across(all_of(adjusters_activity))) |>
    filter(!is.na(treat)) |>
    na.omit()
}

rd_stat <- function(df) {
  km_risk_difference(df, ipw(df, adjusters_activity)$weights, months_5yr)$rd
}

dat <- control_arm(frame)
rd  <- rd_stat(dat)
ci  <- boot_ci(dat, rd_stat, boot_draws, 1)

readr::write_csv(
  tibble::tibble(outcome = "accidental_death", months = months_5yr,
                 deaths = sum(dat$event), rd = round(rd, 4),
                 ci_low = round(ci[1], 4), ci_high = round(ci[2], 4)),
  file.path(dirs$tables, "negative_control_rd.csv"))

message("Negative control on ", sum(dat$event), " accidental deaths.")
message("Activity five-year risk difference on accidental death ", round(rd, 4),
        " (95% CI ", round(ci[1], 4), " to ", round(ci[2], 4), ").")
