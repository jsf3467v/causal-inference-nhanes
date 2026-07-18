# An export for Tableau dashboard. This is the unadjusted,
# exploratory analysis that pairs with the project as a causal report. It writes one flat row per study
# participant with demographics, activity, and mortality, so a dashboard can
# show the raw gradients that the report later adjusts away.

library(here)
library(dplyr)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

descriptive <- function(df) {
  study(df) |>
    filter(!is.na(met_guideline)) |>
    transmute(age, sex, race, education, income_ratio, smoke,
              active_min, met_guideline, prior_disease, bmi,
              died, follow_months)
}

dat <- descriptive(frame)

out_dir <- here("dashboard")
dir.create(out_dir, showWarnings = FALSE)
out_file <- file.path(out_dir, "cohort_descriptive.csv")
readr::write_csv(dat, out_file)

message("Descriptive cohort written for ", nrow(dat), " participants to ", out_file, ".")
