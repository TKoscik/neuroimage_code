args <- commandArgs(trailingOnly = TRUE)

# check for single input
if (length(args) != 1) { stop("A single, 4D input must be provided") }
nii <- args[1]

library(nifti.io, quietly=TRUE)
library(matrixStats, quietly=TRUE)
library(tools, quietly=TRUE)

# check if unzipped
if (file_ext(nii) == "gz") { stop("input NII.GZ must be decompressed first") }

# get image dimensions and check if 4D
sz <- nii.dims(nii)
if (sz[4] <= 1) { stop("Not a 4D NII file") }

# load orientation parameters for output
pixdim <- unlist(nii.hdr(nii, "pixdim"))
orient <- nii.orient(nii)

# load timeseries into matrix, voxels in rows, time across columns
ts <- matrix(0, nrow=prod(sz[1:3]), ncol=sz[4])
for (i in 1:sz[4]) { ts[ ,i] <- read.nii.volume(nii, i) }

# calculate time-series z scores
ts[ts < quantile(ts, 0.5)] <- 0
z <- (ts - rowMeans(ts)) / rowSds(ts)
z <- array(z, dim=sz)

## save z-score if desired
tname <- unlist(strsplit(unlist(strsplit(basename(nii), "[.]"))[1], "_"))
z.nii <- paste0(dirname(nii), "/",
  paste(tname[1:(length(tname)-1)], collapse="_"),
  "_mod-", tname[length(tname)],
  "_tensor-z.nii")
init.nii(z.nii, dims=sz, pixdim=pixdim, orient=orient)
for (i in 1:sz[4]) { write.nii.volume(z.nii, i, z[ , , ,i]) }

