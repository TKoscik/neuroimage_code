args <- commandArgs(trailingOnly = TRUE)

library(tools)

df <- read.csv(args[1], header=F)
for (i in 1:ncol(df)) { df[ ,i] <- c(0, diff(df[ ,i])) }
write.table(df, file=paste0(args[2], basename(file_path_sans_ext(args[1])), "+deriv.1D"), quote=F, row.names=F, col.names=F, sep=" ")
