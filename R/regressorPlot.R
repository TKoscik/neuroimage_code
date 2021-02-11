args <- commandArgs(trailingOnly = TRUE)

library(tools)

regressor.ls <- unlist(strsplit(args[i], split=","))

if (length(args) == 2)
  dir.save <- args[2]
} else {
  dir.save <- dirname(regressor.ls[1])
}
if (length(args) == 3) {
  do.corr <- args[3]
} else {
  do.corr <- FALSE
}

# load regressor files and append to dataframe
for (i in 1:length(regressor.ls)) {
  
}
df <- read.csv(regressor.ls[1], header=FALSE, sep="/t")
