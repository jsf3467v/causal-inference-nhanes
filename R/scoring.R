# One scoring definition shared by the tuning stage and the final evaluation,
# so the numbers are comparable. Thread count is fixed so a fixed seed grows
# the same forest on any machine.

forest_threads <- 2L

auroc_horizon <- function(time, event, risk, months) {
  scored <- timeROC::timeROC(T = time, delta = event, marker = risk,
                             cause = 1, times = months)
  auc <- unname(scored$AUC[match(months, scored$times)])
  stopifnot(is.finite(auc))
  auc
}

forest_risk <- function(forest, baked, months) {
  pred <- stats::predict(forest, baked, num.threads = forest_threads)
  step <- findInterval(months, pred$unique.death.times)
  if (step == 0) rep(0, nrow(baked)) else 1 - pred$survival[, step]
}
