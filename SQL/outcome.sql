-- Mortality status, follow-up months, and underlying cause of death.
-- Mirrors outcome() in R/recode.R. The early-death flag is gone, because
-- reverse causation is now handled by the landmark in R/estimate.R rather
-- than by a derived column.
CREATE OR REPLACE TABLE outcome AS
SELECT
  SEQN,
  CASE WHEN eligstat = 1 THEN 1 WHEN eligstat IS NOT NULL THEN 0 END AS eligible_mort,
  mortstat   AS died,
  permth_exm AS follow_months,
  ucod
FROM mort;
