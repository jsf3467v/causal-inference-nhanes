-- One row per participant, covariates joined to every derived field.
CREATE OR REPLACE TABLE analysis_table AS
SELECT
  c.*,
  t.active_min, t.met_guideline,
  s.smoke,
  m.chd, m.stroke, m.cancer, m.prior_disease,
  b.bmi,
  o.eligible_mort, o.died, o.follow_months, o.ucod, o.early_death
FROM covariates c
LEFT JOIN treatment   t USING (SEQN)
LEFT JOIN smoking     s USING (SEQN)
LEFT JOIN comorbidity m USING (SEQN)
LEFT JOIN (SELECT SEQN, BMXBMI AS bmi FROM bmx) b USING (SEQN)
LEFT JOIN outcome     o USING (SEQN);
