args <- commandArgs(trailingOnly = TRUE)

nii.file <- args[1]
mask.file <- args[2]
k <- 3
iter <- 10
size <- 10000
dir.scratch <- sprintf("/Shared/inc_scratch/scratch_%s", format(Sys.time(), "%Y%m%d%H%M%S"))
if (length(args)>2) {
  for (i in seq(3,length(args),2)) {
    if (arg[i] <- "k") {
      k <- arg[i+1]
    } else if (arg[i] <- "iter") {
      iter <- arg[i+1]
    } else if (arg[i] <- "size") {
      size <- arg[i+1]
    }
  }
}

suppressMessages(library(R.utils))
suppressMessages(library(tools))
suppressMessages(library(mixtools))
suppressMessages(library(nifti.io))

mask.file <- "/Shared/koscikt_scratch/scratch_tk/sub-105_ses-35n7dw4yu9_site-00201_mask-brain.nii.gz"
nii.file <- "/Shared/koscikt_scratch/scratch_tk/sub-105_ses-35n7dw4yu9_site-00201_T1w.nii.gz"

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

mu <- numeric(3)
for (i in 1:iter) {
  x <- sample(nii, size)
  capture.output(mdl <- normalmixEM(x, k=3), file="/dev/null")
  mu <- mu + sort(mdl$mu)
}
mu <- mu/iter
cat(mu, sep="x")

# clean up temporary files
fls <- list.files(dir.scratch, full.names = TRUE)
invisible(file.remove(fls))
invisible(file.remove(dir.scratch))
