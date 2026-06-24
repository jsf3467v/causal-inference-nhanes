-- Baseline coronary disease, stroke, cancer, and any-of flag.
CREATE OR REPLACE TABLE comorbidity AS
WITH flags AS (
  SELECT
    SEQN,
    CASE WHEN MCQ160C = 1 THEN 1 WHEN MCQ160C = 2 THEN 0 END AS chd,
    CASE WHEN MCQ160F = 1 THEN 1 WHEN MCQ160F = 2 THEN 0 END AS stroke,
    CASE WHEN MCQ220  = 1 THEN 1 WHEN MCQ220  = 2 THEN 0 END AS cancer
  FROM mcq
)
SELECT
  SEQN, chd, stroke, cancer,
  CASE
    WHEN chd = 1 OR stroke = 1 OR cancer = 1 THEN 1
    WHEN (chd = 1 OR stroke = 1 OR cancer = 1) IS FALSE THEN 0
  END AS prior_disease
FROM flags;
