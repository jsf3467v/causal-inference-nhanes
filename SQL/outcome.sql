-- Mortality status, follow-up months, leading cause, and the early-death flag.
CREATE OR REPLACE TABLE outcome AS
SELECT
  SEQN,
  CASE WHEN eligstat = 1 THEN 1 WHEN eligstat IS NOT NULL THEN 0 END AS eligible_mort,
  mortstat   AS died,
  permth_exm AS follow_months,
  ucod,
  CASE
    WHEN mortstat = 1 AND permth_exm < 24 THEN 1
    WHEN (mortstat = 1 AND permth_exm < 24) IS FALSE THEN 0
  END AS early_death
FROM mort;
