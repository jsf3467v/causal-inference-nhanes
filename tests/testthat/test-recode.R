# Fixtures for the recoding paths, which is where a quiet error does the most
# damage because nothing downstream would notice. Every sentinel asserted in a
# comment appears in the fixture, so the file doubles as documentation of the
# codebook rather than a description of it.

test_that("na_high sends sentinel codes to missing and keeps real values", {
  expect_equal(na_high(c(3, 77, 99, 0), 77), c(3, NA, NA, 0))
  expect_equal(na_high(c(30, 7777, 9999), 7777), c(30, NA, NA))
})

test_that("exposure converts days and minutes to moderate-equivalent minutes", {
  paq <- tibble::tibble(
    SEQN   = 1:8,
    PAQ650 = c(1,  2,   1,  2,  1,  1,    2,  9),
    PAQ655 = c(3,  NA,  77, NA, 2,  3,    NA, NA),
    PAD660 = c(30, NA,  30, NA, 20, 7777, NA, NA),
    PAQ665 = c(2,  1,   1,  2,  1,  2,    1,  2),
    PAQ670 = c(NA, 5,   4,  NA, 1,  NA,   5,  NA),
    PAD675 = c(NA, 30,  30, NA, 40, NA,   9999, NA)
  )
  out <- exposure(paq)

  # 3 days x 30 min vigorous, doubled, no moderate.
  expect_equal(out$active_min[1], 180)
  expect_equal(out$met_guideline[1], 1L)
  # 5 days x 30 min moderate, no vigorous. Exactly at the threshold.
  expect_equal(out$active_min[2], 150)
  expect_equal(out$met_guideline[2], 1L)
  # PAQ655 = 77, refused day count, poisons the total rather than counting zero.
  expect_true(is.na(out$active_min[3]))
  expect_true(is.na(out$met_guideline[3]))
  # Both screeners answered no, so the total is a real zero.
  expect_equal(out$active_min[4], 0)
  expect_equal(out$met_guideline[4], 0L)
  # 1 x 40 moderate plus 2 x 20 vigorous doubled is 120, below the threshold.
  expect_equal(out$active_min[5], 120)
  expect_equal(out$met_guideline[5], 0L)
  # PAD660 = 7777, refused vigorous minutes.
  expect_true(is.na(out$active_min[6]))
  # PAD675 = 9999, do not know moderate minutes.
  expect_true(is.na(out$active_min[7]))
  # PAQ650 = 9, do not know on the screener itself.
  expect_true(is.na(out$active_min[8]))
})

test_that("smoking maps the two screening items and drops sentinels", {
  smq <- tibble::tibble(SEQN = 1:6,
                        SMQ020 = c(2,  1, 1, 1, 7,  1),
                        SMQ040 = c(NA, 3, 1, 2, NA, 9))
  expect_equal(smoking(smq)$smoke,
               c("never", "former", "current", "current", NA, NA))
})

test_that("comorbidity is any-of, and unknown only when no condition is yes", {
  mcq <- tibble::tibble(SEQN = 1:5,
                        MCQ160C = c(2, 1, 2, 9, 2),   # 9 is do not know
                        MCQ160F = c(2, 2, 1, 2, 7),   # 7 is refused
                        MCQ220  = c(2, 2, 2, 1, 2))
  out <- comorbidity(mcq)$prior_disease
  expect_equal(out[1], 0L)          # all three answered no
  expect_equal(out[2], 1L)          # coronary disease yes
  expect_equal(out[3], 1L)          # stroke yes
  expect_equal(out[4], 1L)          # a yes elsewhere outranks an unknown
  expect_true(is.na(out[5]))        # no yes anywhere and one unknown
})

test_that("outcome carries eligibility, follow-up, and cause through", {
  mort <- tibble::tibble(SEQN = 1:3, eligstat = c(1, 2, 1),
                         mortstat = c(1L, NA, 0L),
                         permth_exm = c(42L, NA, 96L),
                         ucod = c("004", NA, NA))
  out <- outcome(mort)
  expect_equal(out$eligible_mort, c(1L, 0L, 1L))
  expect_equal(out$died, c(1L, NA, 0L))
  expect_equal(out$follow_months, c(42L, NA, 96L))
  expect_equal(out$ucod, c("004", NA, NA))
})

test_that("covariates labels the coded fields and pools the exam weight", {
  demo <- tibble::tibble(
    SEQN = 1:4, RIDAGEYR = c(41, 55, 62, 70), RIAGENDR = c(1, 2, 1, 2),
    RIDRETH1 = c(3, 4, 3, 1), DMDEDUC2 = c(5, 7, 9, 3),
    INDFMPIR = c(2.5, 1.0, NA, 4.2), WTMEC2YR = c(12000, 6000, 9000, 3000),
    SDMVPSU = c(1, 2, 1, 2), SDMVSTRA = c(90, 90, 91, 91),
    cycle = c("2007-2008", "2007-2008", "2009-2010", "2009-2010"))
  out <- covariates(demo)
  expect_equal(as.character(out$race),
               c("Non-Hispanic White", "Non-Hispanic Black",
                 "Non-Hispanic White", "Mexican American"))
  # DMDEDUC2 7 and 9 are refused and do not know.
  expect_equal(as.character(out$education),
               c("College graduate", NA, NA, "High school or GED"))
  expect_equal(out$sex, c("male", "female", "male", "female"))
  # Two distinct cycles in the fixture, so the weight halves.
  expect_equal(out$pooled_weight, c(6000, 3000, 4500, 1500))
})

# The explicit levels are the guard. Without them factor() would invent a
# category from whatever code appeared, in both the R and the SQL path.
test_that("covariates sends codes outside the published range to missing", {
  demo <- tibble::tibble(
    SEQN = 1:2, RIDAGEYR = c(50, 50), RIAGENDR = c(1, 0),
    RIDRETH1 = c(6, 3), DMDEDUC2 = c(6, 4),
    INDFMPIR = c(2, 2), WTMEC2YR = c(1000, 1000),
    SDMVPSU = c(1, 1), SDMVSTRA = c(90, 90),
    cycle = c("2007-2008", "2007-2008"))
  out <- covariates(demo)
  expect_true(is.na(out$race[1]))       # RIDRETH1 has no code 6
  expect_true(is.na(out$education[1]))  # DMDEDUC2 has no code 6
  expect_true(is.na(out$sex[2]))        # case_when falls through, unlike recode
})

test_that("study keeps only eligible adults with complete follow-up", {
  frame <- tibble::tibble(
    age           = c(39, 40, 50, 60, 65),
    eligible_mort = c(1, 1, 0, 1, 1),
    follow_months = c(10, 20, 30, NA, 50),
    died          = c(0, 1, 0, 1, NA))
  expect_equal(nrow(study(frame)), 1)
})
