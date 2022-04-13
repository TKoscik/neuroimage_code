args <- commandArgs(trailingOnly=TRUE)

PID_VAR <- "participant_id"
SID_VAR <- NA
VAR_FACTOR <- NA
OUT_COEF <- TRUE
OUT_AOV <- FALSE
OUT_DIFFLSMEANS <- FALSE
FDR_N <- as.numeric(NA)
CI <- 95
RESTART_LOG <- TRUE
RAND_ORDER <- TRUE
VERBOSE <- FALSE

for (i in seq(1, length(args), 2)) {
  if (args[i] %in% c("nii", "nii_data", "nii.data")) { NII_DATA <- args[i+1] }
  if (args[i] %in% c("df", "df_data", "df.data")) { DF_DATA <- args[i+1] }
  if (args[i] %in% c("pid", "participant", "participant_var")) { PID_VAR <- args[i+1] }
  if (args[i] %in% c("sid", "session", "session_var")) { SID_VAR <- args[i+1] }
  if (args[i] %in% c("factor", "var_factors")) { VAR_FACTOR <- args[i+1] }
  if (args[i] %in% c("form", "FORM", "formula", "FORMULA")) { FORM <- args[i+1] }
  if (args[i] %in% c("func", "FUNC", "function", "FUNCTION")) { FUNC <- args[i+1] }
  if (args[i] %in% c("mask", "roi", "roi_nii", "mask_nii", "roi.nii", "mask.nii")) { ROI_NII <- args[i+1] }
  if (args[i] %in% c("coef", "do_coef", "coef_table", "do_coef_table")) { OUT_COEF <- as.logical(args[i+1]) }
  if (args[i] %in% c("aov", "do_aov", "aov_table", "do_aov_table")) { OUT_AOV <- as.logical(args[i+1]) }
  if (args[i] %in% c("difflsmeans", "diffmeans")) { OUT_DIFFLSMEANS <- as.logical(args[i+1]) }
  if (args[i] %in% c("fdr", "fdr_n", "fdr.n")) { FDR_N <- as.numeric(args[i+1]) }
  if (args[i] %in% c("ci", "confidence", "confidence_interval")) { CI <- as.numeric(args[i+1]) }
  if (args[i] %in% c("dirsave", "dir_save", "dir.save", "savedir", "save_dir", "save.dir")) { DIR_SAVE <- args[i+1] }
  if (args[i] %in% c("prefix", "model", "modelname", "model_name", "model.name")) { MODEL_PFX <- args[i+1] }
  if (args[i] %in% c("log", "restartlog", "restart_log", "restart.log")) { RESTART_LOG <- args[i+1] }
  if (args[i] %in% c("rand", "rand_order", "randomize", "randomize_order")) { RAND_ORDER <- args[i+1] }
  if (args[i] %in% c("ncores", "n_cores", "n.cores", "numcores", "num_cores", "num.cores")) { NUM_CORES <- as.numeric(args[i+1]) }
  if (args[i] %in% c("verbose")) { VERBOSE <- as.logical(args[i+1]) }
}

#### SHOULD NOT NEED TO EDIT BELOW THIS POINT ##################################

# load required libraries ------------------------------------------------------
library(doParallel)
library(lmerTest)
library(car)
library(nifti.io)

# set output directories -------------------------------------------------------
dir.save <- sprintf("%s/%s", DIR_SAVE, MODEL_PFX)
dir.create(dir.save, showWarnings = FALSE, recursive=TRUE)

# load data frame for analysis -------------------------------------------------
pf <- read.csv(DF_DATA)

## make sure IDs are factors, and set the order of groups if not alphabetical
pf[ , PID_VAR] <- as.factor(pf[ , PID_VAR])
if (!is.na(SID_VAR)) { pf[ , SID_VAR] <- as.factor(pf[ , SID_VAR]) }

if (!is.na(VAR_FACTOR)) {
  factor_ls <- unlist(strsplit(VAR_FACTOR, split=";"))
  for (i in 1:length(factor_ls)) {
    factor_name <- unlist(strsplit(factor_ls[i], split=":"))[1]
    if (length(factor_name) == 1) {
      pf[ , factor_name] <- as.factor(pf[ , factor_name])
    } else if (length(factor_name) == 2) {
      tlevels <- eval(parse(text=sprintf("c(%s)", factor_name[2])))
      pf[ , factor_name[1]] <- as.factor(pf[ , factor_name[1]], levels=tlevels)
    }
  }
}

# match subjects to data -------------------------------------------------------
pf$fls <- character(nrow(pf))
for (i in 1:nrow(pf)) {
  pidstr <- paste0("sub-", pf[i, PID_VAR])
  if (!is.na(SID_VAR)) { pidstr <- paste0(pidstr, "_ses-", pf[i, SID_VAR]) }
  tname <- list.files(NII_DATA, pattern=pidstr, full.names=TRUE)
  is.nii <- rep(FALSE,length(tname))
  for (j in 1:length(tname)) {
    fext <- unlist(strsplit(tname[j], split="[.]"))
    if (fext[length(fext)] == "nii") { is.nii[j] <- TRUE }
  }
  tname <- tname[is.nii]
  if (length(tname) != 0) { pf$fls[i] <- tname[1] }
}
## remove rows without matched file
pf <- pf[pf$fls != "", ]
## check if pf is empty
if (nrow(pf) == 0) { stop("Dataset is empty, please check inputs") }

