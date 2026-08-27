# testthat evaluates each file in a child of the global environment and does
# not load R/ on its own, so without this the suite fails on "could not find
# function" rather than on anything it is meant to catch.
#
# testthat also sets the working directory to the test folder, so the root is
# found by walking up to the directory that holds _targets.R. That keeps one
# command working from the project root, from tests/testthat, and in
# continuous integration.

project_root <- function(start = ".") {
  path <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "_targets.R"))) return(path)
    parent <- dirname(path)
    if (identical(parent, path)) stop("could not find _targets.R above ", start)
    path <- parent
  }
}

targets::tar_source(file.path(project_root(), "R"))
