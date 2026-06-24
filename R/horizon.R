# Horizon robustness. A ten-year binary landmark is biased here because
# follow-up ends in 2019, so later cycles lose their survivors. Instead this
# reads the ATT risk difference off a weighted Kaplan-Meier curve at five and
# ten years, using all follow-up, for activity and the smoking control alike.

library(here)
library(WeightIt)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

weighted_horizon <- function(df, adjusters, times) {
  km_risk_difference(df, ipw(df, adjusters)$weights, times)
}

times    <- c(months_5yr, months_10yr)
activity <- arm(frame, met_guideline, adjusters_activity)
smoking  <- arm(frame, case_when(smoke == "current" ~ 1L, smoke == "never" ~ 0L),
                adjusters_smoking)

act <- weighted_horizon(activity, adjusters_activity, times)
smk <- weighted_horizon(smoking,  adjusters_smoking,  times)

readr::write_csv(
  bind_rows(mutate(act, exposure = "activity"),
            mutate(smk, exposure = "smoking")) |>
    transmute(exposure, months, rd = round(rd, 4)),
  file.path(dirs$tables, "horizon_rd.csv"))

message("Activity risk difference, five-year ", round(act$rd[1], 4),
        " and ten-year ", round(act$rd[2], 4), ".")
message("Smoking risk difference, five-year ", round(smk$rd[1], 4),
        " and ten-year ", round(smk$rd[2], 4), ".")
