-- The four counts parity_check() compares against r_checks() in R/parity.R.
-- The names and the order must match that function, because the pipeline
-- joins on `check` and stops on any divergence.
SELECT 'analysis_rows' AS check, COUNT(*)           AS value FROM analysis_table
UNION ALL
SELECT 'study_rows',        COUNT(*)                      FROM study_cohort
UNION ALL
SELECT 'met_guideline',     SUM(met_guideline)            FROM study_cohort
UNION ALL
SELECT 'deaths',            SUM(died)                     FROM study_cohort;
