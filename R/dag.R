# The causal diagram, encoded once. Both adjustment sets derive from it with
# the canonical criterion, which excludes descendants of the exposure.

study_dag <- function() {
  dagitty::dagitty("dag {
    activity -> death
    activity -> bmi
    bmi -> death
    smoke -> activity
    smoke -> death
    smoke -> prior_disease
    smoke -> bmi
    prior_disease -> activity
    prior_disease -> death
    age -> activity          age -> death          age -> smoke
    age -> prior_disease
    sex -> activity          sex -> death          sex -> smoke
    race -> activity         race -> death         race -> smoke
    education -> activity    education -> death    education -> smoke
    income_ratio -> activity income_ratio -> death income_ratio -> smoke
    cycle -> activity        cycle -> death        cycle -> smoke
  }")
}

adjustment_set <- function(dag, exposure) {
  set <- dagitty::adjustmentSets(dag, exposure = exposure, outcome = "death",
                                 type = "canonical")[[1]]
  sort(as.character(set), method = "radix")
}

dag_figure <- function(dag, path) {
  grDevices::png(parent_dir(path), width = 950, height = 650, res = 120)
  plot(dagitty::graphLayout(dag))
  grDevices::dev.off()
  path
}
