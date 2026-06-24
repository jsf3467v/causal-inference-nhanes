# Builds the analysis table in DuckDB from the raw bundle, mirroring cohort.R.
# Runs the SQL files in order, then prints checks that should match the R frame.

library(here)
library(DBI)
library(duckdb)
library(haven)
library(purrr)

source(here("R", "paths.R"))

raw <- readRDS(file.path(dirs$interim, "raw_bundle.rds"))

steps <- c("treatment", "smoking", "comorbidity", "outcome",
           "covariates", "analysis_table", "eligibility")

con <- dbConnect(duckdb::duckdb(), dbdir = file.path(dirs$processed, "cohort.duckdb"))

iwalk(raw, function(tbl, name) dbWriteTable(con, name, zap_labels(tbl), overwrite = TRUE))

walk(here("SQL", paste0(steps, ".sql")),
     function(f) dbExecute(con, paste(readLines(f), collapse = "\n")))

checks <- dbGetQuery(con, paste(readLines(here("SQL", "quality_checks.sql")), collapse = "\n"))
dbDisconnect(con, shutdown = TRUE)

print(checks)
