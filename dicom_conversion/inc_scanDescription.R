args <- commandArgs(trailingOnly = TRUE)

nii.file <- args[1]
json.file <- args[2]
dcm.dump <- args[3]
## Debug ----
# nii.file <- c("/Shared/inc_scratch/scratch_2019-10-30T11.42.11-0500/nifti/sub-HD019_ses-64mlm01se_site-1+1+1_acq-3DASL+0_asl.nii")
# json.file <- c("/Shared/inc_scratch/scratch_2019-10-30T11.42.11-0500/nifti/sub-HD019_ses-64mlm01se_site-1+1+1_acq-3DASL+0_asl.json")
# dcm.dump <- c("/Shared/inc_scratch/scratch_2019-10-30T11.42.11-0500/nifti/sub-HD019_ses-64mlm01se_site-1+1+1_acq-3DASL+0_asl_dcmdump.txt")
# ----

library(tools)
library(jsonlite)
library(nifti.io)

jsonf <- read_json(json.file)
dcmf <- readLines(dcm.dump)
fname <- file_path_sans_ext(basename(nii.file))
mod <- unlist(strsplit(unlist(strsplit(nii.file, "[.]"))[1], "_"))
mod <- mod[length(mod)]

tesla <- manufacturer <- model <- rec.coil <- scan.seq <- acq.plane <- NULL
scan.matrix <- fov <- vxl.size <- slice.spacing <- slice.order <- TR <- NULL
num.volumes <- TE <- TI <- flip.angle <- bandwidth <- NULL
phase.encode.direction <- b.vals <- num.b <- acq <- NULL

json.names <- names(jsonf)
if ("MagneticFieldStrength" %in% json.names) {
  tesla <- paste0(jsonf$MagneticFieldStrength, "T")
}
if ("Manufacturer" %in% json.names) {
  manufacturer <- jsonf$Manufacturer
}
if ("ManufacturersModelName" %in% json.names) {
  model <- gsub("_", " ", jsonf$ManufacturersModelName)
}
rec.coil <- trimws(tolower(gsub("Ch", " channel",unlist(strsplit(unlist(strsplit(
  dcmf[which(grepl("Receive Coil Name",dcmf))],"]"))[1],"[[]"))[2])),"right")
if ("ScanningSequence" %in% json.names) {
  tmp <- unlist(strsplit(jsonf$ScanningSequence, "_"))
  for (j in 1:length(tmp)) {
    tmp[j] <- switch(tmp[j],
                     `RM`="recovery magnitude", `EP`="echo planar", `GR`="gradient echo",
                     `SE`="spin echo", `IR`="inversion recovery", otherwise="UNKNOWN")
  }
  scan.seq <- paste(tmp, collapse=" ")
}
if ("ImageOrientationPatientDICOM" %in% json.names) {
  acq.plane <- as.numeric(jsonf$ImageOrientationPatientDICOM)
  acq.plane <- as.integer(acq.plane*acq.plane + 0.5)
  if (acq.plane[1]==1 && acq.plane[6]==1) {
    acq.plane <- "coronal"
  } else if (acq.plane[1]==1 && acq.plane[5]==1) {
    acq.plane <- "axial"
  } else if (acq.plane[2]==1 && acq.plane[6]==1) {
    acq.plane <- "sagittal"
  }
}
scan.matrix <- nii.dims(nii.file)[1:3]
vxl.size <- unlist(nii.hdr(nii.file, "pixdim"))[2:4]
fov <- as.numeric(unlist(strsplit(unlist(strsplit(dcmf[which(grepl("Acquisition Matrix",dcmf))]," "))[3],"[\\]")))[1:3] * vxl.size
fov <- unname(fov[fov != 0])
if ("SpacingBetweenSlices" %in% json.names) {
  slice.spacing <- jsonf$SpacingBetweenSlices
}
if (mod %in% c("bold")) {
  slice.order <- "UNKNOWN"
  num.volumes <- nii.dims(nii.file)[4]
  if ("PhaseEncodingAxis" %in% json.names) {
    phase.encode.direction <- switch(jsonf$PhaseEncodingAxis, `j`="AP", `-j`="PA", otherwise="UNKNOWN")
  }
} else {
  slice.order <- NULL
  num.volumes <- NULL
  phase.encode.direction <- NULL
}

