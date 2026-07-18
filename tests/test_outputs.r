# Validation tests for the committed result tables. These guard the numbers the
# report relies on, so a bad rerun that breaks an estimate fails the build.

tbl <- function(name) {
  readr::read_csv(here::here("tables", name), show_col_types = FALSE)
}

test_that("weighted estimate is negative and inside its interval", {
  w <- tbl("weighting_rd.csv")
  expect_lt(w$rd[1], 0)
  expect_lt(w$ci_low[1], w$rd[1])
  expect_lt(w$rd[1], w$ci_high[1])
})

test_that("mediator estimates agree within a small margin", {
  m    <- tbl("mediator_rd.csv")
  base <- m$rd[m$adjustment == "base"]
  bmi  <- m$rd[m$adjustment == "with_bmi"]
  expect_lt(base, 0)
  expect_lt(bmi, 0)
  expect_lt(abs(base - bmi), 0.01)
})

test_that("negative control sits on zero", {
  n <- tbl("negative_control_rd.csv")
  expect_lte(n$ci_low[1], 0)
  expect_gte(n$ci_high[1], 0)
})

test_that("positive control recovers a positive risk difference", {
  p  <- tbl("positive_control_rd.csv")
  wr <- p$rd[p$estimator == "weighted"]
  expect_gt(wr, 0)
})

test_that("horizon table covers both exposures at both horizons", {
  h <- tbl("horizon_rd.csv")
  expect_setequal(unique(h$exposure), c("activity", "smoking"))
  expect_setequal(unique(h$months), c(60, 120))
  expect_lt(h$rd[h$exposure == "activity" & h$months == 60], 0)
})

test_that("washout attenuates the estimate toward zero", {
  w    <- tbl("washout_rd.csv")
  full <- w$rd[w$sample == "full"]
  wash <- w$rd[w$sample == "washout"]
  expect_lt(full, 0)
  expect_lt(wash, 0)
  expect_gt(wash, full)
})

test_that("e-values exceed one and the estimate exceeds the limit", {
  e   <- tbl("evalue.csv")
  est <- e$value[e$measure == "e_value_estimate"]
  lim <- e$value[e$measure == "e_value_limit"]
  expect_gt(est, 1)
  expect_gt(lim, 1)
  expect_gte(est, lim)
})

test_that("prediction scores are above chance", {
  s     <- tbl("prediction_scores.csv")
  auroc <- s$value[s$metric == "auroc_60mo"]
  cidx  <- s$value[s$metric == "c_index_oob"]
  expect_gt(auroc, 0.5); expect_lt(auroc, 1)
  expect_gt(cidx, 0.5);  expect_lt(cidx, 1)
})
