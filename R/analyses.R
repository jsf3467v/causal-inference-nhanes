# Analysis statistics and tables. Each dataset fits entropy balancing once
# per replicate and reads every horizon from that single fit, and every
# interval passes through replicate_estimate.

rd_stat <- function(adjusters, months) {
  function(dat, sampling) {
    stats::setNames(km_risk(dat, balanced_weights(dat, adjusters, sampling),
                            months)$rd,
                    paste0("rd_", months))
  }
}

# Risk differences at every horizon and the log risk ratio at ratio_months,
# all from one balancing fit.
effect_stat <- function(adjusters, months, ratio_months) {
  function(dat, sampling) {
    risks <- km_risk(dat, balanced_weights(dat, adjusters, sampling), months)
    c(stats::setNames(risks$rd, paste0("rd_", months)),
      log_rr = log(risk_ratio(risks[risks$months == ratio_months, ])))
  }
}

aj_stat <- function(adjusters, months) {
  function(dat, sampling) {
    c(rd = aj_risk(dat, balanced_weights(dat, adjusters, sampling), months,
                   "target")$rd)
  }
}

rd_rows <- function(est, labels, n) {
  est |>
    dplyr::filter(startsWith(statistic, "rd_")) |>
    dplyr::transmute(analysis = labels,
                     months = as.integer(sub("rd_", "", statistic)),
                     n = n, estimate, se, ci_low, ci_high, replicates)
}

negative_table <- function(dat, reps, adjusters, months) {
  replicate_estimate(dat, reps, aj_stat(adjusters, months)) |>
    dplyr::transmute(analysis = "negative_control", months = months,
                     n = nrow(dat), deaths = sum(dat$event == "target"),
                     estimate, se, ci_low, ci_high, replicates)
}

# The interval exponentiates from the log scale, so the ratio limits stay
# positive and respect the skew of a ratio.
evalue_table <- function(est) {
  row  <- est[est$statistic == "log_rr", ]
  rr   <- exp(c(row$estimate, row$ci_low, row$ci_high))
  near <- dplyr::if_else(rr[1] < 1, rr[3], rr[2])
  crosses <- (rr[1] - 1) * (near - 1) <= 0
  tibble::tibble(
    measure = c("risk_ratio", "risk_ratio_ci_low", "risk_ratio_ci_high",
                "e_value_estimate", "e_value_limit"),
    value = c(rr, e_value(rr[1]), dplyr::if_else(crosses, 1, e_value(near))))
}

# Weighted effective sample size per arm, shown rather than asserted.
diagnostics_table <- function(dat, fit) {
  w   <- fit$weights * dat$pooled_weight
  ess <- tapply(w, dat$treat, function(x) sum(x)^2 / sum(x^2))
  tibble::tibble(arm = c("control", "treated"),
                 n = as.integer(table(dat$treat)),
                 ess = as.numeric(ess))
}

balance_figure <- function(fit, path) {
  plot <- cobalt::love.plot(fit, binary = "std", thresholds = c(m = 0.1),
                            colors = c("#D85A30", "#1D9E75"),
                            sample.names = c("Before", "After"))
  figure_file(plot, path, width = 7, height = 5)
}

# Diagnostic propensity score, fit only to display overlap between arms.
overlap_figure <- function(dat, adjusters, path) {
  score <- stats::glm(stats::reformulate(adjusters, "treat"), data = dat,
                      family = stats::quasibinomial(),
                      weights = pooled_weight / mean(pooled_weight),
                      control = list(maxit = 200))$fitted
  plot <- ggplot2::ggplot(
    tibble::tibble(score = score,
                   arm = factor(dat$treat, labels = c("control", "treated"))),
    ggplot2::aes(score, fill = arm)) +
    ggplot2::geom_density(alpha = 0.5, color = NA) +
    ggplot2::scale_fill_manual(values = c("#D85A30", "#1D9E75")) +
    ggplot2::labs(x = "Propensity score", y = "Density", fill = NULL) +
    ggplot2::theme_minimal(base_size = 13)
  figure_file(plot, path, width = 7, height = 4)
}

parent_dir <- function(path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  path
}

figure_file <- function(plot, path, width, height) {
  ggplot2::ggsave(parent_dir(path), plot, width = width, height = height,
                  dpi = 150)
  path
}

table_file <- function(tbl, path) {
  readr::write_csv(tbl, parent_dir(path))
  path
}

lines_file <- function(lines, path) {
  writeLines(lines, parent_dir(path))
  path
}
