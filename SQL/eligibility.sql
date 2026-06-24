-- Study cohort of adults age 40 and older with known activity and exam
-- follow-up. The follow-up filter matches study() in shared.R so the checks
-- reproduce the R cohort. Interview-only participants have no exam date.
CREATE OR REPLACE TABLE study_cohort AS
SELECT *
FROM analysis_table
WHERE age >= 40
  AND eligible_mort = 1
  AND follow_months IS NOT NULL
  AND died IS NOT NULL
  AND met_guideline IS NOT NULL;
