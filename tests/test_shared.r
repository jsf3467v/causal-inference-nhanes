# Unit tests for the building blocks in shared.R. These run on synthetic data,
# so they need no NHANES download and stay deterministic.

source(here::here("R", "shared.R"))

test_that("study keeps only eligible adults with complete follow-up", {
  df <- tibble::tibble(
    age           = c(39, 40, 50, 60),
    eligible_mort = c(1, 1, 0, 1),
    follow_months = c(10, 20, 30, NA),
    died          = c(0, 1, 0, 1)
  )
  out <- study(df)
  expect_equal(nrow(out), 1)
  expect_true(all(out$age >= 40))
})

test_that("arm builds a two-arm table and drops incomplete rows", {
  df <- tibble::tibble(
    age           = c(45, 55, 65, 75),
    eligible_mort = c(1, 1, 1, 1),
    follow_months = c(50, 60, 70, 80),
    died          = c(0, 1, 0, 1),
    met_guideline = c(1L, 0L, NA, 1L),
    sex           = c("male", "female", "male", "female")
  )
  out <- arm(df, met_guideline, c("age", "sex"))
  expect_named(out, c("treat", "time", "event", "age", "sex"))
  expect_equal(nrow(out), 3)
  expect_true(all(!is.na(out$treat)))
})

test_that("km_risk_difference returns risks in range and rd as their difference", {
  set.seed(42)
  n  <- 200
  df <- tibble::tibble(
    treat = rep(0:1, each = n / 2),
    time  = rexp(n, rate = 0.02),
    event = rbinom(n, 1, 0.5)
  )
  rd <- km_risk_difference(df, rep(1, n), times = 24)
  expect_equal(nrow(rd), 1)
  expect_equal(rd$months, 24)
  expect_gte(rd$risk_treated, 0); expect_lte(rd$risk_treated, 1)
  expect_gte(rd$risk_control, 0); expect_lte(rd$risk_control, 1)
  expect_equal(rd$rd, rd$risk_treated - rd$risk_control)
})

test_that("ipw returns positive weights aligned to the data", {
  set.seed(1)
  n  <- 200
  df <- tibble::tibble(
    treat = rbinom(n, 1, 0.5),
    age   = rnorm(n, 60, 10),
    sex   = sample(c("male", "female"), n, replace = TRUE)
  )
  w <- ipw(df, c("age", "sex"))
  expect_length(w$weights, n)
  expect_true(all(w$weights > 0))
})

test_that("boot_ci returns a reproducible two-sided interval", {
  df   <- tibble::tibble(x = rnorm(100))
  stat <- function(d) mean(d$x)
  ci1  <- boot_ci(df, stat, draws = 50, seed = 123)
  ci2  <- boot_ci(df, stat, draws = 50, seed = 123)
  expect_length(ci1, 2)
  expect_equal(ci1, ci2)
  expect_lte(ci1[[1]], ci1[[2]])
})
