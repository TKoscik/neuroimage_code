args <- commandArgs(trailingOnly = TRUE)
for (i in 1:length(args)) {
  if (args[i] == "regressor") {
    regressor.ls <- unlist(strsplit(args[i+1], split=","))
  } else if (args[i] == "dir-save") {
    dir.save <- args[i+1]
  } else if (args[i] == "docorr") {
    do.corr <- as.logical(args[i+1])
  }
}

library(tools)
library(ggplot2)
library(viridis)
library(reshape2)
library(gridExtra)

timbow <- colorRampPalette(c("#440154FF", "#482878FF", "#3E4A89FF", "#31688EFF",
  "#26828EFF", "#1F9E89FF", "#35B779FF", "#6DCD59FF", "#B4DE2CFF", "#FDE725FF",
  "#F8E125FF", "#FDC926FF", "#FDB32FFF", "#FA9E3BFF", "#F58B47FF", "#ED7953FF",
  "#E3685FFF", "#D8576BFF", "#CC4678FF"))

theme_obj <- theme(legend.title = element_blank(),
                   legend.text = element_text(size=8, margin=margin(0,0,0,0)),
                   legend.position = c(1.05, 0.5),
                   legend.spacing.y = unit(0, "cm"),
                   legend.key.height = unit(0,"lines"),
                   strip.text.y = element_text(angle=0, size=10),
                   strip.placement = "inside",
                   axis.line.y = element_line(),
                   axis.text.y = element_text(size=8),
                   axis.text.x = element_blank(),
                   plot.title = element_text(size=10),
                   plot.subtitle = element_text(size=10),
                   plot.title.position = "plot")

# make filename
prefix <- unlist(strsplit(basename(regressor.ls[1]), split="_"))
prefix <- paste(prefix[1:(length(prefix)-1)], collapse="_")
prefix <- paste0(prefix)
if (file.exists(paste0(dir.save, "/", prefix, "_regressors.png"))) {
  list.files(dir.save, pattern=paste0(prefix, "_regressors"))
  suffix <- paste0("_", length(list.files)+1)
} else {
  suffix <- ""
}

