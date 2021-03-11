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
    tf <- read.csv(regressor.ls[1], header=F, sep=delims[iter], as.is=TRUE, stringsAsFactors = FALSE)
    if (ncol(tf) > 1) { delim.chk <- FALSE  }
  }
  nTR <- nrow(tf)
  nVar <- ncol(tf)
  type.1d <- FALSE
  if (i == 1) { df <- data.frame(TR=1:nTR) }
  if (grepl("moco[+]6[.]1D", regressor.ls[i]) || grepl("6df[.]1D", regressor.ls[i])) {
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
      scale_color_manual(values = timbow(5)[c(2,4,5)]) +
      scale_x_continuous(expand=c(0,0)) +
      facet_grid(xfm ~ ., scales="free_y") +
      geom_line(size=1) +
      geom_hline(yintercept = 0, linetype="dotted") +
      labs(title="Rigid Body Motion Correction", y=NULL, x=NULL) +
      theme_obj
    tf <- tf[ ,-ncol(tf)] 
  }
  if (grepl("moco[+]6[+]deriv[.]1D", regressor.ls[i])) {
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
      scale_color_manual(values = timbow(5)[c(2,4,5)]) +
      scale_x_continuous(expand=c(0,0)) +
      facet_grid(xfm ~ ., scales="free_y") +
      geom_line(size=1) +
      geom_hline(yintercept = 0, linetype="dotted") +
      labs(title="Rigid Body Motion Correction - 1st derivative", y=NULL, x=NULL) +
      theme_obj
    tf <- tf[ ,-ncol(tf)] 
  }
  if (grepl("moco[+]6[+]quad[.]1D", regressor.ls[i])) {
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
      scale_color_manual(values = timbow(5)[c(2,4,5)]) +
      scale_x_continuous(expand=c(0,0)) +
      facet_grid(xfm ~ ., scales="free_y") +
      geom_line(size=1) +
      geom_hline(yintercept = 0, linetype="dotted") +
      labs(title="Rigid Body Motion Correction - squared", y=NULL, x=NULL) +
      theme_obj
    tf <- tf[ ,-ncol(tf)] 
  }
  if (grepl("moco[+]6[+]quad[+]deriv[.]1D", regressor.ls[i])) {
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
      scale_color_manual(values = timbow(5)[c(2,4,5)]) +
      scale_x_continuous(expand=c(0,0)) +
      facet_grid(xfm ~ ., scales="free_y") +
      geom_line(size=1) +
      geom_hline(yintercept = 0, linetype="dotted") +
      labs(title="Rigid Body Motion Correction - squared, 1st derivative", y=NULL, x=NULL) +
      theme_obj
    tf <- tf[ ,-ncol(tf)]
  }
  if (grepl("compcorr-anatomy[.]1D", regressor.ls[i])) {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    uf <- tf
    for (j in 1:nVar) { uf[ ,j] <- (uf[ ,j] - mean(uf[ ,j], na.rm=T)) / sd(uf[ ,j], na.rm=T) }
    colnames(uf) <- colnames(tf) <- c("CSF", "WM")
    uf$TR <- 1:nTR
    pf <- melt(uf, id.vars="TR")
    q <- quantile(pf$value, c(0.025, 0.975))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value, color=variable)) +
      theme_minimal() +
      scale_color_manual(values = c("#c82c2c", "#2c2cc8")) +
      scale_x_continuous(expand=c(0,0)) +
      coord_cartesian(ylim=q) +
      geom_line(size=1) +
      geom_hline(yintercept=q, linetype="dashed") +
      annotate("text", label=sprintf("IQR 2.5%% = %0.2f", q[1]),
               x=Inf, y=q[1]+2, vjust=0, hjust=1, size=3) +
      annotate("text", label=sprintf("IQR 97.5%% = %0.2f", q[2]),
               x=Inf, y=q[2]-2, vjust=1, hjust=1, size=3) +
      labs(title="CompCorr - Anatomical - scaled", y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right")
  }
  if (grepl("compcorr-temporal[.]1D", regressor.ls[i])) {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    uf <- tf
    for (j in 1:nVar) { uf[ ,j] <- (uf[ ,j] - mean(uf[ ,j], na.rm=T)) / sd(uf[ ,j], na.rm=T) }
    colnames(uf) <- colnames(tf) <- paste("Comp", 1:nVar)
    uf$TR <- 1:nTR
    pf <- melt(uf, id.vars="TR")
    pf$group <- factor(unlist(strsplit(as.character(pf$variable), split=":")))
    q <- quantile(pf$value, c(0.025, 0.975))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value, color=group)) +
      theme_minimal() +
      scale_color_manual(values = timbow(nVar)) +
      scale_x_continuous(expand=c(0,0)) +
      coord_cartesian(ylim=q) +
      geom_line(size=1) +
      geom_hline(yintercept=q, linetype="dashed") +
      annotate("text", label=sprintf("IQR 2.5%% = %0.2f", q[1]),
               x=Inf, y=q[1]*0.95, vjust=0, hjust=1, size=3) +
      annotate("text", label=sprintf("IQR 97.5%% = %0.2f", q[2]),
               x=Inf, y=q[2]*0.95, vjust=1, hjust=1, size=3) +
      labs(title="CompCorr - Temporal - scaled", y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right")
  }
  if (grepl("global-anatomy[.]1D", regressor.ls[i])) {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    pf <- data.frame(TR=1:nTR,
                     value = scale(as.numeric(unlist(tf[,1]))))
    q <- quantile(pf$value, c(0.025, 0.975))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value)) +
      theme_minimal() +
      scale_x_continuous(expand=c(0,0)) +
      coord_cartesian(ylim=q) +
      geom_line(size=1) +
      geom_hline(yintercept=q, linetype="dashed") +
      annotate("text", label=sprintf("IQR 2.5%% = %0.2f", q[1]),
               x=Inf, y=q[1]*0.95, vjust=0, hjust=1, size=3) +
      annotate("text", label=sprintf("IQR 97.5%% = %0.2f", q[2]),
               x=Inf, y=q[2]*0.95, vjust=1, hjust=1, size=3) +
      labs(title="Global Anatomical - scaled", y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right")
  }
  if (grepl("global-temporal[.]1D", regressor.ls[i])) {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    pf <- data.frame(TR=1:nTR,
                     value = scale(as.numeric(unlist(tf[,1]))))
    q <- quantile(pf$value, c(0.025, 0.975))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value)) +
      theme_minimal() +
      scale_x_continuous(expand=c(0,0)) +
      coord_cartesian(ylim=q) +
      geom_line(size=1) +
      geom_hline(yintercept=q, linetype="dashed") +
      annotate("text", label=sprintf("IQR 2.5%% = %0.2f", q[1]),
               x=Inf, y=q[1]+2, vjust=0, hjust=1, size=3) +
      annotate("text", label=sprintf("IQR 97.5%% = %0.2f", q[2]),
               x=Inf, y=q[2]-2, vjust=1, hjust=1, size=3) +
      labs(title="Global Temporal - scaled", y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right")
  }
  if (grepl("AD[+]mm[.]1D", regressor.ls[i])) {
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
      scale_color_manual(values = timbow(5)[c(2,4,5)]) +
      scale_x_continuous(expand=c(0,0)) +
      facet_grid(xfm ~ ., scales="free_y") +
      geom_line(size=1) +
      geom_hline(yintercept = 0, linetype="dotted") +
      labs(title="Absolute Displacement (mm)", y=NULL, x=NULL) +
      theme_obj
    tf <- tf[ ,-ncol(tf)]
  }
  if (grepl("RD[+]mm[.]1D", regressor.ls[i])) {
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
      scale_color_manual(values = timbow(5)[c(2,4,5)]) +
      scale_x_continuous(expand=c(0,0)) +
      facet_grid(xfm ~ ., scales="free_y") +
      geom_line(size=1) +
      geom_hline(yintercept = 0, linetype="dotted") +
      labs(title="Relative Displacement (mm)", y=NULL, x=NULL) +
      theme_obj
    tf <- tf[ ,-ncol(tf)]
  }
  if (grepl("FD[.]1D", regressor.ls[i])) {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    pf <- data.frame(TR=1:nTR, value = as.numeric(unlist(tf[,1])))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value)) +
      theme_minimal() +
      scale_x_continuous(expand=c(0,0)) +
      geom_line(size=1) +
      labs(title="Framewise Displacement", y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right")
  }
  if (grepl("RMS[.]1D", regressor.ls[i])) {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    pf <- data.frame(TR=1:nTR, value = as.numeric(unlist(tf[,1])))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value)) +
      theme_minimal() +
      scale_x_continuous(expand=c(0,0)) +
      geom_line(size=1) +
      labs(title="RMS", y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right")
  }
  if (grepl("spike[.]1D", regressor.ls[i])) {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    pf <- data.frame(TR=1:nTR, value = as.numeric(unlist(tf[,1])))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value)) +
      theme_minimal() +
      scale_x_continuous(expand=c(0,0)) +
      geom_line(size=1) +
      labs(title="Spike", y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right")
  }
  if (grepl("moco[+]12[.]1D", regressor.ls[i])) {
    type.1d <- TRUE
    plot.count <- c(plot.count, 1)
    uf <- tf
    for (j in 1:nVar) { uf[ ,j] <- scale(uf[ ,j]) }
    pf <- data.frame(TR=rep(1:nTR,nVar),
                     group = c(sort(rep(paste("Affine", 1:nVar), nTR))),
                     value = as.numeric(unlist(uf)))
    pf$group <- factor(pf$group, levels=paste("Affine", 1:nVar))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value, color=group)) +
      theme_minimal() +
      scale_color_manual(values = timbow(nVar)) +
      guides(color=guide_legend(ncol=3)) +
      scale_x_continuous(expand=c(0,0)) +
      geom_line(size=1) +
      geom_hline(yintercept=0, linetype="dashed") +
      labs(title="Affine Motion Correction", subtitle="(scaled)", y=NULL, x=NULL) +
      theme_obj + theme(legend.position="right", legend.spacing = unit(0,"lines"))
  }
  if (grepl("PrePost[.]1D", regressor.ls[i])) {
    plot.count <- c(plot.count, 1)
    type.1d <- TRUE
    colnames(tf) <- c("PreMOCO", "PostMOCO")
    tf$PreMOCO <- scale(tf$PreMOCO)
    tf$PostMOCO <- scale(tf$PostMOCO)
    tf$TR <- 1:nTR
    pf <- melt(tf, id.vars="TR")
    pf$variable <- factor(pf$variable, levels=c("PreMOCO", "PostMOCO"))
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value, color=variable)) +
      theme_minimal() +
      scale_color_manual(values = c("#cf00cf", "#00cf00")) +
      scale_x_continuous(expand=c(0,0)) +
      geom_line(size=1) +
      labs(title="Pre- and Post-Motion Correction", subtitle="(scaled)", y=NULL, x=NULL) +
      theme_obj
    tf <- tf[ ,-ncol(tf)]
  }
  if (type.1d == FALSE) {
    plot.count <- c(plot.count, 1)
    pf <- data.frame(TR=rep(1:nTR,nVar),
                     group = c(sort(rep(paste("Regressor", 1:nVar), nTR))),
                     value = as.numeric(unlist(tf)))
    pf$group <- factor(pf$group)
    plots[[i]] <- ggplot(pf, aes(x=TR, y=value, color=group)) +
      theme_minimal() +
      scale_color_manual(values = timbow(nVar)) +
      scale_x_continuous(expand=c(0,0)) +
      geom_line(size=1) +
      labs(title="Affine Motion Correction", y=NULL, x=NULL) +
      theme_obj + theme(legend.position="none")
  }
  df <- cbind(df,tf)
}

plot_fcn <- "rgr_plot <- arrangeGrob("
for (i in 1:length(regressor.ls)) {
  plot_fcn <- paste0(plot_fcn, "plots[[", i, "]], ")
}
plot_fcn=paste0(plot_fcn, 'ncol=1, heights=c(', paste(plot.count, collapse=","), '), top="Nuisance Regressors")')
eval(parse(text=plot_fcn))

ggsave(filename = paste0(prefix, "_regressors", suffix, ".png"),
       path = dir.save,
       plot = rgr_plot,
       device = "png",
       width = 7.5,
       height=sum(plot.count),
       dpi=320)

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
  ggsave(filename = paste0(prefix, "_regressorsCorr", suffix, ".png"),
         path = dir.save,
         plot = plot.corr,
         device = "png",
         width = 3.5, height = 3.5, dpi=320)
}


