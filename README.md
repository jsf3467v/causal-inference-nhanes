[![CI](https://github.com/jsf3467v/causal-inference-nhanes/actions/workflows/ci.yml/badge.svg)](https://github.com/jsf3467v/causal-inference-nhanes/actions/workflows/ci.yml)

# Does Meeting the Aerobic Activity Guideline Lower Mortality

> A causal study that first predicts five-year mortality, then estimates whether meeting the aerobic activity guideline lowers it.

Six cycles of the National Health and Nutrition Examination Survey (NHANES), collected between 2007 and 2018 and linked to mortality records through 2019, address two questions. The first asks how accurately baseline characteristics predict five-year mortality. The second asks whether meeting the aerobic activity guideline lowers five-year mortality, separating the effect of activity from the other differences between active and inactive adults.

Meeting the guideline is associated with a 3.3 percentage point reduction in five-year mortality risk. The weighted estimate is an average treatment effect on the treated of $-0.0329$, with a 95 percent confidence interval that runs from $-0.041$ to $-0.025$. The same result appears under both matching and weighting, and it survives the positive and negative controls. It carries an E-value of $2.9$, meaning that an unmeasured confounder would need a moderate association with both activity and mortality before the result would disappear. The figure is best understood as an upper bound on the benefit rather than a settled causal estimate, because a two-year washout shows that roughly a third of the effect may reflect reverse causation.

[![Covariate balance before and after weighting](https://github.com/jsf3467v/causal-inference-nhanes/raw/main/figures/love_weighting.png)](/jsf3467v/causal-inference-nhanes/blob/main/figures/love_weighting.png)

## Summary

This study focuses on adults aged 40 and older. Out of 59,842 participants in six NHANES cycles, 22,235 met the criteria of being in that age group, having mortality follow-up data, and a known activity level. The exposure measured is leisure-time aerobic activity, expressed in moderate-equivalent minutes per week, with 150 minutes weekly serving as the guideline threshold. The key question is whether adults meeting this activity threshold exhibit a lower mortality rate compared to those who don't, and to what extent any observed differences are due to the activity itself versus existing health conditions.

The initial phase involves training a random survival forest on each participant's actual follow-up data instead of using a censored five-year label. This approach achieves a time-dependent area under the ROC curve of $0.811$ at five years and an out-of-bag concordance of $0.799$. Although body mass index is used as a predictor here, it is excluded from the subsequent causal analysis.

The second stage calculates the effect directly. Both propensity-score matching and inverse-probability weighting derive a risk difference from a weighted survival curve, retaining shorter follow-up periods instead of ignoring them. Matching results in $-0.0352$, while weighting yields $-0.0329$. Since body mass index is considered a mediator, it is excluded from the adjustment set.

Several checks support the estimate. A smoking positive control recovers a known harm, with a matched risk difference of $0.016$ and a weighted risk difference of $0.0202$. An accidental-death negative control sits at zero, with a risk difference of $-0.0005$ and an interval from $-0.0018$ to $0.0008$. A two-year washout, which drops deaths in the first two years of follow-up, moves the estimate from $-0.0329$ to $-0.0219$, so roughly a third of the effect may reflect reverse causation. A mediator check restricted to participants with a recorded body mass index moves the estimate from $-0.029$ without that variable to $-0.0312$ with it, a negligible change that argues against body mass index acting as an important mediator. An E-value of $2.9$ indicates that an unmeasured confounder would need a moderate association with both activity and mortality to explain the result away.

The cohort is built twice, once in R and once in DuckDB from a set of SQL files, and the two builds agree on every count, which guards against a silent error in either path.


## Quick look

To see the results without running anything, open [report.html](https://github.com/jsf3467v/causal-inference-nhanes/blob/main/report.html), the fully rendered report that contains every figure, every table, and the reasoning behind each check. Its charting is self-contained and opens in any browser. An [interactive dashboard](https://public.tableau.com/app/profile/a.keith/viz/ActivityandMortalityChart/Dashboard1) shows the descriptive, unadjusted patterns in the cohort, while the adjusted causal analysis lives in the report. The `tables/` directory holds every data table the report reads, one per analysis, and the `figures/` directory holds the calibration, importance, balance, and distribution plots.

## Setup

The project is tested on macOS (Apple Silicon) and Linux and requires R 4.4 or newer. Install the dependencies in R.

```
install.packages(c(
  "here", "dplyr", "ggplot2", "tidyr", "readr", "purrr", "haven",
  "survival", "MatchIt", "WeightIt", "cobalt", "tableone",
  "rsample", "recipes", "ranger", "timeROC",
  "DBI", "duckdb", "knitr"
))
```

Open the project through `Casual Inf.Rproj` so that the working directory and the `here()` anchor are set together. Running scripts from a bare session in another folder will misplace the outputs.

## Data

During the initial run, data_sources.R retrieves NHANES survey tables from the Centers for Disease Control and Prevention, along with public-use linked mortality files, and stores them in data/raw. This caching ensures that subsequent runs and crash recoveries do not require network access. Since this process occurs automatically, no manual data fetching is necessary, and the data/ directory is not managed by git.

## Reproducing from scratch

Run the scripts from the project root in the order shown below. Each script reads the cached frame, so once the cohort is built the second-stage scripts can run in any order.

```
source(here::here("R", "data_sources.R"))   # pull NHANES and mortality, cache to data/raw
source(here::here("R", "cohort.R"))         # derive the analysis frame
source(here::here("R", "database.R"))       # rebuild the cohort in DuckDB and check the counts
source(here::here("R", "eda.R"))            # cohort flow, missingness, baseline table, distributions

source(here::here("R", "prediction.R"))         # prediction, train the survival forest
source(here::here("R", "prediction_eval.R"))    # prediction, discrimination and calibration

source(here::here("R", "matching.R"))           # causal, matched estimate
source(here::here("R", "weighting.R"))          # causal, weighted estimate with bootstrap interval
source(here::here("R", "horizon.R"))            # five and ten-year risk differences
source(here::here("R", "positive_control.R"))   # smoking, a known harm
source(here::here("R", "negative_control.R"))   # accidental death, expected null
source(here::here("R", "washout.R"))            # reverse-causation check
source(here::here("R", "mediator.R"))           # body mass index sensitivity
source(here::here("R", "evalue.R"))             # unmeasured-confounding bound
```

Then render the report.

```
quarto render report.qmd
```

The outputs land in the `figures/` and `tables/` directories, and the report reads from both.

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
│   ├── database.R             # rebuild the cohort in DuckDB, check counts
│   ├── eda.R                  # cohort flow, missingness, baseline table, distributions
│   ├── prediction.R           # prediction model training
│   ├── prediction_eval.R      # prediction model scoring
│   ├── matching.R             # matched causal estimate
│   ├── weighting.R            # weighted causal estimate
│   ├── horizon.R              # five and ten-year horizons
│   ├── positive_control.R     # smoking control
│   ├── negative_control.R     # accidental-death control
│   ├── washout.R              # reverse-causation washout
│   ├── mediator.R             # body mass index sensitivity
│   └── evalue.R               # E-value
├── SQL/                       # DuckDB build, one file per derived table
├── data/{raw,interim,processed}/   # not tracked by git
├── figures/                   # rendered plots
└── tables/                    # rendered data tables and the baseline table
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
