args <- commandArgs(trailingOnly = TRUE)

# example call:
#Rscript ${INC_R}/connectivity.R \
#  "ts" "full/file/name/for/time-series.csv" \
#  "long" "pearson" "mutual-information" "euclidean" "manahattan" \
#  "dirsave" "directory to save output" 

# load libraries ---------------------------------------------------------------
suppressMessages(suppressWarnings(library(reshape2)))
suppressMessages(suppressWarnings(library(tools)))

# default values ---------------------------------------------------------------
ts <- NULL
lut <- NULL
lut.col <- "label"
df.type <- "long"
do.plot <- TRUE
cat.with <- NULL
dir.save <- NULL
var.ls <- character()

# debug
#args <- c("ts",
#          "C:/Users/MBBHResearch/Desktop/sub-105_ses-20190726_task-rest_run-1_dir-fwd_ts-HCPICBM+2mm+WBCXN.csv",
#          "long",
#          "plot_colors", "#0000af,#ffffff,#af0000",
#          "plot_limits", "-1,0,1",
#          "dir_save", "C:/Users/MBBHResearch/Desktop",
#          "corr", "ccf", "coh", "wavelet", "mi", "dist", "city", "dtw", "earth")

# parse arguments --------------------------------------------------------------
for (i in 1:length(args)) {
  if (args[i] %in% c("ts", "timeseries", "time-series")) { ts <- args[i+1] }
  if (args[i] %in% c("corr", "cor", "pearson")) { var.ls <- c(var.ls, "pearsonCorrelation") }
  if (args[i] %in% c("xcorr", "cross", "ccf", "cross-correlation", "crosscorrelation")) { var.ls <- c(var.ls, "crossCorrelationAB", "crossCorrelationBA") }
  if (args[i] %in% c("entropy", "transfer-entropy", "transferentropy")) { var.ls <- c(var.ls, "transferEntropy") }
  if (args[i] %in% c("coh", "coherence")) { var.ls <- c(var.ls, "coherence") }
  if (args[i] %in% c("wavelet", "wavelet-coherence")) { var.ls <- c(var.ls, "waveletCoherence") }
  if (args[i] %in% c("mi", "mutual-information")) { var.ls <- c(var.ls, "mutualInformation") }
  if (args[i] %in% c("dist", "euclid", "euclidean", "euclidean-distance")) { var.ls <- c(var.ls, "euclideanDistance") }
  if (args[i] %in% c("city", "cityblock", "cityblock", "manhattan", "city-block-distance", "manhattan distance")) { var.ls <- c(var.ls, "manhattanDistance") }
  if (args[i] %in% c("dtw", "dynamic-time-warping", "warp", "warping")) { var.ls <- c(var.ls, "dynamicTimeWarping") }
  if (args[i] %in% c("earth", "earthmover", "earthmovers-distance")) { var.ls <- c(var.ls, "earthmoversDistance") }
  if (args[i] %in% c("lut", "lookup")) { lut <- args[i+1] }
  if (args[i] %in% c("lut_column", "lut_name", "label_column", "label_name")) { lut.col <- args[i+1]}
  if (args[i] %in% c("long", "long_df")) { df.type <- "long" }
  if (args[i] %in% c("short", "short_df")) { df.type <- "short" }
  if (args[i] %in% c("mx", "matrix")) { df.type <- "matrix" }
  if (args[i] %in% c("no_plot")) { do.plot <- FALSE }
  if (args[i] %in% c("c", "cat", "concat", "concatenate", "cat.with", "catwith")) { cat.with <- args[i+1] }
  if (args[i] %in% c("dir_save", "save_dir", "dirsave", "savedir", "save")) { dir.save <- args[i+1] }
}

# input checks -----------------------------------------------------------------
if (is.null(ts)) {
  exit("ERROR [INC connectivityMx.R] input time-series required")
}

# load Time-Series -------------------------------------------------------------
delims <- c("\t",",",";"," ","")
delim.chk <- TRUE
iter <- 0
while (delim.chk) {
  iter <- iter + 1
  df <- read.csv(ts, header=F, sep=delims[iter], as.is=TRUE)
  if (ncol(df) > 1) { delim.chk <- FALSE }
}

