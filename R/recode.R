# Derives the analysis frame from the raw bundle.
# Exposure is leisure-time aerobic activity in moderate-equivalent minutes.
# Sentinel codes for refused and do not know map to missing.

na_high <- function(x, cap) {
  dplyr::if_else(as.numeric(x) >= cap, NA_real_, as.numeric(x))
}

exposure <- function(paq) {
  paq |>
    dplyr::transmute(
      SEQN,
      vig_days = na_high(PAQ655, 77), vig_min = na_high(PAD660, 7777),
      mod_days = na_high(PAQ670, 77), mod_min = na_high(PAD675, 7777),
      vig_week = dplyr::case_when(PAQ650 == 2 ~ 0, PAQ650 == 1 ~ vig_days * vig_min),
      mod_week = dplyr::case_when(PAQ665 == 2 ~ 0, PAQ665 == 1 ~ mod_days * mod_min),
      active_min = mod_week + 2 * vig_week,
      met_guideline = dplyr::if_else(active_min >= 150, 1L, 0L)
    ) |>
    dplyr::select(SEQN, active_min, met_guideline)
}

smoking <- function(smq) {
  smq |>
    dplyr::transmute(
      SEQN,
      smoke = dplyr::case_when(
        SMQ020 == 2 ~ "never",
        SMQ020 == 1 & SMQ040 == 3 ~ "former",
        SMQ020 == 1 & SMQ040 %in% c(1, 2) ~ "current"
      )
    )
}

comorbidity <- function(mcq) {
  yes_no <- function(x) {
    dplyr::if_else(x == 1, 1L, dplyr::if_else(x == 2, 0L, NA_integer_))
  }
  mcq |>
    dplyr::transmute(
      SEQN,
      prior_disease = dplyr::if_else(
        yes_no(MCQ160C) == 1 | yes_no(MCQ160F) == 1 | yes_no(MCQ220) == 1,
        1L, 0L)
    )
}

outcome <- function(mort) {
  mort |>
    dplyr::transmute(
      SEQN,
      eligible_mort = dplyr::if_else(eligstat == 1, 1L, 0L),
      died = mortstat,
      follow_months = permth_exm,
      ucod
    )
}

covariates <- function(demo) {
  n_cycles <- dplyr::n_distinct(demo$cycle)
  demo |>
    dplyr::transmute(
      SEQN,
      age = RIDAGEYR,
      sex = dplyr::case_when(RIAGENDR == 1 ~ "male",
                             RIAGENDR == 2 ~ "female"),
      race = factor(RIDRETH1, levels = 1:5,
                    labels = c("Mexican American", "Other Hispanic",
                               "Non-Hispanic White", "Non-Hispanic Black",
                               "Other or multiracial")),
      education = factor(na_high(DMDEDUC2, 7), levels = 1:5,
                         labels = c("Less than 9th grade", "9th to 11th grade",
                                    "High school or GED", "Some college or AA",
                                    "College graduate")),
      income_ratio = INDFMPIR,
      cycle = factor(cycle),
      psu = SDMVPSU, strata = SDMVSTRA,
      pooled_weight = WTMEC2YR / n_cycles
    )
}

analysis_frame <- function(raw) {
  covariates(raw$demo) |>
    dplyr::left_join(exposure(raw$paq), by = "SEQN") |>
    dplyr::left_join(smoking(raw$smq), by = "SEQN") |>
    dplyr::left_join(comorbidity(raw$mcq), by = "SEQN") |>
    dplyr::left_join(dplyr::transmute(raw$bmx, SEQN, bmi = BMXBMI), by = "SEQN") |>
    dplyr::left_join(outcome(raw$mort), by = "SEQN") |>
    dplyr::mutate(row_id = dplyr::row_number())
}
