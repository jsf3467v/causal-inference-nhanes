# Act 1. A random survival forest for time to death, fit on each person's
# real follow-up rather than a censored five-year label, so participants with
# short follow-up contribute instead of being discarded. Body mass index is a
# predictor here and a mediator in Act 2.
#
# Three partitions stratified on the event indicator. The node size is tuned
# on the validation partition, the final forest refits on training plus
# validation, and the test partition is read once. Tuning and final scoring
# share the definitions in R/scoring.R so the numbers are comparable.

forest_predictors <- c("age", "sex", "race", "education", "income_ratio",
                       "smoke", "prior_disease", "bmi")

# The chosen value currently sits at the top of this grid, which means the
# optimum has not been bracketed. Widening it is an open item; the grid stays
# as it is here so the committed tables reproduce.
forest_node_sizes <- c(5L, 15L, 45L, 135L, 405L)

forest_data <- function(frame) {
  study(frame) |>
    dplyr::transmute(time = follow_months, event = died,
                     dplyr::across(dplyr::all_of(forest_predictors)))
}

# Imputation and dummy coding learn from the training rows only, so the
# validation and test partitions stay untouched by the preparation.
forest_recipe <- function(train, vars) {
  spec <- recipes::recipe(~ ., data = train[vars]) |>
    recipes::step_impute_median(recipes::all_numeric_predictors()) |>
    recipes::step_unknown(recipes::all_nominal_predictors()) |>
    recipes::step_dummy(recipes::all_nominal_predictors()) |>
    recipes::step_zv(recipes::all_predictors())
  recipes::prep(spec, training = train[vars])
}

forest_matrix <- function(rec, part) {
  dplyr::mutate(recipes::bake(rec, part), time = part$time, event = part$event)
}

grow_forest <- function(dat, node_size, seed, importance = "none") {
  ranger::ranger(survival::Surv(time, event) ~ ., data = dat,
                 num.trees = 500, min.node.size = node_size,
                 importance = importance, seed = seed,
                 num.threads = forest_threads)
}

# Returns everything the scoring and figure targets need, so the forest is
# grown once and read many times.
forest_bundle <- function(frame, months, seed) {
  set.seed(seed)
  md    <- forest_data(frame)
  first <- rsample::initial_split(md, prop = 0.70, strata = event)
  train <- rsample::training(first)
  rest  <- rsample::initial_split(rsample::testing(first), prop = 0.50,
                                  strata = event)
  valid <- rsample::training(rest)
  test  <- rsample::testing(rest)

  rec    <- forest_recipe(train, forest_predictors)
  dat_tr <- forest_matrix(rec, train)
  dat_va <- forest_matrix(rec, valid)
  dat_te <- forest_matrix(rec, test)

  scored <- vapply(forest_node_sizes, function(size) {
    fit <- grow_forest(dat_tr, size, seed)
    auroc_horizon(dat_va$time, dat_va$event,
                  forest_risk(fit, dat_va, months), months)
  }, numeric(1))

  best   <- forest_node_sizes[which.max(scored)]
  tuning <- tibble::tibble(min_node_size = forest_node_sizes,
                           auroc_validation = scored,
                           chosen = forest_node_sizes == best)

  fit_on  <- dplyr::bind_rows(dat_tr, dat_va)
  forest  <- grow_forest(fit_on, best, seed, importance = "permutation")

  # An area under the curve is uninformative on its own when age is available
  # as a single predictor, so an age-only forest scores through the same
  # function as a reference.
  rec_age <- forest_recipe(train, "age")
  age_fit <- grow_forest(dplyr::bind_rows(forest_matrix(rec_age, train),
                                          forest_matrix(rec_age, valid)),
                         best, seed)

  list(forest = forest, forest_age = age_fit, node_size = best,
       tuning = tuning, test = dat_te, test_age = forest_matrix(rec_age, test))
}

forest_scores <- function(bundle, months) {
  full <- auroc_horizon(bundle$test$time, bundle$test$event,
                        forest_risk(bundle$forest, bundle$test, months), months)
  age  <- auroc_horizon(bundle$test_age$time, bundle$test_age$event,
                        forest_risk(bundle$forest_age, bundle$test_age, months),
                        months)
  tibble::tibble(metric = c("auroc_full", "auroc_age_only", "c_index_oob"),
                 value = c(full, age, 1 - bundle$forest$prediction.error))
}

# Observed risk in a slice of the test partition, one minus Kaplan-Meier,
# so censoring is handled rather than ignored.
observed_risk <- function(time, event, months) {
  fit <- survival::survfit(survival::Surv(time, event) ~ 1)
  1 - summary(fit, times = months, extend = TRUE)$surv
}

calibration_figure <- function(bundle, months, path) {
  points <- tibble::tibble(risk = forest_risk(bundle$forest, bundle$test, months),
                           time = bundle$test$time,
                           event = bundle$test$event) |>
    dplyr::mutate(bin = dplyr::ntile(risk, 10)) |>
    dplyr::group_by(bin) |>
    dplyr::summarise(predicted = mean(risk),
                     observed = observed_risk(time, event, months),
                     .groups = "drop")
  plot <- ggplot2::ggplot(points, ggplot2::aes(predicted, observed)) +
    ggplot2::geom_abline(linetype = 2, color = "grey60") +
    ggplot2::geom_line(color = "#1D9E75", linewidth = 1) +
    ggplot2::geom_point(color = "#1D9E75", size = 3) +
    ggplot2::labs(x = "Mean predicted risk", y = "Observed mortality") +
    ggplot2::theme_minimal(base_size = 13)
  figure_file(plot, path, width = 5, height = 5)
}

# Dummy columns are summed back to the variable they came from, so the plot
# reads in the units of the codebook rather than the design matrix.
importance_figure <- function(bundle, path) {
  imp <- bundle$forest$variable.importance
  grouped <- tibble::tibble(variable = names(imp), importance = as.numeric(imp)) |>
    dplyr::mutate(group = dplyr::case_when(
      startsWith(variable, "race_")      ~ "race",
      startsWith(variable, "education_") ~ "education",
      startsWith(variable, "smoke_")     ~ "smoke",
      startsWith(variable, "sex_")       ~ "sex",
      .default = variable)) |>
    dplyr::group_by(group) |>
    dplyr::summarise(importance = sum(importance), .groups = "drop")
  plot <- ggplot2::ggplot(grouped,
                          ggplot2::aes(stats::reorder(group, importance),
                                       importance, fill = importance)) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::scale_fill_viridis_c(option = "D", guide = "none") +
    ggplot2::coord_flip() +
    ggplot2::labs(x = NULL, y = "Permutation importance") +
    ggplot2::theme_minimal(base_size = 13)
  figure_file(plot, path, width = 7, height = 5)
}

roc_figure <- function(bundle, months, path) {
  scored <- timeROC::timeROC(T = bundle$test$time, delta = bundle$test$event,
                             marker = forest_risk(bundle$forest, bundle$test,
                                                  months),
                             cause = 1, times = months)
  col   <- match(months, scored$times)
  curve <- tibble::tibble(fpr = scored$FP[, col], tpr = scored$TP[, col])
  plot <- ggplot2::ggplot(curve, ggplot2::aes(fpr, tpr)) +
    ggplot2::geom_abline(linetype = 2, color = "grey60") +
    ggplot2::geom_line(color = "#1D6FB8", linewidth = 1) +
    ggplot2::coord_equal() +
    ggplot2::labs(x = "False positive rate", y = "True positive rate") +
    ggplot2::theme_minimal(base_size = 13)
  figure_file(plot, path, width = 5, height = 5)
}
