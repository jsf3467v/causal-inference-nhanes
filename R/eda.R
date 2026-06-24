# EDA on the study cohort of adults age 40 and older.
# Writes a cohort flow, a missingness table, a Table 1 with standardized mean
# differences, and the weekly activity distribution. The cohort rule comes from
# shared.R so the reported counts match what the models run on.

library(here)
library(dplyr)
library(ggplot2)
library(tableone)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

cohort_flow <- function(df) {
  base <- df$age >= 40 & df$eligible_mort == 1
  follow <- base & !is.na(df$follow_months) & !is.na(df$died)
  tibble::tibble(
    step = c("all", "age 40 plus", "mortality eligible",
             "exam follow-up", "exposure known"),
    n = c(nrow(df),
          sum(df$age >= 40, na.rm = TRUE),
          sum(base, na.rm = TRUE),
          sum(follow, na.rm = TRUE),
          sum(follow & !is.na(df$met_guideline), na.rm = TRUE))
  )
}

missingness <- function(df) {
  df |>
    summarise(across(everything(), ~ mean(is.na(.)))) |>
    tidyr::pivot_longer(everything(), names_to = "variable",
                        values_to = "fraction_missing") |>
    arrange(desc(fraction_missing))
}

table_one <- function(df) {
  vars <- c("age", "sex", "race", "education", "income_ratio",
            "smoke", "prior_disease", "bmi", "died", "follow_months")
  tableone::CreateTableOne(vars = vars, strata = "met_guideline",
                           data = df, test = FALSE)
}

minutes_plot <- function(df) {
  ggplot(df, aes(x = pmin(active_min, 600))) +
    geom_histogram(bins = 40) +
    geom_vline(xintercept = 150) +
    labs(x = "Weekly moderate-equivalent leisure minutes, capped at 600",
         y = "Participants")
}

study_cohort <- study(frame) |> filter(!is.na(met_guideline))

readr::write_csv(cohort_flow(frame), file.path(dirs$tables, "cohort_flow.csv"))
readr::write_csv(missingness(study_cohort), file.path(dirs$tables, "missingness.csv"))
writeLines(
  capture.output(print(table_one(study_cohort), smd = TRUE, printToggle = TRUE)),
  file.path(dirs$tables, "table_one.txt")
)
ggsave(file.path(dirs$figures, "weekly_minutes.png"),
       minutes_plot(study_cohort), width = 7, height = 4, dpi = 150)

message("Study cohort ", nrow(study_cohort), " adults age 40 and older.")
message("Met guideline ", sum(study_cohort$met_guideline == 1), " of ",
        nrow(study_cohort), ".")
message("Deaths ", sum(study_cohort$died == 1, na.rm = TRUE),
        " over median ", round(median(study_cohort$follow_months, na.rm = TRUE)),
        " months.")
