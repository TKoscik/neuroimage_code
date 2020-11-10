args <- commandArgs(trailingOnly = TRUE)

library(nifti.io)
get_mode <- function(x) {
  x <- hist(x, breaks=50, plot=FALSE)
  x$mids[which.max(x$counts)]
}

norm.t1 <- as.numeric(read.nii.volume(args[1],1))
norm.t2 <- as.numeric(read.nii.volume(args[2],1))
norm.roi <- as.numeric(read.nii.volume(args[3],1))
norm.roi1 <- which(norm.roi==1)
norm.roi2 <- which(norm.roi==2)
sub.t1 <- as.numeric(read.nii.volume(args[4],1))
sub.t2 <- as.numeric(read.nii.volume(args[5],1))
sub.roi <- as.numeric(read.nii.volume(args[6],1))
sub.roi1 <- which(sub.roi==1)
sub.roi2 <- which(sub.roi==2)

qval <- quantile(norm.t1, 0.98)
norm.t1[norm.t1 > qval] <- qval
norm.t1[norm.t1 < 0] <- 0
t1.Xr <- get_mode(norm.t1[norm.roi1])
t1.Yr <- get_mode(norm.t1[norm.roi2])

qval <- quantile(norm.t2, 0.98)
norm.t2[norm.t2 > qval] <- qval
norm.t2[norm.t2 < 0] <- 0
t2.Xr <- get_mode(norm.t2[norm.roi1])
t2.Yr <- get_mode(norm.t2[norm.roi2])

qval <- quantile(sub.t1, 0.98)
sub.t1[sub.t1 > qval] <- qval
sub.t1[sub.t1 < 0] <- 0
t1.Xs <- get_mode(sub.t1[sub.roi1])
t1.Ys <- get_mode(sub.t1[sub.roi2])

qval <- quantile(sub.t2, 0.98)
sub.t2[sub.t2 > qval] <- qval
sub.t2[sub.t2 < 0] <- 0
t2.Xs <- get_mode(sub.t2[sub.roi1])
t2.Ys <- get_mode(sub.t2[sub.roi2])

sub.t1 <- ((t1.Xr - t1.Yr)/(t1.Xs - t1.Ys)) * sub.t1 + (((t1.Xs * t1.Yr) - (t1.Xr * t1.Ys))/(t1.Xs - t1.Ys))
sub.t2 <- ((t2.Xr - t2.Yr)/(t2.Xs - t2.Ys)) * sub.t2 + (((t2.Xs * t2.Yr) - (t2.Xr * t2.Ys))/(t2.Xs - t2.Ys))

myelin <- sub.t1 / sub.t2

img.dims <- nii.dims(args[1])
pixdim <- unlist(nii.hdr(args[1], "pixdim"))
orient <- nii.orient(args[1])
save.dir <- dirname(args[1])

init.nii(paste0(save.dir, "/myelin.nii"), img.dims, pixdim, orient)
write.nii.volume(paste0(save.dir, "/myelin.nii"), 1, myelin)
