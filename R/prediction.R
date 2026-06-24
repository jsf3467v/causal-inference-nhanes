# Act 1 training. A random survival forest for time to death, using every
# cycle's real follow-up rather than a censored five-year label. BMI is a
# predictor here. Act 2 drops it as a mediator on the causal side.
# Cohort entry comes from shared.R. Scoring lives in prediction_eval.R.

library(here)
library(dplyr)
library(rsample)
library(recipes)
library(survival)
library(ranger)

source(here("R", "paths.R"))
source(here("R", "shared.R"))

frame <- readRDS(file.path(dirs$processed, "analysis_frame.rds"))

model_data <- function(df) {
  study(df) |>
    transmute(time = follow_months, event = died,
              age, sex, race, education, income_ratio, smoke, prior_disease, bmi)
}

recipe_spec <- function(train) {
  recipe(~ age + sex + race + education + income_ratio +
           smoke + prior_disease + bmi, data = train) |>
    step_impute_median(all_numeric_predictors()) |>
    step_unknown(all_nominal_predictors()) |>
    step_dummy(all_nominal_predictors()) |>
    step_zv(all_predictors())
}

# Split seed and forest seed are placed where each source of randomness is.
set.seed(1)
md    <- model_data(frame)
parts <- initial_split(md, prop = 0.75, strata = event)
train <- training(parts)
test  <- testing(parts)

rec    <- prep(recipe_spec(train), training = train)
dat_tr <- bake(rec, train) |> mutate(time = train$time, event = train$event)

forest <- ranger(Surv(time, event) ~ ., data = dat_tr,
                 num.trees = 500, importance = "permutation", seed = 1)

saveRDS(list(forest = forest, recipe = rec, test = test),
        file.path(dirs$processed, "prediction_model.rds"))

message("Trained on ", nrow(train), " participants, out-of-bag C-index ",
        formatC(1 - forest$prediction.error, format = "f", digits = 3), ".")

