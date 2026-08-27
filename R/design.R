# Survey design and replicate weights. NHANES strata hold two primary
# sampling units, which the Rao-Wu-Yue-Beaumont rescaled bootstrap handles.
# Replicate weights generate once, restricted to study rows, and travel with
# their design scale so the variance formula holds for any bootstrap type.

survey_design <- function(frame) {
  survey::svydesign(ids = ~psu, strata = ~strata, weights = ~pooled_weight,
                    nest = TRUE, data = frame)
}

replicate_design <- function(frame, draws, seed) {
  set.seed(seed)
  boot <- svrep::as_bootstrap_design(survey_design(frame),
                                     type = "Rao-Wu-Yue-Beaumont",
                                     replicates = draws)
  rows <- study(frame)$row_id
  list(row_id = rows, scale = boot$scale,
       rscales = rep(boot$rscales, length.out = draws),
       weights = stats::weights(boot, type = "analysis")[rows, , drop = FALSE])
}
