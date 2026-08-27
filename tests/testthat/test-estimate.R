# The estimator runs on a simulated cohort whose true risk difference among
# the treated is known in closed form, so a break in the estimation path fails
# here and unbiasedness under its own assumptions is demonstrated.

test_that("entropy balanced survival recovers the closed-form ATT risk difference", {
  set.seed(7)
  n  <- 20000
  x  <- stats::rbinom(n, 1, 0.5)
  tr <- stats::rbinom(n, 1, stats::plogis(-0.4 + 0.9 * x))
  h  <- 0.004 * exp(log(2) * tr + log(1.6) * x)
  t_true <- stats::rexp(n, h)
  dat <- tibble::tibble(treat = tr, time = pmin(t_true, 120),
                        event = as.integer(t_true <= 120),
                        x = x, pooled_weight = 1)
  risk  <- function(tr_, x_) 1 - exp(-0.004 * exp(log(2) * tr_ + log(1.6) * x_) * 60)
  px1   <- stats::plogis(0.5) / (stats::plogis(0.5) + stats::plogis(-0.4))
  truth <- px1 * (risk(1, 1) - risk(0, 1)) + (1 - px1) * (risk(1, 0) - risk(0, 0))
  fit <- entropy_weights(dat, "x", dat$pooled_weight)
  est <- km_risk(dat, fit$weights * dat$pooled_weight, 60)$rd
  expect_lt(abs(est - truth), 0.02)
})

test_that("risk_ratio returns missing when either arm risk is zero", {
  risks <- tibble::tibble(risk_treated = c(0.2, 0.2, 0),
                          risk_control = c(0.1, 0, 0.1))
  expect_equal(risk_ratio(risks), c(2, NA_real_, NA_real_))
})

test_that("cause_event counts decedents with missing cause codes as competing", {
  ev <- cause_event(died = c(1, 1, 1, 0), ucod = c("004", "010", NA, NA),
                    cause = "004")
  expect_equal(as.character(ev), c("target", "other", "other", "censor"))
})

test_that("aj_risk reads the cumulative incidence of the target state", {
  dat <- tibble::tibble(
    treat = rep(0:1, each = 4),
    time  = c(10, 20, 30, 40, 10, 20, 30, 40),
    event = factor(c("target", "other", "censor", "censor",
                     "other", "other", "censor", "censor"),
                   levels = c("censor", "target", "other")))
  out <- aj_risk(dat, rep(1, 8), 60, "target")
  expect_equal(out$risk_control, 0.25)
  expect_equal(out$risk_treated, 0)
  expect_equal(out$rd, -0.25)
})

test_that("landmark re-anchors follow-up at the origin", {
  dat <- tibble::tibble(time = c(10, 24, 30), event = c(1, 0, 1))
  out <- landmark(dat, 24)
  expect_equal(out$time, c(0, 6))
})

test_that("replicate_estimate matches the design variance and is reproducible", {
  set.seed(11)
  dat  <- tibble::tibble(row_id = 1:200, x = stats::rnorm(200),
                         pooled_weight = 1)
  reps <- list(row_id = 1:200, scale = 1 / 40, rscales = rep(1, 40),
               weights = matrix(stats::rexp(200 * 40), nrow = 200))
  stat <- function(d, w) c(mean = stats::weighted.mean(d$x, w))
  a <- replicate_estimate(dat, reps, stat)
  b <- replicate_estimate(dat, reps, stat)
  expect_equal(a, b)
  expect_equal(a$estimate, mean(dat$x))
  expect_equal(a$replicates, 40L)
  draws <- apply(reps$weights, 2, function(w) stats::weighted.mean(dat$x, w))
  expect_equal(a$se, sqrt(mean((draws - mean(dat$x))^2)))
  expect_lt(a$ci_low, a$estimate)
  expect_gt(a$ci_high, a$estimate)
})

test_that("replicate_estimate returns one row per named statistic", {
  dat  <- tibble::tibble(row_id = 1:50, x = stats::rnorm(50), pooled_weight = 1)
  reps <- list(row_id = 1:50, scale = 1 / 10, rscales = rep(1, 10),
               weights = matrix(stats::rexp(50 * 10), nrow = 50))
  stat <- function(d, w) c(mean = stats::weighted.mean(d$x, w),
                           total = sum(d$x * w))
  out <- replicate_estimate(dat, reps, stat)
  expect_equal(out$statistic, c("mean", "total"))
  expect_equal(out$estimate, c(mean(dat$x), sum(dat$x)))
})

test_that("replicate_estimate stops when too many replicates are lost", {
  dat <- tibble::tibble(row_id = 1:10, x = stats::rnorm(10), pooled_weight = 1)
  w   <- matrix(1, 10, 20)
  w[, 1:3] <- 0
  reps <- list(row_id = 1:10, scale = 1 / 20, rscales = rep(1, 20), weights = w)
  stat <- function(d, w) c(mean = stats::weighted.mean(d$x, w))
  expect_error(replicate_estimate(dat, reps, stat))
})

test_that("evalue_table exponentiates the log ratio interval", {
  est <- tibble::tibble(statistic = "log_rr", estimate = log(0.8),
                        se = 0.1, ci_low = log(0.7), ci_high = log(0.9),
                        replicates = 500L)
  out <- evalue_table(est)
  expect_equal(out$value[out$measure == "risk_ratio"], 0.8)
  expect_equal(out$value[out$measure == "risk_ratio_ci_low"], 0.7)
  expect_equal(out$value[out$measure == "risk_ratio_ci_high"], 0.9)
  expect_gt(out$value[out$measure == "e_value_estimate"], 1)
  expect_gt(out$value[out$measure == "e_value_limit"], 1)
})
