args <- commandArgs(trailingOnly = TRUE)

for (i in 1:length(args)) {
  if (args[i] %in% c("ts")) {
    ts <- args[i+1]
  } else if (args[i] %in% c("show", "show.plot", "plot")) {
    show.plot <- TRUE
  }
}
