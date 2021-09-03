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
inc.r.path=sprintf("~/R/INC/%s.%s", R.Version()$major, R.Version()$minor)
if (!(inc.r.path %in% .libPaths())) {
  dir.create(inc.r.path, showWarnings=FALSE, recursive=TRUE)
  .libPaths(c(inc.r.path , .libPaths()))
  rprofile.fid <- file("~/.Rprofile")
  out.str <- sprintf('.libPaths(c("~/R/INC/%s.%s", .libPaths()))',
                     R.Version()$major,
                     R.Version()$minor)
  writeLines(out.str, con = rprofile.fid)
  close(rprofile.fid)
}

pkgs <- as.character(unique(as.data.frame(installed.packages())$Package))

# check and install missing packages from CRAN ---------------------------------
CRAN.chk <- which(!(CRAN.pkgs %in% pkgs))
if (length(CRAN.chk)>0) {
  install.packages(pkgs=CRAN.pkgs[CRAN.chk], lib=inc.r.path, repos="http://cran.r-project.org", verbose=FALSE)
  print(CRAN.pkgs[CRAN.chk])
}

# check and install from github ------------------------------------------------
GITHUB.chk <- which(!(unlist(strsplit(GITHUB.pkgs, "[/]"))[seq(2, length(GITHUB.pkgs)*2, 2)] %in% pkgs))
for (i in 1:length(GITHUB.chk)) {
  library(devtools)
  library(withr)
  with_libpaths(new=inc.r.path, install_github(GITHUB.pkgs[i], quiet=TRUE))
  print(GITHUB.pkgs[i])
}

