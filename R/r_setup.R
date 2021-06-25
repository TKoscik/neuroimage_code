rm(list=ls())
invisible(gc())

CRAN.pkgs <- c("car",
               "devtools",
               "doParallel",
               "effects",
               "ez.combat",
               "fastcluster",
               "ggplot2",
               "grid",
               "gridExtra",
               "Hmisc",
               "jsonlite",
               "lme4",
               "lmerTest",
               "MASS",
               "mixtools",
               "nifti.io",
               "R.utils",
               "reshape2",
               "tools",
               "viridis")
GITHUB.pkgs <- c("tkoscik/fsurfR",
                 "tkoscik/tkmisc")

# Setup a library including the appropriate R packages -------------------------
## maybe remove this and force people to run manually?
#inc.r.path=sprintf("~/R/INC_library/%s.%s", R.Version()$major, R.Version()$minor)
#if (!(inc.r.path %in% .libPaths())) {
#  .libPaths( c( inc.r.path , .libPaths() ) )
#  dir.create(inc.r.path, showWarnings=FALSE)
#}
lib.path <- .libPaths()
lib.path <- lib.path[length(lib.path)-1]

pkgs <- as.character(unique(as.data.frame(installed.packages())$Package))

# check and install missing packages from CRAN ---------------------------------
CRAN.chk <- which(!(CRAN.pkgs %in% pkgs))
if (length(CRAN.chk)>0) {
  install.packages(pkgs=CRAN.pkgs[CRAN.chk], lib=lib.path, repos="http://cran.r-project.org")
}

# check and install from github ------------------------------------------------
library(devtools)
library(withr)
GITHUB.chk <- which(!(GITHUB.pkgs %in% pkgs))
for (i in GITHUB.chk) {
    with_libpaths(new=lib.path, install_github(GITHUB.pkgs[i]))
}

