args <- commandArgs(trailingOnly = TRUE)

library(tools)

input <- args[1]
if (length(args) == 2) {
  dir.save <- args[2]
} else {
  dir.save <- dirname(input)
}

df <- read.csv(input, header=FALSE, sep="\t")

# reorder for AFNI, from "rot1 rot2 rot3 trans1 trans2 trans3" ==> "rot3 rot1 rot2 trans3 trans1 trans2"
df <- df[ ,c(2,3,1,5,6,4)]

# swap direction for AFNI
df[ ,c(1:3,6)] <- df[ ,c(1:3,6)] * -1

# convert to degrees from radians
df[ ,1:3] <- (df[ ,1:3] * 180) / pi

# Convert rotations to mm per Power et. al. 2012 (radius of 50mm)
radius <- 50
df[ ,1:3] <- df[ ,1:3] * radius

# write output
write.table(df, file=paste0(dir.save, "/", basename(file_path_sans_ext(input)), "+mm.1D"), quote=F, row.names=F, col.names=F, sep="\t")