# label columns if lut provided ------------------------------------------------
if (!is.null(lut)) {
  delim.chk <- TRUE
  iter <- 0
  while (delim.chk) {
    iter <- iter + 1
    lut.df <- read.csv(lut, sep=delims[iter], as.is=TRUE)
    if (ncol(df) > 1) { delim.chk <- FALSE }
  }
  if (nrow(lut.df) != ncol(df)) {
    exit("ERROR [INC connectivityMx.R] number of labels does not match number of time-series")
  }
  colnames(df) <- lut.df[ ,lut.col]
}
alabs <- matrix(rep(colnames(df), ncol(df)), ncol=ncol(df))
alabs <- alabs[upper.tri(alabs)]
blabs <- matrix(rep(colnames(df), ncol(df)), ncol=ncol(df), byrow = T)
blabs <- blabs[upper.tri(blabs)]

pid <- unlist(strsplit(unlist(strsplit(basename(ts), "_"))[1], "sub-"))[2]
sid <- unlist(strsplit(unlist(strsplit(basename(ts), "_"))[2], "ses-"))[2]
prefix <- file_path_sans_ext(basename(ts))
date_calc <- format(Sys.time(),"%Y-%m-%dT%H:%M:%S")

if (df.type == "long") {
  pf <- data.frame(
    participant_id=rep(pid, length(alabs)),
    session_id=rep(sid, length(alabs)),
    date_calculated=rep(date_calc, length(alabs)),
    A=alabs, B=blabs,
    matrix(as.numeric(NA), nrow=length(alabs), ncol=length(var.ls)))
  colnames(pf)[6:ncol(pf)] <- var.ls
} else if (df.type == "short") {
  pf <- data.frame(
    participant_id=rep(pid, length(var.ls)),
    session_id=rep(sid, length(var.ls)),
    date_calculated=rep(date_calc, length(var.ls)),
    measure = var.ls, 
    matrix(as.numeric(NA), ncol=length(alabs), nrow=length(var.ls)))
  colnames(pf)[5:ncol(pf)] <- paste(alabs, blabs, sep="_")
}

if (do.plot) { suppressMessages(suppressWarnings(library(ggplot2))) }

