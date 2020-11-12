
# evaluate input arguments -----------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
nii.t1 <- NULL
nii.t1 <- NULL
nii.label <- NULL
label.vals <- "1x2x3"
norms.t1 <- "0.1x1.45x2.45x3.55x3.765794"
norms.t2 <- "0.1x1.95x3.1x4.5x6.738198"
for (i in seq(1,length(args),2)) {
  if (tolower(args[i]) == "t1") { nii.t1 <- args[i+1] }
  if (tolower(args[i]) == "t2") { nii.t2 <- args[i+1] }
  if (tolower(args[i]) == "label") { nii.label <- args[i+1] }
  if (tolower(args[i]) == "label-values") { label.vals <- args[i+1] }
  if (tolower(args[i]) == "t1.norms") { norms.t1 <- args[i+1] }
  if (tolower(args[i]) == "t2.norms") { norms.t2 <- args[i+1] }
}

# set up R environment ---------------------------------------------------------
library(nifti.io)
get_mode <- function(x) {
  x <- hist(x, breaks=50, plot=FALSE)
  x$mids[which.max(x$counts)]
}

# load nifti images ------------------------------------------------------------
t1 <- as.numeric(read.nii.volume(nii.t1,1))
t2 <- as.numeric(read.nii.volume(nii.t2,1))
label <- as.numeric(read.nii.volume(nii.label,1))
label.vals <- as.numeric(unlist(strsplit(label.vals, "x")))
norms.t1 <- as.numeric(unlist(strsplit(norms.t1, "x")))
norms.t2 <- as.numeric(unlist(strsplit(norms.t2, "x")))

# extract T1w distribution parameters ------------------------------------------
sub.t1 <- numeric(5)
sub.t1[1] <- get_mode(t1)
sub.t1[2] <- get_mode(t1[which(label==label.vals[1])])
sub.t1[3] <- get_mode(t1[which(label==label.vals[2])])
sub.t1[4] <- get_mode(t1[which(label==label.vals[3])])
sub.t1[5] <- quantile(t1, 0.98)

# extract T2w distribution parameters ------------------------------------------
sub.t2 <- numeric(5)
sub.t2[1] <- get_mode(t2)
sub.t2[2] <- get_mode(t2[which(label==label.vals[3])])
sub.t2[3] <- get_mode(t2[which(label==label.vals[2])])
sub.t2[4] <- get_mode(t2[which(label==label.vals[1])])
sub.t2[5] <- quantile(t2[which(label==label.vals[1])], 0.98)

# scale T1w values to normalized template values -------------------------------
scaled.t1 <- numeric(length(t1))
scaled.t1[t1 <= sub.t1[1]] <- 0 # set zero value at BG peak, zero anything below
scaled.t1[t1 > sub.t1[5]] <- norms.t1[5] # set voxels greater than 98 percentile to the 98% of normalized curve
for (i in 1:4) {
  idx <- which((t1 > sub.t1[i]) & (t1 <= sub.t1[i+1]))
  scaled.t1[idx] <- ((t1[idx] - sub.t1[i]) / (sub.t1[i+1] - sub.t1[i])) * (norms.t1[i+1] - norms.t1[i]) + norms.t1[i]
}

# scale T2w values to normalized template values -------------------------------
scaled.t2 <- numeric(length(t2))
scaled.t2[t2 <= sub.t2[1]] <- 0 # set zero value at BG peak, zero anything below
scaled.t2[t2 > sub.t2[5]] <- norms.t2[5] # set voxels greater than 98 percentile to the 98% of normalized curve
for (i in 1:4) {
  idx <- which((t2 > sub.t2[i]) & (t2 <= sub.t2[i+1]))
  scaled.t2[idx] <- ((t2[idx] - sub.t2[i]) / (sub.t2[i+1] - sub.t2[i])) * (norms.t2[i+1] - norms.t2[i]) + norms.t2[i]
}

# calculate myelin values ------------------------------------------------------
scaled.t1[scaled.t1 == 0] <- min(scaled.t1[scaled.t1 != 0])/2 # remove zeros to prevent Inf or Div-0
scaled.t2[scaled.t2 == 0] <- min(scaled.t2[scaled.t2 != 0])/2 # remove zeros to prevent Inf or Div-0
myelin <- scaled.t1 / scaled.t2 # Calculate Myelin^2
myelin[myelin > quantile(myelin, 0.98, na.rm=T)] <- quantile(myelin, 0.98, na.rm=T) # winsorize upper limit, CSF and noise in BG can have extreme values
myelin <- sqrt(myelin) # claculate myelin

# gather nifti parameters and save output --------------------------------------
img.dims <- nii.dims(nii.t1)
pixdim <- unlist(nii.hdr(nii.t1, "pixdim"))
orient <- nii.orient(nii.t1)
save.dir <- dirname(nii.t1)
init.nii(paste0(save.dir, "/myelin.nii"), img.dims, pixdim, orient)
write.nii.volume(paste0(save.dir, "/myelin.nii"), 1, myelin)

