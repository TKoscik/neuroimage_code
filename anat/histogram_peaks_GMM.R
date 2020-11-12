args <- commandArgs(trailingOnly = TRUE)

nii.file <- args[1]
mask.file <- args[2]
dir.scratch <- sprintf("%s/hist_peak_GMM", args[3])
k <- 3
iter <- 10
size <- 10000

if (length(args)>3) {
  for (i in seq(4,length(args),2)) {
    if (args[i] == "k") {
      k <- arg[i+1]
    } else if (args[i] == "iter") {
      iter <- args[i+1]
    } else if (args[i] == "size") {
      size <- args[i+1]
    } 
  }
}

pkg.ls <- c("R.utils", "tools", "mixtools", "nifti.io")
for (i in 1:length(pkg.ls)) {
  if (!require(pkg.ls[i], character.only = TRUE)) {
    if (pkg.ls[i] %in% c("nifti.io", ))
    install.packages(pkg.ls[i], dependencies = TRUE)
    library(x, character.only = TRUE)
  }
}

suppressMessages(library(R.utils))
suppressMessages(library(tools))
suppressMessages(library(mixtools))
suppressMessages(library(nifti.io))

if (file_ext(nii.file)=="gz") {
  dir.create(dir.scratch, showWarnings = FALSE, recursive=TRUE)
  new.name <- paste0(dir.scratch, "/", basename(file_path_sans_ext(nii.file)))
  gunzip(nii.file, new.name, overwrite=TRUE, remove=FALSE)
  nii.file <- new.name
}
if (file_ext(mask.file)=="gz") {
  dir.create(dir.scratch, showWarnings = FALSE, recursive=TRUE)
  new.name <- paste0(dir.scratch, "/", basename(file_path_sans_ext(mask.file)))
  gunzip(mask.file, new.name, overwrite=TRUE, remove=FALSE)
  mask.file <- new.name
}

nii <- read.nii.volume(nii.file, 1)
mask <- which(read.nii.volume(mask.file,1)==1, arr.ind=T)
nii <- nii[mask]

if (size > nrow(mask)) { size <- nrow(mask) }

mu <- numeric(k)
sigma <- numeric(k)
for (i in 1:iter) {
  x <- sample(nii, size)
  capture.output(mdl <- normalmixEM(x, k=k), file="/dev/null")
  mu.order <- order(mdl$mu)
  mu <- mu + mdl$mu[mu.order]/iter
  sigma <- sigma + mdl$sigma[mu.order]/iter
}
cat(sprintf("%0.3f,%0.3f", mu, sigma), sep=" ")

# clean up temporary files
fls <- list.files(dir.scratch, full.names = TRUE)
invisible(file.remove(fls))
invisible(file.remove(dir.scratch))