if ("RepetitionTime" %in% json.names) {TR <- jsonf$RepetitionTime * 1000}
if ("EchoTime" %in% json.names) {TE <- jsonf$EchoTime * 1000}
if ("InversionTime" %in% json.names) {TI <- jsonf$InversionTime * 1000}
if ("FlipAngle" %in% json.names) {flip.angle <- jsonf$FlipAngle}
if ("PixelBandwidth" %in% json.names) {bandwidth <- jsonf$PixelBandwidth}

if (mod == "dwi") {
  tmp <- unlist(strsplit(unlist(strsplit(nii.file, "acq-"))[2], "_"))[1]
  b.vals <- unlist(strsplit(tmp, "v"))[1]
  b.vals <- unlist(strsplit(substr(b.vals, 2, nchar(b.vals)), "[+]"))
  num.b <- unlist(strsplit(tmp, "v"))[2]
  num.b <- unlist(strsplit(num.b, "[+]"))
  if ("PhaseEncodingAxis" %in% json.names) {
    phase.encode.direction <- switch(jsonf$PhaseEncodingAxis,
                                     `j`="AP", `-j`="PA", otherwise="UNKNOWN")
  }
} else {
  b.vals <- NULL
  num.b <- NULL
}

if (mod != "dwi" & grepl(pattern = "acq", nii.file)) {
  acq <- unlist(strsplit(unlist(strsplit(nii.file, "acq-"))[2], "_"))[1]
  acq <- gsub("sag", "", acq)
  acq <- gsub("cor", "", acq)
  acq <- gsub("axi", "", acq)
  acq <- switch(acq,
                `MPRAGEPROMO`="An MPRAGE sequence with prospective motion correction (PROMO) was used.",
                `MPRAGE`="An MPRAGE sequence was used.",
                `MPRAGEPROMO`="A CUBE sequence with prospective motion correction (PROMO) was used.",
                `CUBE`="A CUBE sequence was used.", 
                otherwise=NULL)
}

output <- 
  sprintf("This %s scan was acquired on a %s %s scanner (%s) using a %s coil and a %s sequence in the %s plane with the following parameters: ", 
          mod, tesla, manufacturer, model, rec.coil, scan.seq, acq.plane)
if (!is.null(scan.matrix)) { output <- paste0(output, sprintf("matrix = %d x %d x %d, ", scan.matrix[1], scan.matrix[2], scan.matrix[3])) }
if (!is.null(fov)) { output <- paste0(output, sprintf("FOV = %g x %g mm, ", fov[1], fov[2])) }
if (!is.null(vxl.size)) { output <- paste0(output, sprintf("voxel size = %g x %g x %g mm, ", vxl.size[1], vxl.size[3], vxl.size[3])) }
if (!is.null(slice.spacing)) { output <- paste0(output, sprintf("slice spacing = %g mm, ", slice.spacing)) }
if (!is.null(slice.order)) { output <- paste0(output, sprintf("slice.order = %s, ", slice.order)) }
if (!is.null(TR)) { output <- paste0(output, sprintf("TR = %g ms, ", TR)) }
if (!is.null(num.volumes)) { output <- paste0(output, sprintf("number of volumes = %d, ", num.volumes)) }
if (!is.null(TE)) { output <- paste0(output, sprintf("TE = %g ms, ", TE)) }
if (!is.null(TI)) { output <- paste0(output, sprintf("TI = %g ms, ", TI)) }
if (!is.null(flip.angle)) { output <- paste0(output, sprintf("flip angle = %g degrees, ", flip.angle)) }
if (!is.null(bandwidth)) { output <- paste0(output, sprintf("bandwidth = %g Hz, ", bandwidth)) }
if (!is.null(phase.encode.direction)) { output <- paste0(output, sprintf("phase encoding direction = %s, ", phase.encode.direction)) }
if (!is.null(b.vals)) { output <- paste0(output, "B values = ", paste(b.vals, collapse=", "), ", ") }
if (!is.null(num.b)) { output <- paste0(output, "number of directions = ", paste(num.b, collapse=", "), ", ") }
output <- paste0(substr(output, 1, nchar(output)-2), ". ")
if (!is.null(acq)) { output <- paste0(output, acq) }

print(output)
