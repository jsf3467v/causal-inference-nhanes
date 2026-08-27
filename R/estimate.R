# Estimand machinery. One cohort rule, entropy balancing to the treated with
# the pooled survey weight as a sampling weight, weighted survival estimators,
# and one replicate interval used by every analysis.

study <- function(frame) {
  dplyr::filter(frame, age >= 40, eligible_mort == 1,
                !is.na(follow_months), !is.na(died))
}

arm <- function(frame, treat_expr, adjusters, event_expr = died) {
  study(frame) |>
    dplyr::transmute(row_id, pooled_weight, treat = {{ treat_expr }},
                     time = follow_months, event = {{ event_expr }},
                     dplyr::across(dplyr::all_of(adjusters))) |>
    dplyr::filter(!is.na(treat)) |>
    stats::na.omit()
}

# Missing cause codes among decedents count as competing deaths, not as gaps.
cause_event <- function(died, ucod, cause) {
  factor(dplyr::case_when(died == 1 & ucod %in% cause ~ "target",
                          died == 1 ~ "other",
                          .default = "censor"),
         levels = c("censor", "target", "other"))
}

landmark <- function(dat, origin) {
  dat |>
    dplyr::filter(time >= origin) |>
    dplyr::mutate(time = time - origin)
}

entropy_weights <- function(dat, adjusters, sampling) {
  WeightIt::weightit(stats::reformulate(adjusters, "treat"), data = dat,
                     method = "ebal", estimand = "ATT", s.weights = sampling)
}

balanced_weights <- function(dat, adjusters, sampling) {
  entropy_weights(dat, adjusters, sampling)$weights * sampling
}

km_risk <- function(dat, weights, months) {
  fit  <- survival::survfit(survival::Surv(time, event) ~ treat,
                            data = dat, weights = weights)
  ctrl <- 1 - summary(fit[1], times = months, extend = TRUE)$surv
  trt  <- 1 - summary(fit[2], times = months, extend = TRUE)$surv
  tibble::tibble(months = months, risk_treated = trt, risk_control = ctrl,
                 rd = trt - ctrl)
}

# Aalen-Johansen cumulative incidence with other causes as competing events.
aj_risk <- function(dat, weights, months, state) {
  fit  <- survival::survfit(survival::Surv(time, event) ~ treat,
                            data = dat, weights = weights)
  col  <- match(state, fit$states)
  ctrl <- as.numeric(summary(fit[1, ], times = months, extend = TRUE)$pstate[, col])
  trt  <- as.numeric(summary(fit[2, ], times = months, extend = TRUE)$pstate[, col])
  tibble::tibble(months = months, risk_treated = trt, risk_control = ctrl,
                 rd = trt - ctrl)
}

risk_ratio <- function(risks) {
  dplyr::if_else(risks$risk_control > 0 & risks$risk_treated > 0,
                 risks$risk_treated / risks$risk_control, NA_real_)
}

e_value <- function(rr) {
  r <- dplyr::if_else(rr < 1, 1 / rr, rr)
  r + sqrt(r * (r - 1))
}

# No estimation step draws a random number, so replicate results are identical
# at any worker count.
replicate_cores <- function() {
  if (.Platform$OS.type == "windows") 1L
  else max(1L, parallel::detectCores() - 1L)
}

# Point estimate from the pooled weight, variance from the replicate design
# scale. The balancing model refits inside every replicate, zero-weight rows
# leave that replicate, and the run stops if more than the allowed share of
# replicates is lost, since selective failures would shrink the interval.
replicate_estimate <- function(dat, reps, stat, floor = 0.95) {
  idx   <- match(dat$row_id, reps$row_id)
  point <- stat(dat, dat$pooled_weight)
  one <- function(k) {
    w    <- reps$weights[idx, k]
    keep <- w > 0
    tryCatch(stat(dat[keep, , drop = FALSE], w[keep]),
             error = function(e) rep(NA_real_, length(point)))
  }
  draws <- do.call(cbind, parallel::mclapply(seq_along(reps$rscales), one,
                                             mc.cores = replicate_cores()))
  ok <- colSums(is.na(draws)) == 0
  stopifnot(mean(ok) >= floor)
  dev <- (draws[, ok, drop = FALSE] - point)^2
  se  <- sqrt(reps$scale * as.vector(dev %*% reps$rscales[ok]) / mean(ok))
  z   <- stats::qnorm(0.975)
  pt  <- unname(point)
  tibble::tibble(statistic = names(point), estimate = pt, se = se,
                 ci_low = pt - z * se, ci_high = pt + z * se,
                 replicates = sum(ok))
}