# load mask -------------------------------------------------------------------
## masks have to be unzipped to load into R
mask <- read.nii.volume(ROI_NII,1)
mask <- (mask != 0) * 1
vxl.ls <- which(mask!=0, arr.ind=TRUE)

# gather nifti file info -------------------------------------------------------
img.dims <- info.nii(ROI_NII, "dims")
pixdim <- info.nii(ROI_NII, "pixdim")
orient <- info.nii(ROI_NII, "orient")

# initialize log file if it doesn't exist --------------------------------------
log.nii <- paste0(dir.save, "/log.nii")
if (file.exists(log.nii) == FALSE || RESTART_LOG == TRUE) {
  init.nii(log.nii, dims=img.dims, pixdim=pixdim, orient=orient, init.value=0)
  write.nii.volume(log.nii, vol.num=1, value=mask)
} else {
  log <- read.nii.volume(log.nii,1)
  vxls.not_run <- (log == 1) * 1
  vxl.ls <- which(vxls.not_run==1, arr.ind=TRUE)
}

# set voxel looping poarameters ------------------------------------------------
n.vxls <- nrow(vxl.ls)
## randomize order ---
if (RAND_ORDER) { vxl.ls <- vxl.ls[sample(1:n.vxls, n.vxls, replace=F), ] }
## check if there are no voxels
if (n.vxls == 0) { stop("There are no voxels in the specified ROI to run") }

# specify model function -------------------------------------------------------
model.fxn <- function(X, ...) {
  ## load VOXELWISE DATA - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  coords <- vxl.ls[X, ]
  df <- pf
  df$nii <- numeric(nrow(df))
  for (i in 1:nrow(df)) { df$nii[i] <- read.nii.voxel(df$fls[i], coords) }
  
  ## select appropriate model function - - - - - - - - - - - - - - - - - - - - -
  if (FUNC == "lm") {
    mdl <- lm(FORM, df)
  } else if (FUNC == "lmer") {
    mdl <- lmer(FORM, df)
  }  else if (FUNC == "glmer") {
    mdl <- glmer(FORM, df)
  }

  ## output Coefficient table - - - - - - - - - - - - - - - - - - - - - - - - -
  if (OUT_COEF) {
    coef <- as.data.frame(summary(mdl)$coef)
    ### FDR correction
    if (!is.na(FDR_N)) {
      coef$pFDR <- p.adjust(coef[ ,pmatch("P", colnames(coef))], method="BY", n=as.numeric(FDR_N))
    }
    ### Confidence Interval
    if (~is.na(CI) && CI != FALSE) {
      out.ci <- confint(mdl, method="Wald", level=as.numeric(CI)/100)
      coef <- cbind(coef, na.omit(out.ci))
    }
    table.to.nii(in.table = coef, coords=coords, save.dir=dir.save,
                 do.log=TRUE, model.string=FORM,
                 img.dims=img.dims, pixdim=pixdim, orient=orient)
  }

  ## output ANOVA table - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  if (OUT_AOV) {
    aov <- Anova(mdl, type=3L, test.statistic="F")
    ### FDR correction
    if (!is.na(FDR_N)) {
      aov$pFDR <- p.adjust(aov[ ,pmatch("P", colnames(aov))], method="BY", n=FDR_N)
    }
    table.to.nii(in.table = aov, coords=coords, save.dir=dir.save,
                 do.log=TRUE, model.string=FORM,
                 img.dims=img.dims, pixdim=pixdim, orient=orient)
  }

  ## output DIFFLSMEANS table - - - - - - - - - - - - - - - - - - - - - - - - -
  if (OUT_DIFFLSMEANS) {
    dlsmeans <- difflsmeans(mdl)
    ### FDR correction
    if (!is.na(FDR_N)) {
      dlsmeans$pFDR <- p.adjust(dlsmeans[ ,pmatch("P", colnames(dlsmeans))], method="BY", n=FDR_N)
    }
    table.to.nii(in.table = dlsmeans, coords=coords, save.dir=dir.save,
                 do.log=TRUE, model.string=FORM,
                 img.dims=img.dims, pixdim=pixdim, orient=orient)
  }

  if (VERBOSE) {
    print(sprintf("(%d, %d, %d) DONE, %d remaining", coords[1], coords[2], coords[3], n.vxls - X))
  }

  write.nii.voxel(log.nii, coords, 2)
}

# Run voxels in parallel
print("starting voxelwise models...")
registerDoParallel(NUM_CORES)
invisible(foreach(X=1:n.vxls) %dopar% model.fxn(X))
stopImplicitCluster() # Stop parallelization

