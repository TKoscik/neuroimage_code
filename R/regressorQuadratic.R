args <- commandArgs(trailingOnly = TRUE)

library(tools)

delims <- c("\t",",",";"," ","")
delim.chk <- TRUE
iter <- 0
while (delim.chk) {
  iter <- iter + 1
  df <- read.csv(args[1], header=F, sep=delims[iter], as.is=TRUE)
  if (ncol(df) > 1) { delim.chk <- FALSE }
  if (iter == length(delims)) { delim.chk <- FALSE }
}

df <- apply(df, 2, function(x) x^2)
write.table(df,
  file=paste0(args[2], "/", basename(file_path_sans_ext(args[1])), "+quad.1D"),
  quote=F, row.names=F, col.names=F, sep="\t")


