[![CI](https://github.com/jsf3467v/causal-inference-nhanes/actions/workflows/ci.yml/badge.svg)](https://github.com/jsf3467v/causal-inference-nhanes/actions/workflows/ci.yml)

# Does Meeting the Aerobic Activity Guideline Lower Mortality

> A two-act NHANES study on predicting an outcome and then changing it.

Six cycles of NHANES (2007-2018), linked to mortality records through 2019, were used to address two questions. Act 1 predicts mortality based on baseline traits. Act 2 assesses whether meeting the aerobic activity guideline reduces five-year mortality, distinguishing the effect of activity from other differences between active and inactive individuals.

Meeting the guideline correlates with a 3.3 percentage point reduction in five-year mortality risk (weighted ATT -0.0329, 95% CI -0.041 to -0.025). This finding is consistent across matching and weighting methods, remains robust after positive and negative controls, a reverse-causation washout, and a mediator check, and is supported by an E-value of 2.9. It is presented as an upper bound on the potential benefit rather than a definitive causal figure, as the washout indicates that about a third of the effect may be due to reverse causation.

![Covariate balance before and after weighting](figures/love_weighting.png)

## Summary

- **Question.** Whether adults aged 40 and older who meet the aerobic activity guideline have a 
lower death rate compared to those who do not, and to what extent this difference is due to the 
activity itself versus their prior health.


- **Data.** Six NHANES cycles included 59,842 participants, which was narrowed down to a study cohort of 22,235 adults aged 40 and older. This group was followed for mortality and had known activity levels. Exposure was measured as leisure-time aerobic activity in moderate-equivalent minutes per week, using 150 minutes as the guideline threshold.


- **Act 1, prediction.** A random survival forest is applied to each individual's actual follow-up data instead of a censored five-year label. The model achieves a time-dependent AUROC of 0.811 at five years and an out-of-bag concordance of 0.799. Body mass index is used as a predictor in this context but is removed from the causal analysis.


- **Act 2, the effect.** Propensity-score matching and inverse-probability weighting both estimate the risk difference from a weighted survival curve, maintaining shorter follow-up periods instead of discarding them. Matching yields -0.0352, while weighting results in -0.0329. Body mass index is excluded as a mediator in this analysis.


- **Validation.** A smoking positive control recovers a known harm (0.0202). An accidental-death
  negative control sits on zero (-0.0005, interval -0.0018 to 0.0008). A two-year washout moves the
  estimate from -0.0329 to -0.0219. A mediator check adding body mass index back moves it only to
  -0.0312. An E-value of 2.93 says a confounder would need a moderate association with both activity
  and mortality to erase the result.


- **Reproducibility.** The cohort is built twice, once in R and once in DuckDB from a set of SQL
  files, and the two agree on every count, which guards against a quiet error in either path.

## Quick look

To see the results without running anything.

- **[report.html](report.html)** is the full rendered report with every figure, table, and the
  reasoning behind each check. Self-contained, open it in any browser.
- **`tables/`** holds every CSV the report reads, one per analysis.
- **`figures/`** holds the calibration, importance, balance, and distribution plots.

## Setup

Tested on macOS (Apple Silicon) and Linux. R 4.4 or newer.

```r
install.packages(c(
  "here", "dplyr", "ggplot2", "tidyr", "readr", "purrr", "haven",
  "survival", "MatchIt", "WeightIt", "cobalt", "tableone",
  "rsample", "recipes", "ranger", "timeROC",
  "DBI", "duckdb", "knitr"
))
```

Open the project through `Casual Inf.Rproj` so the working directory and the `here()` anchor are
set together. Running scripts from a bare session in another folder will misplace the outputs.

## Data

Everything is pulled and cached automatically on the first run. `data_sources.R` downloads the
NHANES survey tables from the CDC and the public-use linked mortality files, then caches them to
`data/raw` so later runs and crash recovery skip the network. Nothing needs to be downloaded by
hand. The `data/` tree is not tracked by git.

## Reproducing from scratch

Run from the project root in order. Each script reads the cached frame, so once the cohort is built
the Act 2 scripts can run in any order.

```r
source(here::here("R", "data_sources.R"))   # pull NHANES and mortality, cache to data/raw
source(here::here("R", "cohort.R"))         # derive the analysis frame
source(here::here("R", "database.R"))       # build the same cohort in DuckDB and check the counts
source(here::here("R", "eda.R"))            # cohort flow, missingness, Table 1, distribution

source(here::here("R", "prediction.R"))         # Act 1, train the survival forest
source(here::here("R", "prediction_eval.R"))    # Act 1, discrimination and calibration

source(here::here("R", "matching.R"))           # Act 2, matched estimate
source(here::here("R", "weighting.R"))          # Act 2, weighted estimate with bootstrap interval
source(here::here("R", "horizon.R"))            # five and ten-year risk differences
source(here::here("R", "positive_control.R"))   # smoking, a known harm
source(here::here("R", "negative_control.R"))   # accidental death, should be null
source(here::here("R", "washout.R"))            # reverse-causation check
source(here::here("R", "mediator.R"))           # body mass index sensitivity
source(here::here("R", "evalue.R"))             # unmeasured-confounding bound
```

Then render the report.

```
quarto render report.qmd
```

Outputs land in `figures/` and `tables/`, and the report reads from both.

## Project layout

```
.
├── Casual Inf.Rproj
├── report.qmd                 # the report source
├── report.html                # rendered, self-contained
├── R/
│   ├── paths.R                # project directories, anchored by here()
│   ├── shared.R               # cohort rule, adjustment sets, weights, estimator, bootstrap
│   ├── data_sources.R         # NHANES and mortality pulls, cached
│   ├── cohort.R               # derive the analysis frame in R
│   ├── database.R             # build the same cohort in DuckDB, check counts
│   ├── eda.R                  # cohort flow, missingness, Table 1, distribution
│   ├── prediction.R           # Act 1 training
│   ├── prediction_eval.R      # Act 1 scoring
│   ├── matching.R             # Act 2 matched estimate
│   ├── weighting.R            # Act 2 weighted estimate
│   ├── horizon.R              # five and ten-year horizons
│   ├── positive_control.R     # smoking control
│   ├── negative_control.R     # accidental-death control
│   ├── washout.R              # reverse-causation washout
│   ├── mediator.R             # body mass index sensitivity
│   └── evalue.R               # E-value
├── SQL/                       # DuckDB build, one file per derived table
├── data/{raw,interim,processed}/   # not tracked by git
├── figures/                   # rendered plots
└── tables/                    # rendered CSVs and Table 1
```

## Citation

```
@misc{keith2026activity,
  author       = {Keith, Arlene},
  title        = {Does Meeting the Aerobic Activity Guideline Lower Mortality},
  year         = {2026},
  howpublished = {NHANES observational study},
  url          = {https://github.com/jsf3467v/causal-inference-nhanes}
}
```

## License

MIT License, see `LICENSE`.
