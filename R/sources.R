# NHANES survey tables and the public-use linked mortality files.
# Raw files cache to data/raw, and each download lands in a temporary file
# that renames only on success, so a failed transfer cannot affect the cache.

nhanes_base    <- "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public"
mortality_base <- "https://ftp.cdc.gov/pub/Health_Statistics/NCHS/datalinkage/linked_mortality"

cycles <- tibble::tribble(
  ~cycle,      ~suffix,
  "2007-2008", "E",
  "2009-2010", "F",
  "2011-2012", "G",
  "2013-2014", "H",
  "2015-2016", "I",
  "2017-2018", "J"
)

demo_cols <- c("RIDAGEYR", "RIAGENDR", "RIDRETH1", "DMDEDUC2", "INDFMPIR",
               "WTMEC2YR", "SDMVPSU", "SDMVSTRA")
paq_cols  <- c("PAQ650", "PAQ655", "PAD660", "PAQ665", "PAQ670", "PAD675")
smq_cols  <- c("SMQ020", "SMQ040")
mcq_cols  <- c("MCQ160C", "MCQ160F", "MCQ220")
bmx_cols  <- c("BMXBMI")

local_copy <- function(url, file) {
  if (!file.exists(parent_dir(file))) {
    part <- tempfile(tmpdir = dirname(file))
    on.exit(unlink(part), add = TRUE)
    utils::download.file(url, part, mode = "wb", quiet = TRUE)
    file.rename(part, file)
  }
  file
}

nhanes_table <- function(cyc, suffix, stem, columns) {
  table <- paste0(stem, "_", suffix)
  url   <- paste0(nhanes_base, "/", substr(cyc, 1, 4), "/DataFiles/", table, ".xpt")
  file  <- local_copy(url, file.path("data", "raw", paste0(table, ".XPT")))
  haven::read_xpt(file) |>
    dplyr::select(dplyr::any_of(c("SEQN", columns))) |>
    dplyr::mutate(cycle = cyc)
}

nhanes_stack <- function(stem, columns) {
  purrr::pmap_dfr(cycles, function(cycle, suffix)
    nhanes_table(cycle, suffix, stem, columns))
}

# Fixed-width layout from the NCHS sample program shipped with the .dat files.
mortality_table <- function(cyc) {
  name <- paste0("NHANES_", gsub("-", "_", cyc), "_MORT_2019_PUBLIC.dat")
  file <- local_copy(paste0(mortality_base, "/", name),
                     file.path("data", "raw", name))
  readr::read_fwf(
    file,
    readr::fwf_cols(SEQN = c(1, 6), eligstat = c(15, 15), mortstat = c(16, 16),
                    ucod = c(17, 19), permth_exm = c(46, 48)),
    col_types = "iiici",
    na = c("", ".")
  )
}

raw_bundle <- function() {
  list(
    demo = nhanes_stack("DEMO", demo_cols),
    paq  = nhanes_stack("PAQ",  paq_cols),
    smq  = nhanes_stack("SMQ",  smq_cols),
    mcq  = nhanes_stack("MCQ",  mcq_cols),
    bmx  = nhanes_stack("BMX",  bmx_cols),
    mort = purrr::map_dfr(cycles$cycle, mortality_table)
  )
}
