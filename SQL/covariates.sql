-- Demographics, design fields, and the pooled six-cycle weight.
-- Mirrors covariates() in R/recode.R, labels included, so the DuckDB table
-- reads the same as the R frame. Education codes 7 and 9 are refused and do
-- not know, so they drop to null. Survey cycle is carried because the causal
-- diagram gives it edges to both exposure and outcome.
CREATE OR REPLACE TABLE covariates AS
SELECT
  SEQN,
  RIDAGEYR AS age,
  CASE
    WHEN RIAGENDR = 1 THEN 'male'
    WHEN RIAGENDR = 2 THEN 'female'
  END AS sex,
  CASE RIDRETH1
    WHEN 1 THEN 'Mexican American'
    WHEN 2 THEN 'Other Hispanic'
    WHEN 3 THEN 'Non-Hispanic White'
    WHEN 4 THEN 'Non-Hispanic Black'
    WHEN 5 THEN 'Other or multiracial'
  END AS race,
  CASE DMDEDUC2
    WHEN 1 THEN 'Less than 9th grade'
    WHEN 2 THEN '9th to 11th grade'
    WHEN 3 THEN 'High school or GED'
    WHEN 4 THEN 'Some college or AA'
    WHEN 5 THEN 'College graduate'
  END AS education,
  INDFMPIR AS income_ratio,
  cycle,
  SDMVPSU  AS psu,
  SDMVSTRA AS strata,
  WTMEC2YR / (SELECT COUNT(DISTINCT cycle) FROM demo) AS pooled_weight
FROM demo;
