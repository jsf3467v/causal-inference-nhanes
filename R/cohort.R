# Derives the analysis frame from the raw bundle.
# Exposure is leisure-time aerobic activity in moderate-equivalent minutes.
# BMI is carried for description only and stays out of any adjustment set.

library(here)
library(dplyr)

source(here("R", "paths.R"))

raw <- readRDS(file.path(dirs$interim, "raw_bundle.rds"))

na_high <- function(x, cap) dplyr::if_else(as.numeric(x) >= cap, NA_real_, as.numeric(x))

exposure <- function(paq) {
  paq |>
    transmute(
      SEQN,
      vig_days = na_high(PAQ655, 77), vig_min = na_high(PAD660, 7777),
      mod_days = na_high(PAQ670, 77), mod_min = na_high(PAD675, 7777),
      vig_week = case_when(PAQ650 == 2 ~ 0, PAQ650 == 1 ~ vig_days * vig_min),
      mod_week = case_when(PAQ665 == 2 ~ 0, PAQ665 == 1 ~ mod_days * mod_min),
      active_min = mod_week + 2 * vig_week,
      met_guideline = dplyr::if_else(active_min >= 150, 1L, 0L)
    ) |>
    select(SEQN, active_min, met_guideline)
}

smoking <- function(smq) {
  smq |>
    transmute(
      SEQN,
      smoke = case_when(
        SMQ020 == 2 ~ "never",
        SMQ020 == 1 & SMQ040 == 3 ~ "former",
        SMQ020 == 1 & SMQ040 %in% c(1, 2) ~ "current"
      )
    )
}

comorbidity <- function(mcq) {
  yes_no <- function(x) dplyr::if_else(x == 1, 1L, dplyr::if_else(x == 2, 0L, NA_integer_))
  mcq |>
    transmute(
      SEQN,
      chd = yes_no(MCQ160C), stroke = yes_no(MCQ160F), cancer = yes_no(MCQ220),
      prior_disease = dplyr::if_else(chd == 1 | stroke == 1 | cancer == 1, 1L, 0L)
    )
}

outcome <- function(mort) {
  mort |>
    transmute(
      SEQN,
      eligible_mort = dplyr::if_else(eligstat == 1, 1L, 0L),
      died = mortstat,
      follow_months = permth_exm,
      ucod,
      early_death = dplyr::if_else(mortstat == 1 & permth_exm < 24, 1L, 0L)
    )
}

covariates <- function(demo) {
  n_cycles <- dplyr::n_distinct(demo$cycle)
  demo |>
    transmute(
      SEQN,
      age = RIDAGEYR,
      sex = dplyr::recode(RIAGENDR, `1` = "male", `2` = "female"),
      race = factor(RIDRETH1),
      # Education codes 7 and 9 are refused and do not know, so drop them.
      education = factor(na_high(DMDEDUC2, 7)),
      income_ratio = INDFMPIR,
      mec_weight = WTMEC2YR, psu = SDMVPSU, strata = SDMVSTRA,
      pooled_weight = WTMEC2YR / n_cycles
    )
}

analysis_frame <- function(raw) {
  covariates(raw$demo) |>
    left_join(exposure(raw$paq), by = "SEQN") |>
    left_join(smoking(raw$smq), by = "SEQN") |>
    left_join(comorbidity(raw$mcq), by = "SEQN") |>
    left_join(transmute(raw$bmx, SEQN, bmi = BMXBMI), by = "SEQN") |>
    left_join(outcome(raw$mort), by = "SEQN")
}

frame <- analysis_frame(raw)
saveRDS(frame, file.path(dirs$processed, "analysis_frame.rds"))
message("Analysis frame ", nrow(frame), " rows and ", ncol(frame), " columns.")

