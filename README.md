[![CI](https://github.com/jsf3467v/causal-inference-nhanes/actions/workflows/ci.yml/badge.svg)](https://github.com/jsf3467v/causal-inference-nhanes/actions/workflows/ci.yml)

# Does Meeting the Aerobic Activity Guideline Lower Mortality

The project answers this question in two acts. The first act measures how well baseline characteristics predict death within five years. The second act estimates the causal effect of the activity itself, which requires separating that effect from the many ways active and inactive adults already differ at baseline.

The data comprise six cycles of the National Health and Nutrition Examination Survey from 2007 through 2018, which is linked to mortality records through 2019. The cohort is adults age 40 and older who were eligible for follow-up and had a known activity level. Activity is leisure-time aerobic minutes per week, and 150 minutes marks the guideline threshold.

**[Read the full report](https://jsf3467v.github.io/causal-inference-nhanes/)**, which continuous integration renders and publishes on every push to main.

## Result

Meeting the guideline is associated with a 2.6 percentage point decrease in five-year mortality risk among those who meet it. The population average treatment effect on the treated is $-0.0257$, with a 95% confidence interval ranging from $-0.0330$ to $-0.0184$. The co-primary landmark, which excludes the first 24 months and redefines follow-up, shows a similar effect of $-0.0241$. The consistency between these two findings suggests the effect isn't due to frail individuals being both inactive and near death. An E-value of $3.1$ indicates that an unmeasured confounder would need at least this level of association with both activity and mortality to negate the observed effect.

The first act reaches a time-dependent area under the curve of $0.829$ at five years against $0.794$ for an age-only model scored the same way. So, everything besides age buys about three and a half points of discrimination. Validation performance is flat across an eighty-fold range of node sizes and the selected value sits at the edge of the grid, which says the forest's flexibility is not being used and that mortality here is close to a smooth function of age. Predicting the outcome well and estimating the effect of changing it are separate problems, and this is what the separation looks like.

This remains observational. The estimate rests on the causal diagram being right, and the diagram is an assumption rather than a finding.

## Design

The estimand is fixed in [`protocol.md`](protocol.md) before any estimation runs. It is the population average treatment effect on the treated at five years, estimated by entropy balancing ([Hainmueller 2012](https://doi.org/10.1093/pan/mpr025)) with the pooled examination weights, with variance from survey bootstrap replicate weights that respect the cluster design. The adjustment sets derive from the causal diagram in `R/dag.R` and are pinned by a test. A reverse-causation landmark is co-primary. The protocol names every sensitivity analysis, including a smoking positive control, an accidental-death negative control with competing risks, a mediator pair, and an E-value.

## Audit

The protocol, causal diagram, and pipeline graph govern every design decision, ensuring no script deviates from the estimand, adjustment sets, or execution order. The survey design influences both the estimate and variance, with each interval undergoing a replicate construction. Adjustment sets are determined and validated through testing, while the system's tests, database cross-checks, and continuous integration detect actual errors rather than passing blindly.

Three issues remain unresolved. Missing family income is handled by complete-case deletion; the exposure is dichotomized at 150 minutes per week; and the implied conditional independencies in the causal diagram have not yet been tested against the data.

## Reproducing

The project is a [`targets`](https://docs.ropensci.org/targets/) pipeline. Reproduction is one command from the project root, intermediate results cache to `_targets/`, and an interrupted run resumes at the first stale node.

```r
install.packages("renv")
renv::restore()                    # installs the pinned packages from renv.lock
targets::tar_make()                # pulls data, builds everything, renders the report
```

`renv::restore()` installs the package versions recorded in `renv.lock`, which continuous integration also restores. The pipeline needs R 4.4 or newer and [Quarto](https://quarto.org) for the report. It runs on macOS, Linux, and Windows, and all paths are relative to the project root.

Raw files are downloaded once from the Centers for Disease Control and Prevention and stored in the `data/raw` directory. Each file is first downloaded with a temporary name and only renamed upon successful completion, preventing partial files from remaining in the cache if a transfer fails.

Three core operations are initialized: the replicate weight construction, the data split, and the forest. The replicate weight loop is designed to run across the available CPU cores. Since no estimation step employs randomness, the output remains consistent regardless of the number of workers. The forest thread count is set in `R/scoring.R` due to each thread's generator being seeded individually.

## Outputs

Generated outputs are not monitored. `tar_make()` saves tables in `tables/`, figures in `figures/`, exports to Tableau in `dashboard/`, and creates the report at `report.html`. During continuous integration, the report is generated on each push to main and published to the `gh-pages` branch. The raw cohort patterns are displayed on a [Tableau Public dashboard](https://public.tableau.com/app/profile/a.keith/viz/ActivityandMortalityChart/Dashboard1).

## Testing

The tests run on synthetic data and require no download. One test simulates a cohort with a known true risk difference in closed form and asserts that the estimator recovers it. A second pins the adjustment sets derived from the causal diagram. Fixture tests exercise the published sentinel codes for refused and do-not-know responses across every recoding path, and a further fixture checks that codes outside the published range become missing rather than being assigned a category invented from the data.

```r
testthat::test_dir("tests/testthat", stop_on_failure = TRUE)
```

## Layout

```
_targets.R        pipeline graph, options, seeds
protocol.md       the estimand, fixed before estimation
AUDIT.md          the faults found in the previous version and their resolution
R/                functions only, sourced by the pipeline
SQL/              the DuckDB mirror of the cohort build
tests/testthat/   fixture and estimator tests
report.qmd        report source, rendered by the pipeline
```