# Shared building blocks for the Act 2 scripts.
# Sourced so the cohort rule, the adjustment sets, the propensity weights, the
# effect estimator, and the bootstrap each live in one place.

library(dplyr)

# Follow-up reads, in months, for the five-year and ten-year horizons.
months_5yr  <- 60
months_10yr <- 120

# Confounders for the activity effect. The smoking control drops smoke,
# which is the treatment there rather than a confounder.
adjusters_activity <- c("age", "sex", "race", "education", "income_ratio",
                        "smoke", "prior_disease")
adjusters_smoking  <- c("age", "sex", "race", "education", "income_ratio",
                        "prior_disease")

# Study entry. Adults 40 and up, eligible for mortality follow-up, with an exam
# follow-up time. Interview-only participants have no exam date, so their exam
# follow-up is missing and they leave here, matching what the models run on.
study <- function(df) {
  filter(df, age >= 40, eligible_mort == 1, !is.na(follow_months), !is.na(died))
}

# Two-arm modeling table for one contrast. treat_expr defines the binary
# treatment and may return NA for rows outside the contrast, which drop out.
arm <- function(df, treat_expr, adjusters) {
  study(df) |>
    transmute(treat = {{ treat_expr }}, time = follow_months, event = died,
              across(all_of(adjusters))) |>
    filter(!is.na(treat)) |>
    na.omit()
}

# ATT propensity weights from a logistic model on the named adjusters.
ipw <- function(df, adjusters) {
  WeightIt::weightit(reformulate(adjusters, "treat"), data = df,
                     method = "glm", estimand = "ATT")
}

# Weighted Kaplan-Meier arm risks and their difference at each time. weights
# aligns row-wise with df.
km_risk_difference <- function(df, weights, times) {
  fit  <- survival::survfit(survival::Surv(time, event) ~ treat,
                            data = df, weights = weights)
  ctrl <- 1 - summary(fit[1], times = times, extend = TRUE)$surv
  trt  <- 1 - summary(fit[2], times = times, extend = TRUE)$surv
  tibble::tibble(months = times, risk_treated = trt,
                 risk_control = ctrl, rd = trt - ctrl)
}

# Bootstrap 95 percent interval for a statistic that refits on a resample.
boot_ci <- function(df, stat, draws, seed) {
  RNGkind("L'Ecuyer-CMRG")
  set.seed(seed)
  cores <- if (.Platform$OS.type == "windows") 1L
           else max(1L, parallel::detectCores() - 1L)
  draw <- function(i) tryCatch(stat(df[sample(nrow(df), replace = TRUE), ]),
                               error = function(e) NA_real_)
  vals <- unlist(parallel::mclapply(seq_len(draws), draw, mc.cores = cores))
  quantile(vals, c(0.025, 0.975), na.rm = TRUE)
}

# Standardized mean differences before and after adjustment, from a matchit
# or weightit object.
balance_plot <- function(x) {
  cobalt::love.plot(x, binary = "std", thresholds = c(m = 0.1),
                    colors = c("#D85A30", "#1D9E75"),
                    sample.names = c("Before", "After"))
}
