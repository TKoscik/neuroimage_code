rm(list=ls())
gc()

CRAN.pkgs <- c("car",
               "devtools",
               "doParallel",
               "effects",
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
               "R.utils",
               "reshape2",
               "tools",
               "viridis")
GITHUB.pkgs <- c("tkoscik/nifti.io",
                 "tkoscik/fsurfR",
                 "tkoscik/tkmisc",
                 "tkoscik/ez.combat",
                 "tkoscik/power.pro")

# Setup a library including the appropriate R packages -------------------------
## maybe remove this and force people to run manually?
inc.r.path=sprintf("~/R/INC_library/%s.%s", R.Version()$major, R.Version()$minor)
if (!(inc.r.path %in% .libPaths())) {
  .libPaths( c( inc.r.path , .libPaths() ) )
  dir.create(inc.r.path, warnings=FALSE)
}

pkgs <- as.character(unique(as.data.frame(installed.packages())$Package))

# check and install missing packages from CRAN ---------------------------------
CRAN.chk <- which(!(CRAN.pkgs %in% pkgs))
if (length(CRAN.chk)>0) {
  install.packages(pkgs=CRAN.pkgs[CRAN.chk], lib=.libPaths()[1], repos="http://cran.r-project.org")
}

# check and install from github
GITHUB.chk <- which(!(GITHUB.pkgs %in% pkgs))
for (i in GITHUB.chk) {
    devtools::install_github(i, )
}