plots <- list()
plot.count <- numeric()
for (i in 1:length(regressor.ls)) {
  delims <- c("\t",",",";"," ","")
  delim.chk <- TRUE
  iter <- 0
  while (delim.chk) {
    iter <- iter + 1
    tf <- read.csv(regressor.ls[i], header=F, sep=delims[iter], as.is=TRUE, stringsAsFactors = FALSE)
    if (ncol(tf) > 1) { delim.chk <- FALSE  }
  }
  nTR <- nrow(tf)
  nVar <- ncol(tf)
  type.1d <- FALSE
  
  cor.include <- TRUE
  if (grepl("moco[+]6", regressor.ls[i]) || grepl("6df", regressor.ls[i])) {
    ptitle <- "Rigid Motion Correction"
    which.plot <- "plot6df"
    cls <- timbow(5)[c(2,4,5)]
  } else if (grepl("moco[+]12", regressor.ls[i]) || grepl("12df", regressor.ls[i])) {
    ptitle <- "Affine Motion Correction"
    which.plot <- "plotMx"
    cnames <- paste("Affine", 1:nVar)
    cls <- timbow(nVar)
  } else if (grepl("tissueMeans", regressor.ls[i])) {
    ptitle <- "Tissue Mean Signal (Z)"
    which.plot <- "plotMx"
    cnames <- c("CSF", "WM")
    cls <- c("#c82c2c", "#2c2cc8")
  } else if (grepl("compcorr[+]csf", regressor.ls[i])) {
    ptitle <- "CompCorr - CSF (Z)"
    which.plot <- "plotMx"
    cnames <- paste("CSF", 1:nVar)
    cls <- timbow(nVar)
  } else if (grepl("compcorr[+]wm", regressor.ls[i])) {
    ptitle <- "CompCorr - WM (Z)"
    which.plot <- "plotMx"
    cnames <- paste("WM", 1:nVar)
    cls <- timbow(nVar)
  } else if (grepl("compcorr[+]temporal", regressor.ls[i])) {
    ptitle <- "CompCorr - Temporal (Z)"
    which.plot <- "plotMx"
    cnames <- paste("Temporal", 1:nVar)
    cls <- timbow(nVar)
  } else if (grepl("global", regressor.ls[i])) {
    ptitle <- "Global Signal (Z)"
    which.plot <- "plotVec"
    cls <- "#000000"
  } else if (grepl("displacement+absolute[+]mm", regressor.ls[i])) {
    ptitle <- "Absolute Displacement (mm)"
    which.plot <- "plot6df"
    cls <- timbow(5)[c(2,4,5)]
  } else if (grepl("displacement+relative[+]mm", regressor.ls[i])) {
    ptitle <- "Relative Displacement (mm)"
    which.plot <- "plot6df"
    cls <- timbow(5)[c(2,4,5)]
  } else if (grepl("displacement+framewise", regressor.ls[i])) {
    ptitle <- "Framewise Displacement"
    which.plot <- "plotVec"    
    cls <- "#000000"
  } else if (grepl("displacement+RMS", regressor.ls[i])) {
    ptitle <- "Displacement Root Mean Squared"
    which.plot <- "plotVec"
    cls <- "#000000"
  } else if (grepl("spike", regressor.ls[i])) {
    ptitle <- "Spike"
    which.plot <- "plotVec"
    cls <- "#000000"
  }  else if (grepl("ts+processing", regressor.ls[i])) {
    ptitle <- "time-series Processing"
    which.plot <- "plotMx"
    cnames <- c("Raw","MOCO","Residual")
    cls <- c("#000000", "#cf00cf","#00cf00")
    corr.include <- FALSE
  } else {
    ptitle <- "Regressor"
    which.plot <- "plot.mx"
    cnames <- paste("Regressor", 1:nVar)
    cls <- timbow(nVar)
  }

  if (grepl("quad[+]deriv", regressor.ls[i])) {
    ptitle <- paste0(ptitle, " - Quadratic, Derivative")
  } else if (grepl("quad", regressor.ls[i])) {
    ptitle <- paste0(ptitle, " - Quadratic")
  } else if (grepl("deriv", regressor.ls[i])) {
    ptitle <- paste0(ptitle, " - Derivative")
  }

  if (which.plot == "plot6df") {
    plot.count <- c(plot.count, 2)
    type.1d <- TRUE
    colnames(tf) <- c("Translation:X", "Translation:Y", "Translation:Z",
                      "Rotation:X", "Rotation:Y", "Rotation:Z")
    tf$TR <- 1:nTR
    pf <- melt(tf, id.vars="TR")
    pf$xfm <- factor(unlist(strsplit(as.character(pf$variable), split=":"))[seq(1,2*nVar*nTR,2)],
                     levels=c("Translation", "Rotation"))
    pf$plane <- factor(unlist(strsplit(as.character(pf$variable), split=":"))[seq(2,2*nVar*nTR,2)],
                       levels=c("X", "Y", "Z"))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value, color=plane)) +
      theme_minimal() +
      scale_color_manual(values = cls) +
      scale_x_continuous(expand=c(0,0)) +
      facet_grid(xfm ~ ., scales="free_y") +
      geom_line(size=1) +
      geom_hline(yintercept = 0, linetype="dotted") +
      labs(title=ptitle, y=NULL, x=NULL) +
      theme_obj
    tf <- tf[ ,-ncol(tf)] 
  }
  if (which.plot == "plotVec") {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    pf <- data.frame(TR=1:nTR, value=scale(as.numeric(unlist(tf[,1]))))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value)) +
      theme_minimal() +
      scale_x_continuous(expand=c(0,0)) +
      geom_line(size=1, color=cls) +
      labs(title=ptitle, y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right")
  }
  if (grepl("plotMx", regressor.ls[i])) {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    uf <- tf
    for (j in 1:nVar) { uf[ ,j] <- (uf[ ,j] - mean(uf[ ,j], na.rm=T)) / sd(uf[ ,j], na.rm=T) }
    colnames(uf) <- colnames(tf) <- cnames
    uf$TR <- 1:nTR
    pf <- melt(uf, id.vars="TR")
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value, color=variable)) +
      theme_minimal() +
      scale_color_manual(values = cls) +
      scale_x_continuous(expand=c(0,0)) +
      geom_line(size=1) +
      labs(title=ptitle, y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right")
  }
  if (i==1) {df <- data.frame(TR=1:nTR) }
  if (corr.include) { df <- cbind(df,tf) }
}

plot_fcn <- "rgr_plot <- arrangeGrob("
for (i in 1:length(regressor.ls)) { plot_fcn <- paste0(plot_fcn, "plots[[", i, "]], ") }
plot_fcn=paste0(plot_fcn, 'ncol=1, heights=c(', paste(plot.count, collapse=","), '), top="Nuisance Regressors")')
eval(parse(text=plot_fcn))

ggsave(filename=paste0(prefix, "_regressors", suffix, ".png"), path=dir.save,
       plot=rgr_plot, device="png", width=7.5, height=sum(plot.count), dpi=320)

if (do.corr) {
  df <- df[ ,-1]
  corMX = melt(cor(df))
  corMX$Var2 <- factor(corMX$Var2, levels=rev(levels(corMX$Var2)))
  plot.corr <- ggplot(data=corMX, aes(x=Var1, y=Var2, fill=value)) +
    theme_void() +
    scale_fill_gradient2(midpoint = 0, limit=c(-1,1)) +
    coord_equal() +
    geom_raster() + 
    labs(title="Nuisance Regressor - Correlations") +
    theme(legend.title = element_blank(),
          legend.text = element_text(size=8),
          plot.title = element_text(size=10))
  ggsave(filename=paste0(prefix, "_regressorsCorr", suffix, ".png"), path=dir.save,
         plot=plot.corr, device="png", width=4, height=4, dpi=320)
}


