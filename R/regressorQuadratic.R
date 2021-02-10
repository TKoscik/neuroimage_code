args <- commandArgs(trailingOnly = TRUE)

library(tools)

df <- read.csv(args[1], header=F)
df <- apply(df, 2, function(x) x^2)
write.table(df, filename=paste0(args[2], basename(file_path_sans_ext(args[1])), "+quad.1D"), quotes=F, row.names=F, col.names=F, sep=" ")
