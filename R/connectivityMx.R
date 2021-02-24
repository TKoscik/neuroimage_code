args <- commandArgs(trailingOnly = TRUE)

show.plot <- FALSE
color.low <- "#af0000"
color.mid <- "#ffffff"
color.high <- "#0000af"
value.low <- -1
value.mid <- 0
value.high <- 1

for (i in 1:length(args)) {
  if (args[i] %in% c("ts")) {
    ts <- args[i+1]
  } else if (args[i] %in% c("show", "show.plot", "plot")) {
    show.plot <- TRUE
  }
}

df <- unlist(read.csv(ts))
cor.mx <- cor(df)
# save correlation matrix

if (show.plot) {
  library(reshape2)
  library(ggplot2)

  plotf <- melt(df)
  ggplot(plotf, aes(x=Var1, y=Var2, fill=value)) +
    theme_void() +
    coord_equal() +
    scale_fill_gradientn(low = color.low,
                         mid = color.mid,
                         high = color.high,
                         midpoint = value.mid,
                         limits = c(value.low, value.high))
    geom_raster()
  #ggsave()
}
