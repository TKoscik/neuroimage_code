args <- commandArgs(trailingOnly = TRUE)

# set defaults -----------------------------------------------------------------
zdir <- "abs"
zthresh <- 1.5
plane <- "z"
nthresh <- 0.15
method <- "spline"
value <- as.numeric(NA)

# parse command arguments ------------------------------------------------------
for (i in 1:length(args)) {
  if (args[i] %in% c("i", "img", "image")) { nii <- args[i+1] }
  if (args[i] %in% c("zmap")) { zmap <- args[i+1] }
  if (args[i] %in% c("zdir", "direction")) { zdir <- args[i+1] }
  if (args[i] %in% c("zt", "zthresh")) { zthresh <- as.numeric(args[i+1]) }
  if (args[i] %in% c("p", "plane")) { plane <- args[i+1] }
  if (args[i] %in% c("n", "nt", "nthresh")) { nthresh <- as.numeric(args[i+1]) }
  if (args[i] %in% c("m", "method")) { method <- args[i+1] }
  if (args[i] %in% c("v", "value")) { value <- args[i+1] }
  if (args[i] %in% c("dir", "dirsave", "dir.save", "save", "savedir", "save.dir")) { dir.save <- args[i+1] }
}
if (!exists(dir.save)) { dir.save <- dirname(nii)}

# setup environment ------------------------------------------------------------
library(nifti.io, quietly=TRUE, warn.conflicts=FALSE)
library(tools, quietly=TRUE, warn.conflicts=FALSE)
library(zoo, quietly=TRUE, warn.conflicts=FALSE)

# get image dimensions and check if 4D -----------------------------------------
sz <- nii.dims(nii)
if (sz[4] <= 1) { stop("Not a 4D NII file") }

# load orientation parameters for output ---------------------------------------
pixdim <- unlist(nii.hdr(nii, "pixdim"))
orient <- nii.orient(nii)

# load timeseries and zmaps into arrays ----------------------------------------
ts <- array(0, dim=sz)
z <- array(0, dim=sz)
mask <- array(0, dim=sz)
for (i in 1:sz[4]) {
  ts[ , , , i] <- read.nii.volume(nii, i)
  z[ , , , i] <- read.nii.volume(zmap, i)
}

# set direction of zmap --------------------------------------------------------
z <- switch(zdir, `abs` = abs(z), `pos` = z, `neg` =  z * (-1))

# convert specified plane to index value ---------------------------------------
plane.idx <- switch(plane, `z` = 3, `y` = 2, `x` = 1)
in.plane <- 1:3
in.plane <- in.plane[-which(in.plane==plane.idx)]

# threshold slices in each volume independently --------------------------------
for (i in 1:sz[plane.idx]) {
  for (j in 1:sz[4]) {
    tmp <- switch(as.character(plane.idx),
      `1` = tmp <- sum(z[i, , ,j] > zthresh, na.rm=TRUE),
      `2` = tmp <- sum(z[ ,i, ,j] > zthresh, na.rm=TRUE),
      `3` = tmp <- sum(z[ , ,i,j] > zthresh, na.rm=TRUE))
    if (tmp > (prod(sz[in.plane]) * nthresh)) { mask[ , ,i,j] <- 1 }
  }
}

# get save prefix ---------------------------------------------------------------
fname <- unlist(strsplit(file_path_sans_ext(basename(nii)), split="_"))
fname[length(fname)] <- paste0("mod-", fname[length(fname)])
fname <- paste(fname, collapse="_")

# save mask ---------------------------------------------------------------------
init.nii(paste0(dir.save, "/", fname, "_mask-deghost.nii"), sz, pixdim, orient)
for (i in 1:sz[4]) {
  write.nii.volume(paste0(dir.save, "/", fname, "_mask-deghost.nii"), i, mask[ , , ,i])
}

# add in cleaned values ---------------------------------------------------------
if (method != "none") {
  ts <- matrix(ts, nrow=prod(sz[1:3]), ncol=sz[4])
  mask <- matrix(mask, nrow=prod(sz[1:3]), ncol=sz[4])
  ts[mask == 1] <- NA
  if (method == "linear" ) {
    for (i in 1:nrow(ts)) { ts[i, ] <- na.approx(ts[i, ], rule=2) }
  } else if (method == "spline" ) {
    for (i in 1:nrow(ts)) { ts[i, ] <- na.spline(ts[i, ]) }
  } else if (method == "mean" ) {
    for (i in 1:nrow(ts)) { ts[i, is.na(ts[i, ])] <- mean(ts[i, ], na.rm=TRUE) }
  } else if (method == "median" ) {
    for (i in 1:nrow(ts)) { ts[i, is.na(ts[i, ])] <- median(ts[i, ], na.rm=TRUE) }
  } else if (is.numeric(method)) {
    for (i in 1:nrow(ts)) { ts[i, is.na(ts[i, ])] <- value }    
  }
  ts <- array(ts, dim=sz)
  init.nii(paste0(dir.save, "/", fname, "_deghost.nii"), sz, pixdim, orient)
  for (i in 1:sz[4]) {
    write.nii.volume(paste0(dir.save, "/", fname, "_deghost.nii"), i, ts[ , , ,i])
  }
}

