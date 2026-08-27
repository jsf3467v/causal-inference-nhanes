# Protocol

This document fixes the estimand before any estimation runs. Every analysis in the pipeline is an instance of this specification, and any departure is a named sensitivity analysis listed below.

## Estimand

The target quantity measures the population average treatment effect on the treated over five years. Specifically, it reflects the difference in five-year mortality risk between noninstitutionalized U.S. adults aged 40 and older who meet the aerobic activity guideline and the risk they would have faced if they did not meet the guideline. 

The population is derived by pooling examination weights from six NHANES cycles spanning 2007 to 2018. Exposure is defined as meeting the 150 moderate-equivalent leisure minutes per week guideline at the time of examination. The outcome is all-cause death within 60 months, as recorded in linked mortality data with follow-up through 2019. The risk difference is obtained from weighted Kaplan-Meier curves.

## Identification

## Identification

The adjustment sets are derived from the causal diagram in `R/dag.R` rather than chosen by the analyst. The diagram encodes which variables cause which, and `dagitty` reads the sets off it under the canonical criterion, which conditions on ancestors of the exposure and outcome and excludes descendants of the exposure by construction. This matters because a list written by hand can drift from the reasoning that produced it, and because the exclusion of descendants is then a property of the criterion rather than a judgement call made one variable at a time. Body mass index is a descendant of activity, so it stays out of the primary adjustment. Survey cycle has edges to both exposure and outcome, so calendar time enters the adjustment automatically.

## Estimation

Entropy balancing reweights the control arm to the treated arm on the derived adjustment set, with the pooled examination weight supplied as a sampling weight. The risk difference is read from the balanced survival curves at 60 months. Variance comes from Rao-Wu-Yue-Beaumont rescaled bootstrap replicate weights that respect the stratified two-per-stratum cluster design, and the balancing model refits inside every replicate. Every reported interval passes through this one construction.

## Co-primary landmark

Reverse causation is the largest threat, so the landmark analysis is co-primary rather than a side check. Participants who died or were censored before 24 months are excluded, follow-up re-anchors at the landmark, and the risk difference is estimated over the following 60 months. The size of the attenuation is the most informative result the study produces.

## Named sensitivity analyses

1. A ten-year horizon on the same weighted curves.
2. A positive control of current against never smoking, with its own derived adjustment set.
3. A negative control on accidental death, estimated as an Aalen-Johansen cumulative incidence with other causes as competing events.
4. A mediator pair on the subset with measured body mass index, one fit without it and one with it.
5. An E-value on the risk-ratio scale for unmeasured confounding.

## Open items

Missing family income remains handled by complete-case deletion. The exposure remains dichotomized at 150 minutes per week. The diagram itself remains an assumption whose implied conditional independencies have not been tested against the data. These are left open deliberately.
