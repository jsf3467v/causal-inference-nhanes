# Cohort description. Table 1 is survey weighted so the described cohort and
# the analyzed population match. The cohort rule comes from estimate.R.

cohort_flow <- function(frame) {
  base   <- frame$age >= 40 & frame$eligible_mort == 1
  follow <- base & !is.na(frame$follow_months) & !is.na(frame$died)
  tibble::tibble(
    step = c("all", "age 40 plus", "mortality eligible",
             "exam follow-up", "exposure known"),
    n = c(nrow(frame),
          sum(frame$age >= 40, na.rm = TRUE),
          sum(base, na.rm = TRUE),
          sum(follow, na.rm = TRUE),
          sum(follow & !is.na(frame$met_guideline), na.rm = TRUE)))
}

study_cohort <- function(frame) {
  dplyr::filter(study(frame), !is.na(met_guideline))
}

# Analysis variables only. Cause of death is blank for survivors by design
# and bookkeeping columns cannot be missing, so neither belongs here.
missingness <- function(cohort) {
  vars <- c("age", "sex", "race", "education", "income_ratio", "smoke",
            "prior_disease", "bmi", "active_min")
  tibble::tibble(
    variable = vars,
    fraction_missing = vapply(cohort[vars], function(x) mean(is.na(x)),
                              numeric(1))) |>
    dplyr::arrange(dplyr::desc(fraction_missing))
}

table_one_text <- function(frame) {
  vars <- c("age", "sex", "race", "education", "income_ratio", "smoke",
            "prior_disease", "bmi", "cycle", "died", "follow_months")
  design <- subset(survey_design(frame),
                   row_id %in% study_cohort(frame)$row_id)
  one <- tableone::svyCreateTableOne(vars = vars, strata = "met_guideline",
                                     data = design, test = FALSE)
  utils::capture.output(print(one, smd = TRUE))
}

minutes_figure <- function(cohort, path) {
  plot <- ggplot2::ggplot(cohort, ggplot2::aes(x = pmin(active_min, 600))) +
    ggplot2::geom_histogram(bins = 40) +
    ggplot2::geom_vline(xintercept = 150) +
    ggplot2::labs(x = "Weekly moderate-equivalent leisure minutes, capped at 600",
                  y = "Participants")
  figure_file(plot, path, width = 7, height = 4)
}

# Flat unadjusted export behind the Tableau dashboard.
dashboard_table <- function(cohort) {
  dplyr::transmute(cohort, age, sex, race, education, income_ratio, smoke,
                   active_min, met_guideline, prior_disease, bmi,
                   died, follow_months)
}
