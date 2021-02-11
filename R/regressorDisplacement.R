args <- commandArgs(trailingOnly = TRUE)

input <- NULL
dir.save <- NULL
spike.thresh <- 0.25
radius <- 50 # Framewise displacement, as per Power, et al. 2012 (radius ~50mm)

for (i in 1:length(args)) {
  if (file.exists(args[i])) { # for some dumb reason this considers directories files
    if (!dir.exists(args[i])) {
      input <- args[i]
    } else {
      dir.save <- args[i]
    }
  } else if (grepl("spike", args[i])) {
    spike.thresh <- as.numeric(unlist(strsplit(args[i], split="="))[2])
  } else if (grepl("rad", args[i])) {
    radius <- as.numeric(unlist(strsplit(args[i], split="="))[2])
  }
}
if (is.null(input)) {
  error("ERROR: [INC regressorDisplacement.R] input 1D file must be provided")
}
if (is.null(dir.save)) {
  dir.save <- dirname(input)
}

library(tools)

# setup file names -------------------------------------------------------------
base.name <- unlist(strsplit(input, split="_"))
base.name <- paste(base.name[1:(length(base.name)-1)], collapse="_")
file.prefix <- paste0(dir.save, "/", basename(base.name))

# load input 1D file -----------------------------------------------------------
df <- read.csv(input, header=FALSE, sep="\t")
if (ncol(df) != 6) {
  error("ERROR [INC regressorDisplacement.R] expecting 6 DOF motion parameters")
}

# Calculate displacement for each vector----------------------------------------
## convert radians to degrees - - - - - - - - - - - - - - - - - - - - - - - - - 
df[ ,1:3] <- (df[ ,1:3] * 180) / pi
# calculate rotational distance specified - - - - - - - - - - - - - - - - - - - 
df[ ,1:3] <- 2 * pi * radius * (df[ ,1:3] / 360)
# write displacement in mm file - - - - - - - - - - - - - - - - - - - - - - - - 
write.table(df, file=paste0(file.prefix, "_AD+mm.1D"),
  quote=F, row.names=F, col.names=F, sep="\t")

# calculate change in displacement between timepoints --------------------------
for (i in 1:ncol(df)) { df[ ,i] <- c(0, diff(df[ ,i])) }
# write relative displacement in mm file - - - - - - - - - - - - - - - - - - - -
write.table(df, file=paste0(file.prefix, "_RD+mm.1D"),
  quote=F, row.names=F, col.names=F, sep="\t")

# get framewise displacement ---------------------------------------------------
FD <- rowSums(abs(df))
write.table(FD, file=paste0(file.prefix, "_FD.1D"),
  quote=F, row.names=F, col.names=F, sep="\t")

# calculate RMS ----------------------------------------------------------------
RMS <- sqrt(c(0,diff(FD))^2)
write.table(RMS, file=paste0(file.prefix, "_RMS.1D"),
  quote=F, row.names=F, col.names=F, sep="\t")

# calculate spikes -------------------------------------------------------------
spike <- (RMS > spike.thresh) * 1
write.table(spike, file=paste0(file.prefix, "_spike.1D"),
  quote=F, row.names=F, col.names=F, sep="\t")
