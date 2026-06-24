# Project directories, anchored at the repo root by here().
# Put an empty .here file or an .Rproj at the root so the anchor resolves.

library(here)

dirs <- list(
  raw       = here("data", "raw"),
  interim   = here("data", "interim"),
  processed = here("data", "processed"),
  figures   = here("figures"),
  tables    = here("tables")
)

invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
