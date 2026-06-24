# Act 1 scoring. Loads the saved forest and held-out test set, then reports
# five-year discrimination and calibration with censoring handled correctly.
# Discrimination is the time-dependent AUROC at 60 months, the analog of a
# plain AUROC. Calibration compares predicted risk to observed Kaplan-Meier.

library(here)
library(dplyr)
library(ggplot2)
library(recipes)
library(survival)
library(ranger)
library(timeROC)

source(here("R", "paths.R"))

horizon <- 60
obj  <- readRDS(file.path(dirs$processed, "prediction_model.rds"))
test <- obj$test

dat_te <- bake(obj$recipe, test) |> mutate(time = test$time, event = test$event)
pred   <- predict(obj$forest, dat_te)
times  <- obj$forest$unique.death.times
risk5  <- 1 - pred$survival[, max(which(times <= horizon))]

# Observed five-year risk in a slice, one minus the Kaplan-Meier survival.
km_risk <- function(time, event, t) {
  f <- survfit(Surv(time, event) ~ 1)
  1 - summary(f, times = t, extend = TRUE)$surv
}

calibration_plot <- function(risk, time, event, t) {
  tibble(risk, time, event) |>
    mutate(bin = ntile(risk, 10)) |>
    group_by(bin) |>
    summarise(predicted = mean(risk),
              observed = km_risk(time, event, t), .groups = "drop") |>
    ggplot(aes(predicted, observed)) +
    geom_abline(linetype = 2, color = "grey60") +
    geom_line(color = "#1D9E75", linewidth = 1) +
    geom_point(color = "#1D9E75", size = 3) +
    labs(x = "Mean predicted risk", y = "Observed mortality") +
    theme_minimal(base_size = 13)
}

importance_plot <- function(forest) {
  tibble(variable = names(forest$variable.importance),
         importance = forest$variable.importance) |>
    mutate(group = case_when(
      startsWith(variable, "race_")      ~ "race",
      startsWith(variable, "education_") ~ "education",
      startsWith(variable, "smoke_")     ~ "smoke",
      startsWith(variable, "sex_")       ~ "sex",
      TRUE ~ variable)) |>
    group_by(group) |>
    summarise(importance = sum(importance), .groups = "drop") |>
    ggplot(aes(reorder(group, importance), importance, fill = importance)) +
    geom_col(width = 0.7) +
    scale_fill_viridis_c(option = "D", guide = "none") +
    coord_flip() +
    labs(x = NULL, y = "Permutation importance") +
    theme_minimal(base_size = 13)
}

scored <- timeROC(T = test$time, delta = test$event, marker = risk5,
                  cause = 1, times = horizon)
auc60  <- tail(na.omit(as.numeric(scored$AUC)), 1)
cindex <- 1 - obj$forest$prediction.error

ggsave(file.path(dirs$figures, "calibration.png"),
       calibration_plot(risk5, test$time, test$event, horizon),
       width = 5, height = 5, dpi = 150)
ggsave(file.path(dirs$figures, "importance.png"),
       importance_plot(obj$forest), width = 7, height = 5, dpi = 150)
readr::write_csv(
  tibble::tibble(metric = c("auroc_60mo", "c_index_oob"),
                 value = round(c(auc60, cindex), 3)),
  file.path(dirs$tables, "prediction_scores.csv"))

message("Test five-year AUROC ", formatC(auc60, format = "f", digits = 3),
        " and out-of-bag C-index ", formatC(cindex, format = "f", digits = 3), ".")

