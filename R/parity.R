# The cohort builds twice, once in R and once in DuckDB from the SQL files.
# parity_check compares four counts from both paths and stops the pipeline on
# any divergence.

sql_text <- function(path) paste(readLines(path), collapse = "\n")

duckdb_checks <- function(raw, sql_dir, db_path) {
  steps <- c("treatment", "smoking", "comorbidity", "outcome", "covariates",
             "analysis_table", "eligibility")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = parent_dir(db_path))
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  purrr::iwalk(raw, function(tbl, name)
    DBI::dbWriteTable(con, name, haven::zap_labels(tbl), overwrite = TRUE))
  purrr::walk(file.path(sql_dir, paste0(steps, ".sql")),
              function(f) DBI::dbExecute(con, sql_text(f)))
  DBI::dbGetQuery(con, sql_text(file.path(sql_dir, "quality_checks.sql")))
}

r_checks <- function(frame) {
  cohort <- dplyr::filter(study(frame), !is.na(met_guideline))
  tibble::tibble(
    check = c("analysis_rows", "study_rows", "met_guideline", "deaths"),
    value = c(nrow(frame), nrow(cohort),
              sum(cohort$met_guideline), sum(cohort$died)))
}

parity_check <- function(frame, raw, sql_dir, db_path) {
  both <- dplyr::inner_join(duckdb_checks(raw, sql_dir, db_path),
                            r_checks(frame), by = "check",
                            suffix = c("_sql", "_r"))
  stopifnot(nrow(both) == 4, all(both$value_sql == both$value_r))
  both
}
