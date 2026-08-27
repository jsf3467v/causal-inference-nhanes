# The adjustment sets are derived, not written, so this pin is the only place
# an accidental edit to the diagram can surface before it reaches an estimate.

test_that("the diagram derives the expected adjustment sets", {
  dag <- study_dag()
  expect_equal(adjustment_set(dag, "activity"),
               c("age", "cycle", "education", "income_ratio", "prior_disease",
                 "race", "sex", "smoke"))
  expect_equal(adjustment_set(dag, "smoke"),
               c("age", "cycle", "education", "income_ratio", "race", "sex"))
})
