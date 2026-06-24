# Gathers NHANES survey tables and the public-use linked mortality files.
# Raw files cache to data/raw so reruns and crash recovery skip the network.

library(here)
library(haven)
library(readr)
library(purrr)
library(dplyr)

source(here("R", "paths.R"))

# CDC hosts each cycle under its first year inside a DataFiles folder.
nhanes_base    <- "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public"
mortality_base <- "https://ftp.cdc.gov/pub/Health_Statistics/NCHS/datalinkage/linked_mortality"

cycles <- tibble::tribble(
  ~cycle,       ~suffix,
  "2007-2008",  "E",
  "2009-2010",  "F",
  "2011-2012",  "G",
  "2013-2014",  "H",
  "2015-2016",  "I",
  "2017-2018",  "J"
)

local_copy <- function(url, file) {
  if (!file.exists(file)) download.file(url, file, mode = "wb", quiet = TRUE)
  file
}

present_columns <- function(df, columns) {
  dplyr::select(df, dplyr::any_of(c("SEQN", columns)))
}

nhanes_table <- function(cyc, suffix, stem, columns) {
  table <- paste0(stem, "_", suffix)
  url   <- paste0(nhanes_base, "/", substr(cyc, 1, 4), "/DataFiles/", table, ".xpt")
  file  <- local_copy(url, file.path(dirs$raw, paste0(table, ".XPT")))
  haven::read_xpt(file) |> present_columns(columns) |> dplyr::mutate(cycle = cyc)
}

nhanes_stack <- function(stem, columns) {
  purrr::pmap_dfr(cycles, function(cycle, suffix)
    nhanes_table(cycle, suffix, stem, columns))
}

# Continuous NHANES public-use layout. Confirm against the NCHS R sample
# program shipped with the .dat files before trusting the estimates.
mortality_table <- function(cyc) {
  name <- paste0("NHANES_", gsub("-", "_", cyc), "_MORT_2019_PUBLIC.dat")
  file <- local_copy(paste0(mortality_base, "/", name),
                     file.path(dirs$raw, name))
  readr::read_fwf(
    file,
    readr::fwf_cols(SEQN = c(1, 6), eligstat = c(15, 15), mortstat = c(16, 16),
                    ucod = c(17, 19), permth_exm = c(46, 48)),
    col_types = "iiici",
    na = c("", ".")
  )
}

mortality_stack <- function() {
  purrr::map_dfr(cycles$cycle, mortality_table)
}

# Confirm these NHANES variable codes against the PAQ, SMQ, MCQ codebooks.
demo_cols <- c("RIDAGEYR", "RIAGENDR", "RIDRETH1", "DMDEDUC2", "INDFMPIR",
               "WTMEC2YR", "SDMVPSU", "SDMVSTRA")
paq_cols  <- c("PAQ650", "PAQ655", "PAD660", "PAQ665", "PAQ670", "PAD675")
smq_cols  <- c("SMQ020", "SMQ040")
mcq_cols  <- c("MCQ160C", "MCQ160F", "MCQ220")
bmx_cols  <- c("BMXBMI")

raw <- list(
  demo = nhanes_stack("DEMO", demo_cols),
  paq  = nhanes_stack("PAQ",  paq_cols),
  smq  = nhanes_stack("SMQ",  smq_cols),
  mcq  = nhanes_stack("MCQ",  mcq_cols),
  bmx  = nhanes_stack("BMX",  bmx_cols),
  mort = mortality_stack()
)

saveRDS(raw, file.path(dirs$interim, "raw_bundle.rds"))
message("Pulled ", nrow(raw$demo), " participants across ", nrow(cycles), " cycles.")

