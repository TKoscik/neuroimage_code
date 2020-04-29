args <- commandArgs(trailingOnly=TRUE)

input_nii <- NULL
input_mask <- NULL
input_data <- NULL
participant <- "participant_id"
session <- "session_id"
batch <- NULL
model <- NULL
dir.scratch <- NULL
dir.save <- NULL

n.args <- length(args)
for (i in seq(1,n.args,2)) {
    if (args[i] == "input_nii") { input_nii <- args[i+1] }
    if (args[i] == "input_mask") { input_mask <- args[i+1] }
    if (args[i] == "input_data") { input_data <- args[i+1] }
    if (args[i] == "participant") { participant <- args[i+1] }
    if (args[i] == "session") { session <- args[i+1] }
    if (args[i] == "batch") { batch <- args[i+1] }
    if (args[i] == "model") { model <- args[i+1] }
    if (args[i] == "dir.scratch") { dir.scratch <- args[i+1] }
    if (args[i] == "dir.save") { dir.save <- args[i+1] }
}

library(nifti.io)
library(ez.combat)
library(R.utils)
library(tools)

if (is.null(dir.scratch)) { dir.scratch <- paste0("/Shared/inc_scratch/scratch_", format(Sys.time(), "%Y%m%dT%H%M%S")) }
if (is.null(dir.save)) { 
  if (dir.exists(input_nii)) {
    dir.save <- paste0(input_nii, "_combat")
  } else {
    temp.str <- unlist(strsplit(input_nii, "/"))
    temp.str <- temp.str[-length(temp.str)]
    dir.save <- paste0(paste(temp.str, collapse="/"), "_combat")
  }
}

# Load dataset
pf.ext <- file_ext(input_data)
if (pf.ext == "csv") { 
  pf <- read.csv(input_data)
} else if (pf.ext == "tsv") {
  pf <- read.csv(input_data, sep="\t")
} else {
  stop("Unknown file extension for input dateset file, must be csv or tsv.")
}

# Gather Files ----------------------------------------------------------------
if (!dir.exists(dir.scratch)) { dir.create(dir.scratch) }
# match nifti files to dataset
if (dir.exists(input_nii)) {
  nii.list <- list.files(input_nii, pattern="nii", full.names=TRUE)
} else {
  nii.list <- unlist(strsplit(input_nii, ","))
}

pf$nii.file <- rep(as.character(NA), nrow(pf))
for (i in 1:nrow(pf)) {
  which.match <- numeric(0)
  if (is.null(session)) {
    which.match <- which(grepl(pf[i,participant], nii.list))
  } else {
    which.match <- which(grepl(pf[i,participant], nii.list) & grepl(pf[i,session], nii.list))
  }
  if (length(which.match) == 0) {
    if (is.null(session)) {
      warning(sprintf("NII file not found: sub-%s", pf[i,participant]))
    } else {
      warning(sprintf("NII file not found: sub-%s_ses-%s", pf[i,participant], pf[i,session]))
    }
  } else {
    pf$nii.file[i] <- nii.list[which.match]
    nii.ext <- file_ext(pf$nii.file[i])
    if (nii.ext == "gz") {
      new.file <- paste0(dir.scratch, "/", file_path_sans_ext(basename(pf$nii.file[i])))
      gunzip(pf$nii.file[i], destname=new.file, overwrite=TRUE, remove=FALSE)
      pf$nii.file[i] <- new.file
    } else {  
      file.copy(pf$nii.file[i], dir.scratch)
      new.file <- paste0(dir.scratch, "/", basename(pf$nii.file[i]))
      pf$nii.file[i] <- new.file
    }
  }
}
pf <- pf[!is.na(pf$nii.file), ]

# get Mask
mask.ext <- file_ext(input_mask)
if (mask.ext == "gz") {
  new.file <- paste0(dir.scratch, "/mask.nii")
  gunzip(input_mask, destname=new.file, overwrite=TRUE, remove=FALSE)
} else {
  file.copy(input_mask, paste0(dir.scratch, "/mask.nii"))
}
mask <- which(read.nii.volume(paste0(dir.scratch, "/mask.nii"),1)==1, arr.ind=TRUE)
n.vxls <- nrow(mask)

# parse model for terms to include
if (!is.null(model)) {
  model.terms <- unique(unlist(strsplit(labels(terms(as.formula(model))), split=":")))
} else {
  model.terms <- NULL
}
n.vars <- length(model.terms) + 1

# load NII data
tx <- matrix(as.numeric(NA), nrow=nrow(pf), ncol=n.vxls)
for (i in 1:nrow(pf)) {
  tx[i, ] <- read.nii.volume(pf$nii.file[i],1)[mask]
}
sd.chk <- apply(tx,2,sd, na.rm=TRUE)
incl.col <- which(sd.chk != 0)
mask <- mask[incl.col, ]
tx <- tx[ ,incl.col]

# Setup matrix for combat
df <- data.frame(batch=pf[ ,batch], pf[ ,model.terms], tx)
colnames(df)[1:(n.vars)] <- c(batch, model.terms)

# run combat harmonization
cbf <- ez.combat(df = df, batch.var = batch, exclude.var = model.terms, model = model)$df

# save adjusted variables
for (i in 1:nrow(pf)) {
  temp <- read.nii.volume(pf$nii.file[i],1) * NA
  temp[mask] <- as.numeric(unlist(cbf[i, (n.vars+1):ncol(cbf)]))
  write.nii.volume(pf$nii.file[i], 1, temp)
  gzip(pf$nii.file[i])
}
if (!dir.exists(dir.save)) { dir.create(dir.save) }
file.copy(list.files(dir.scratch, pattern="gz"), dir.save)

