args <- commandArgs(trailingOnly = TRUE)

library(tools)

input <- args[1]
dir.save <- args[2]
spike.thresh <- args[3]

base.name <- unlist(strsplit(input, split="_"))
base.name <- paste(base.name[1:(length(base.name)-1)], collapse="_")

df <- read.csv(input, header=FALSE, sep="\t")

# absolute displacement
tf <- df
tf[ ,1:3] <- 0.2*80^2 * ((cos(tf[ ,1:3]) - 1)^2 + (sin(tf[ ,1:3]))^2)
tf[ ,4:6] <- tf[ ,4:6]^2
abs.disp <- sqrt(rowSums(tf))
# write output
write.table(abs.disp,
  file=paste0(dir.save, "/", basename(base.name), "_FD+abs.1D"),
  quote=F, row.names=F, col.names=F, sep="\t")

# relative displacement
tf <- df
for (i in 1:ncol(tf)) {
  tf[,i] <- c(0, diff(tf[,1]))
}
tf[ ,1:3] <- 0.2*80^2 * ((cos(tf[ ,1:3]) - 1)^2 + (sin(tf[ ,1:3]))^2)
tf[ ,4:6] <- tf[ ,4:6]^2
rel.disp <- sqrt(rowSums(tf))
# write output
write.table(rel.disp,
  file=paste0(dir.save, "/", basename(base.name), "_FD+rel.1D"),
  quotes=F, row.names=F, col.names=F, sep="\t")

# root mean square of cumulative displacement
rms.disp <- cumsum(sqrt(rel.disp)^2)
# write output
write.table(cum.disp,
  file=paste0(dir.save, "/", basename(base.name), "_FD+rms.1D"),
  quotes=F, row.names=F, col.names=F, sep="\t")

# spike
spikes <- (cum.disp > spike.thresh) * 1
# write output
write.table(spikes,
  file=paste0(dir.save, "/", basename(base.name), "_spike.1D"),
  quotes=F, row.names=F, col.names=F, sep="\t")