# do PEARSON CORRELATION --------------------------------------------------------
if ("pearsonCorrelation" %in% var.ls) {
  tx <- cor(df)
  colnames(tx) <- rownames(tx) <- colnames(df)
  tf <- as.vector(tx[upper.tri(tx)])
  if (df.type == "long" ) { pf[ , "pearsonCorrelation"] <- tf }
  if (df.type == "short" ) { pf[pf$measure=="pearsonCorrelation", 5:ncol(pf)] <- tf }
  if (df.type == "matrix" ) {
    colnames(tx) <- rownames(tx) <- alabs
    write.table(tx, file=paste0(dir.save, "/", prefix, "_pearsonR.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    tp <- melt(tx)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(tx)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_gradient2(low="#0000af", mid="#ffffff", high="#af0000", limits=c(-1,1)) +
      geom_raster() +
      labs(title= "Pearson Correlation") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_pearsonR.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}

# do CROSS-CORRELATION (manipulate lag?)
if ("crossCorrelationAB" %in% var.ls) {
  txAB <- cor(df[-nrow(df),], df[-1,])
  txBA <- cor(df[-1,], df[-nrow(df),])
  if (df.type == "long") {
    pf[ ,"crossCorrelationAB"] <- txAB[upper.tri(txAB)]
    pf[ ,"crossCorrelationBA"] <- txBA[upper.tri(txBA)]
  }
  if (df.type == "short") {
    pf["crossCorrelationAB", 5:ncol(pf)] <- txAB[upper.tri(txAB)]
    pf["crossCorrelationBA", 5:ncol(pf)] <- txBA[upper.tri(txBA)]
  }
  if (df.type == "matrix" ) {
    colnames(txAB) <- rownames(txAB) <- colnames(txBA) <- rownames(txBA) <- alabs
    write.table(txAB, file=paste0(dir.save, "/", prefix, "_crossCorrAB.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
    write.table(txBA, file=paste0(dir.save, "/", prefix, "_crossCorrBA.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    tp <- txAB
    diag(tp) <- NA
    tp[lower.tri(tp)] <- txBA[lower.tri(txBA)]
    tp <- melt(tp)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(txAB)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_gradient2(low="#0000af", mid="#ffffff", high="#af0000", limits=c(-1,1)) +
      geom_raster() +
      labs(title= "Cross-Correlation (lag 1, AB upper, BA lower)") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_crossCorrelation.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}

# do TRANSFER ENTROPY --------------------------------------------------------
### NOT READY IS NOT FULLY IMPLEMENTED FOR BOTH DIRECTIONS
if ("transferEntropy" %in% var.ls) {
  suppressMessages(suppressWarnings(library(RTransferEntropy)))
  tx <- matrix(NA,nrow=ncol(df), ncol=ncol(df))
  for (i in 1:(ncol(df)-1)) {
    for (j in (1+1):ncol(df)) {
      xx <- transfer_entropy(df[,i], df[,j])
      tx[i,j] <- tx[j,i] <- xx$coef
      print(i)
    }
  }
  colnames(tx) <- rownames(tx) <- colnames(df)
  tf <- as.vector(tx[upper.tri(tx)])
  if (df.type == "long" ) { pf[ , "transferEntropy"] <- tf }
  if (df.type == "short" ) { pf[pf$measure=="transferEntropy", 5:ncol(pf)] <- tf }
  if (df.type == "matrix" ) {
    colnames(tx) <- rownames(tx) <- alabs
    write.table(tx, file=paste0(dir.save, "/", prefix, "_transferEntropy.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    tp <- melt(tx)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(tx)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_viridis_d() +
      geom_raster() +
      labs(title= "Transfer Entropy") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_transferEntropy.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}

# do COHERENCE, not implemented properly
if ("coherence" %in% var.ls) {
  tx <- spectrum(df)
  tx <- apply(tx$coh, 2, function(x) max(x))
  if (df.type == "long") { pf[ ,"coherence"] <- tx[upper.tri(tx)] }
  if (df.type == "short") { pf[pf$measure=="coherence", 5:ncol(pf)] <- tx[upper.tri(tx)] }
  if (df.type == "matrix" ) {
    colnames(tx) <- rownames(tx) <- alabs
    write.table(tx, file=paste0(dir.save, "/", prefix, "_coherence.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    tp <- melt(tx)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(tx)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_viridis_c() +
      geom_raster() +
      labs(title= "Coherence") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_coherence.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}

# do WAVELET COHERENCE, not implemented properly
if ("waveletCoherence" %in% var.ls) {
  suppressMessages(suppressWarnings(library(WaveletComp)))
  tx <- analyze.coherency(df)
  if (df.type == "long") { pf[ ,"waveletCoherence"] <- tx[upper.tri(tx)] }
  if (df.type == "short") { pf[pf$measure=="waveletCoherence", 5:ncol(pf)] <- tx[upper.tri(tx)] }
  if (df.type == "matrix" ) {
    colnames(tx) <- rownames(tx) <- alabs
    write.table(tx, file=paste0(dir.save, "/", prefix, "_waveletCoherence.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    tp <- melt(tx)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(tx)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_viridis_d() +
      geom_raster() +
      labs(title= "Wavelet Coherence") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_waveletCoherence.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}

# do MUTUAL INFORMATION
if ("mutualInformation" %in% var.ls) {
  suppressMessages(suppressWarnings(library(infotheo)))
  tx <- mutinformation(discretize(df))
  if (df.type == "long") { pf[ ,"mutualInformation"] <- tx[upper.tri(tx)] }
  if (df.type == "short") { pf[pf$measure=="mutualInformation", 5:ncol(pf)] <- tx[upper.tri(tx)] }
  if (df.type == "matrix" ) {
    colnames(tx) <- rownames(tx) <- alabs
    write.table(tx, file=paste0(dir.save, "/", prefix, "_mutualInformation.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    tp <- melt(tx)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(tx)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_viridis_c() +
      geom_raster() +
      labs(title= "Mutual Information") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_mutualInformation.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}

## make scaled dataset to scale distance between 0 and 1
if (any(c("euclideanDistance", "manhattanDistance", "earthmoversDistance") %in% var.ls)) {
  sf <- df
  for (i in 1:ncol(sf)) { sf[ ,i] <- (sf[,i] - min(sf[,i]))/(max(sf[,i]) - min(sf[,i])) }
}

# do EUCLIDEAN DISTANCE
if ("euclideanDistance" %in% var.ls) {
  tx <- as.matrix(dist(t(sf), method="euclidean")) / sqrt(ncol(sf))
  if (df.type == "long") { pf[ ,"euclideanDistance"] <- tx[upper.tri(tx)] }
  if (df.type == "short") { pf[pf$measure=="euclideanDistance", 5:ncol(pf)] <- tx[upper.tri(tx)] }
  if (df.type == "matrix" ) {
    colnames(tx) <- rownames(tx) <- alabs
    write.table(tx, file=paste0(dir.save, "/", prefix, "_euclideanDistance.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    tp <- melt(tx)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(tx)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_viridis_c() +
      geom_raster() +
      labs(title= "Euclidean Distance (normalized)") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_euclideanDistance.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}

# do CITY BLOCK DISTANCE
if ("manhattanDistance" %in% var.ls) {
  tx <- as.matrix(dist(t(sf), method="manhattan", upper=T)) / ncol(sf)
  if (df.type == "long") { pf[ ,"manhattanDistance"] <- tx[upper.tri(tx)] }
  if (df.type == "short") { pf[pf$measure=="manhattanDistance", 5:ncol(pf)] <- tx[upper.tri(tx)] }
  if (df.type == "matrix" ) {
    colnames(tx) <- rownames(tx) <- alabs
    write.table(tx, file=paste0(dir.save, "/", prefix, "_manhattanDistance.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    tp <- melt(tx)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(tx)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_viridis_c() +
      geom_raster() +
      labs(title= "Manhattan Distance") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_manhattanDistance.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}
# do DYNAMIC-TIME WARPING
if ("dynamicTimeWarping" %in% var.ls) {
  suppressMessages(suppressWarnings(library(dtw)))
  tx <- dtwDist(t(df))
  if (df.type == "long") { pf[ ,"dynamicTimeWarping"] <- tx[upper.tri(tx)] }
  if (df.type == "short") { pf[pf$measure=="dynamicTimeWarping", 5:ncol(pf)] <- tx[upper.tri(tx)] }
  if (df.type == "matrix" ) {
    colnames(tx) <- rownames(tx) <- alabs
    write.table(tx, file=paste0(dir.save, "/", prefix, "_dynamicTimeWarping.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    tp <- melt(tx)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(tx)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_viridis_c() +
      geom_raster() +
      labs(title= "Dynamic Time Warping") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_dynamicTimeWarping.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}

# do EARTHMOVER'S DISTANCE
if ("earthmoversDistance" %in% var.ls) {
  suppressMessages(suppressWarnings(library(transport)))
  tx <- matrix(NA,nrow=ncol(sf), ncol=ncol(sf))
  for (i in 1:(ncol(df)-1)) {
    for (j in (1+1):ncol(df)) {
      tx[i,j] <- tx[j,i] <- wasserstein1d(sf[,i], sf[,j])
    }
  }
  if (df.type == "long") { pf[ ,"earthmoversDistance"] <- tx[upper.tri(tx)] }
  if (df.type == "short") { pf[pf$measure=="earthmoversDistance", 5:ncol(pf)] <- tx[upper.tri(tx)] }
  if (df.type == "matrix" ) {
    colnames(tx) <- rownames(tx) <- alabs
    write.table(tx, file=paste0(dir.save, "/", prefix, "_earthmoversDistance.csv"),
                sep=",", quote=F, row.names=T, col.names=T)
  }
  if (do.plot) {
    colnames(tx) <- rownames(tx) <- colnames(df)
    tp <- melt(tx)
    tp$Var2 <- factor(tp$Var2, levels=rev(colnames(tx)))
    tplot <- ggplot(tp, aes(x=Var1, y=Var2, fill=value)) +
      theme_void() +
      coord_equal() +
      scale_x_discrete(position="top") +
      scale_fill_viridis_c() +
      geom_raster() +
      labs(title= "Earthmover's Distance") +
      theme(legend.title=element_blank(),
            legend.position="right")
    if (!is.null(lut)) {
      tplot <- tplot +
        theme(axis.text.x=element_text(angle=90, hjust=0, vjust=0.5, size=6),
              axis.text.y=element_text(hjust=1, vjust=0.5, size=6))
    }
    ggsave(filename=paste0(dir.save, "/", prefix, "_earthmoversDistance.png"),
           plot=tplot, device="png", width=4, height=4, units="in", dpi=340)
  }
}

# save output --------------------------------------------------------------------------
if (df.type %in% c("long", "short")) {
  write.table(pf, file=paste0(dir.save, "/", prefix, "_connectivity_", df.type, "_df.csv"),
              sep=",", quote=F, row.names=F, col.names=T)
}

# concatenate with existing output -----------------------------------------------------
if (!is.null(cat.with)) {
  if (!file.exists(cat.with)) {
    write.table(pf, file=cat.with, sep=",", quote=F, row.names=F, col.names=T)
  } else {
    write.table(pf, file=cat.with, sep=",", append=T, quote=F, row.names=F, col.names=F)
  }
}


