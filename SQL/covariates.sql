-- Demographics, design fields, and the pooled six-cycle weight.
-- Education codes 7 and 9 are refused and do not know, so drop them.
CREATE OR REPLACE TABLE covariates AS
SELECT
  SEQN,
  RIDAGEYR AS age,
  CASE WHEN RIAGENDR = 1 THEN 'male' WHEN RIAGENDR = 2 THEN 'female' END AS sex,
  CAST(RIDRETH1 AS VARCHAR) AS race,
  CASE WHEN DMDEDUC2 IN (7, 9) THEN NULL ELSE CAST(DMDEDUC2 AS VARCHAR) END AS education,
  INDFMPIR AS income_ratio,
  WTMEC2YR AS mec_weight,
  SDMVPSU  AS psu,
  SDMVSTRA AS strata,
  WTMEC2YR / (SELECT COUNT(DISTINCT cycle) FROM demo) AS pooled_weight
FROM demo;
