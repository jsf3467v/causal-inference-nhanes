# Pipeline graph. Reproduction is targets::tar_make() from the project root.
# Intermediate results cache to _targets/, so an interrupted run resumes at
# the first stale node. Three seeded operations exist in the project, which
# are the replicate weights, the data split, and the forest.

library(targets)
library(tarchetypes)

tar_source("R")

tar_option_set(
  packages = c("dplyr", "tibble", "purrr", "readr", "ggplot2",
               "haven", "survival", "survey", "svrep", "WeightIt", "cobalt",
               "dagitty", "tableone", "rsample", "recipes", "ranger",
               "timeROC", "DBI", "duckdb"),
  format = "rds"
)

options(timeout = 600)

months_5yr      <- 60
months_10yr     <- 120
landmark_origin <- 24
replicate_draws <- 500

list(
  tar_target(raw, raw_bundle()),
  tar_target(frame, analysis_frame(raw)),
  tar_target(parity, parity_check(frame, raw, "SQL",
                                  file.path("data", "processed", "cohort.duckdb"))),

  tar_target(dag, study_dag()),
  tar_target(adj_activity, adjustment_set(dag, "activity")),
  tar_target(adj_smoke, adjustment_set(dag, "smoke")),
  tar_target(fig_dag, dag_figure(dag, file.path("figures", "dag.png")),
             format = "file"),

  tar_target(reps, replicate_design(frame, replicate_draws, seed = 101)),

  tar_target(dat_activity, arm(frame, met_guideline, adj_activity)),
  tar_target(dat_landmark, landmark(dat_activity, landmark_origin)),
  tar_target(dat_smoke,
             arm(frame,
                 dplyr::case_when(smoke == "current" ~ 1L, smoke == "never" ~ 0L),
                 adj_smoke)),
  tar_target(dat_bmi, arm(frame, met_guideline, c(adj_activity, "bmi"))),
  tar_target(dat_accident,
             arm(frame, met_guideline, adj_activity,
                 cause_event(died, ucod, "004"))),

  tar_target(fit_activity,
             entropy_weights(dat_activity, adj_activity,
                             dat_activity$pooled_weight)),
  tar_target(diagnostics, diagnostics_table(dat_activity, fit_activity)),
  tar_target(fig_balance,
             balance_figure(fit_activity, file.path("figures", "balance.png")),
             format = "file"),
  tar_target(fig_overlap,
             overlap_figure(dat_activity, adj_activity,
                            file.path("figures", "overlap.png")),
             format = "file"),

  tar_target(act_est,
             replicate_estimate(dat_activity, reps,
                                effect_stat(adj_activity,
                                            c(months_5yr, months_10yr),
                                            months_5yr))),
  tar_target(land_est,
             replicate_estimate(dat_landmark, reps,
                                rd_stat(adj_activity, months_5yr))),
  tar_target(smoke_est,
             replicate_estimate(dat_smoke, reps,
                                rd_stat(adj_smoke, c(months_5yr, months_10yr)))),
  tar_target(med_base_est,
             replicate_estimate(dat_bmi, reps,
                                rd_stat(adj_activity, months_5yr))),
  tar_target(med_bmi_est,
             replicate_estimate(dat_bmi, reps,
                                rd_stat(c(adj_activity, "bmi"), months_5yr))),

  tar_target(effects, dplyr::bind_rows(
    rd_rows(act_est, c("primary", "activity_10yr"), nrow(dat_activity)),
    rd_rows(land_est, "landmark", nrow(dat_landmark)),
    rd_rows(smoke_est, "positive_control", nrow(dat_smoke)),
    rd_rows(med_base_est, "mediator_base", nrow(dat_bmi)),
    rd_rows(med_bmi_est, "mediator_bmi", nrow(dat_bmi)))),
  tar_target(negative, negative_table(dat_accident, reps, adj_activity,
                                      months_5yr)),
  tar_target(evalue, evalue_table(act_est)),

  tar_target(flow, cohort_flow(frame)),
  tar_target(cohort, study_cohort(frame)),
  tar_target(missing_tbl, missingness(cohort)),
  tar_target(table_one, table_one_text(frame)),
  tar_target(fig_minutes,
             minutes_figure(cohort, file.path("figures", "weekly_minutes.png")),
             format = "file"),

  tar_target(bundle, forest_bundle(frame, months_5yr, seed = 202)),
  tar_target(scores, forest_scores(bundle, months_5yr)),
  tar_target(fig_calibration,
             calibration_figure(bundle, months_5yr,
                                file.path("figures", "calibration.png")),
             format = "file"),
  tar_target(fig_importance,
             importance_figure(bundle, file.path("figures", "importance.png")),
             format = "file"),
  tar_target(fig_roc,
             roc_figure(bundle, months_5yr, file.path("figures", "roc_curve.png")),
             format = "file"),

  tar_target(effects_csv, table_file(effects, file.path("tables", "effects.csv")),
             format = "file"),
  tar_target(negative_csv, table_file(negative,
                                      file.path("tables", "negative_control.csv")),
             format = "file"),
  tar_target(evalue_csv, table_file(evalue, file.path("tables", "evalue.csv")),
             format = "file"),
  tar_target(diagnostics_csv, table_file(diagnostics,
                                         file.path("tables", "diagnostics.csv")),
             format = "file"),
  tar_target(scores_csv, table_file(scores,
                                    file.path("tables", "prediction_scores.csv")),
             format = "file"),
  tar_target(tuning_csv, table_file(bundle$tuning,
                                    file.path("tables", "tuning.csv")),
             format = "file"),
  tar_target(flow_csv, table_file(flow, file.path("tables", "cohort_flow.csv")),
             format = "file"),
  tar_target(missing_csv, table_file(missing_tbl,
                                     file.path("tables", "missingness.csv")),
             format = "file"),
  tar_target(table_one_txt, lines_file(table_one,
                                       file.path("tables", "table_one.txt")),
             format = "file"),
  tar_target(dashboard_csv, table_file(dashboard_table(cohort),
                                       file.path("dashboard", "cohort_descriptive.csv")),
             format = "file"),

  tar_quarto(report, "report.qmd")
)
