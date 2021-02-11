args <- commandArgs(trailingOnly = TRUE)

library(tools)
library(ggplot2)
library(viridis)
library(reshape2)

timbow <- colorRampPalette(c("#440154FF", "#482878FF", "#3E4A89FF", 
"#31688EFF", "#26828EFF", "#1F9E89FF", "#35B779FF", "#6DCD59FF", "#B4DE2CFF", "#FDE725FF", "#F8E125FF", "#FDC926FF", "#FDB32FFF", "#FA9E3BFF", "#F58B47FF", "#ED7953FF", "#E3685FFF", "#D8576BFF", "#CC4678FF"))

regressor.ls <- unlist(strsplit(args[i], split=","))

group.ls <- character(0)
color.ls <- character(0)
color.vals <- character(0)
df <- data.frame(TR=numeric(0),
                 grouping.var=character(0),
                 color.var=character(0),
                 value=numeric(0),
                 stringsAsFactors = FALSE)
for (i in 1:length(regressor.ls)) {
  tf <- read.csv(regressor.ls[i], header=FALSE, sep="\t")
  nTR <- nrow(tf)
  nVar <- ncol(tf)
  if (grepl("moco[+]6[.]1D", regressor.ls[i])) {
    group.label <- "MoCo 6df"
    uf <- data.frame(TR=rep(1:nTR, nVar),
                     grouping.var=c(rep(group.label, nVar*nTR)),
                     color.var=c(rep("X", nTR), rep("Y", nTR), rep("Z", nTR),
                                 rep("Roll", nTR), rep("Pitch", nTR), rep("Yaw", nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if (!("X" %in% color.ls)) { 
      color.ls <- c(color.ls, "X")
      color.vals <- c(color.vals, "#a80000")
    }
    if (!("Y" %in% color.ls)) {
      color.ls <- c(color.ls, "Y")
      color.vals <- c(color.vals, "#00a800")
    }
    if (!("Z" %in% color.ls)) {
      color.ls <- c(color.ls, "Z")
      color.vals <- c(color.vals, "#0000a8")
    }
    if (!("Roll" %in% color.ls)) {
      color.ls <- c(color.ls, "Roll")
      color.vals <- c(color.vals, "#a86400")
    }
    if (!("Pitch" %in% color.ls)) {
      color.ls <- c(color.ls, "Pitch")
      color.vals <- c(color.vals, "#00a864")
    }
    if (!("Yaw" %in% color.ls)) {
      color.ls <- c(color.ls, "Yaw")
      color.vals <- c(color.vals, "#6400a8")
    }
  } else if (grepl("moco[+]6[+]deriv[.]1D", regressor.ls[i])) {
    group.label <- "MoCo 6df dx"
    uf <- data.frame(TR=rep(1:nTR, ncol(tf)),
                     grouping.var=c(rep(group.label, nVar*nTR)),
                     color.var=c(rep("X", nTR), rep("Y", nTR), rep("Z", nTR),
                                 rep("Roll", nTR), rep("Pitch", nTR), rep("Yaw", nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if (!("X" %in% color.ls)) {
      color.ls <- c(color.ls, "X")
      color.vals <- c(color.vals, "#a80000")
    }
    if (!("Y" %in% color.ls)) {
      color.ls <- c(color.ls, "Y")
      color.vals <- c(color.vals, "#00a800")
    }
    if (!("Z" %in% color.ls)) {
      color.ls <- c(color.ls, "Z")
      color.vals <- c(color.vals, "#0000a8")
    }
    if (!("Roll" %in% color.ls)) {
      color.ls <- c(color.ls, "Roll")
      color.vals <- c(color.vals, "#a86400")
    }
    if (!("Pitch" %in% color.ls)) {
      color.ls <- c(color.ls, "Pitch")
      color.vals <- c(color.vals, "#00a864")
    }
    if (!("Yaw" %in% color.ls)) {
      color.ls <- c(color.ls, "Yaw")
      color.vals <- c(color.vals, "#6400a8")
    }
  } else if (grepl("moco[+]6[+]quad[.]1D", regressor.ls[i])) {
    group.label <- "MoCo 6df sq."
    uf <- data.frame(TR=rep(1:nTR, ncol(tf)),
                     grouping.var=c(rep(group.label, nVar*nTR)),
                     color.var=c(rep("X", nTR), rep("Y", nTR), rep("Z", nTR),
                                 rep("Roll", nTR), rep("Pitch", nTR), rep("Yaw", nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if (!("X" %in% color.ls)) {
      color.ls <- c(color.ls, "X")
      color.vals <- c(color.vals, "#a80000")
    }
    if (!("Y" %in% color.ls)) {
      color.ls <- c(color.ls, "Y")
      color.vals <- c(color.vals, "#00a800")
    }
    if (!("Z" %in% color.ls)) {
      color.ls <- c(color.ls, "Z")
      color.vals <- c(color.vals, "#0000a8")
    }
    if (!("Roll" %in% color.ls)) {
      color.ls <- c(color.ls, "Roll")
      color.vals <- c(color.vals, "#a86400")
    }
    if (!("Pitch" %in% color.ls)) {
      color.ls <- c(color.ls, "Pitch")
      color.vals <- c(color.vals, "#00a864")
    }
    if (!("Yaw" %in% color.ls)) {
      color.ls <- c(color.ls, "Yaw")
      color.vals <- c(color.vals, "#6400a8")
    }
  } else if (grepl("moco[+]6[+]quad[+]deriv[.]1D", regressor.ls[i])) {
    group.label <- "MoCo 6df sq. dx"
    uf <- data.frame(TR=rep(1:nTR, ncol(tf)),
                     grouping.var=c(rep(group.label, nVar*nTR)),
                     color.var=c(rep("X", nTR), rep("Y", nTR), rep("Z", nTR),
                                 rep("Roll", nTR), rep("Pitch", nTR), rep("Yaw", nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if (!("X" %in% color.ls)) {
      color.ls <- c(color.ls, "X")
      color.vals <- c(color.vals, "#a80000")
    }
    if (!("Y" %in% color.ls)) {
      color.ls <- c(color.ls, "Y")
      color.vals <- c(color.vals, "#00a800")
    }
    if (!("Z" %in% color.ls)) {
      color.ls <- c(color.ls, "Z")
      color.vals <- c(color.vals, "#0000a8")
    }
    if (!("Roll" %in% color.ls)) {
      color.ls <- c(color.ls, "Roll")
      color.vals <- c(color.vals, "#a86400")
    }
    if (!("Pitch" %in% color.ls)) {
      color.ls <- c(color.ls, "Pitch")
      color.vals <- c(color.vals, "#00a864")
    }
    if (!("Yaw" %in% color.ls)) {
      color.ls <- c(color.ls, "Yaw")
      color.vals <- c(color.vals, "#6400a8")
    }
  } else if (grepl("compcorr-anatomy[.]1D", regressor.ls[i])) {
    group.label <- "Anatomical CompCorr"
    uf <- data.frame(TR=rep(1:nTR, ncol(tf)),
                     grouping.var=c(rep(group.label, 2*nTR)),
                     color.var=c(rep("CSF", nTR),
                                 rep("WM", nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if (!("CSF" %in% color.ls)) {
      color.ls <- c(color.ls, "CSF")
      color.vals <- c(color.vals, "#a800a8")
    }
    if (!("WM" %in% color.ls)) {
      color.ls <- c(color.ls, "WM")
      color.vals <- c(color.vals, "#00a8a8")
    }
  } else if (grepl("compcorr-temporal[.]1D", regressor.ls[i])) {
    group.label <- "Temporal CompCorr"
    uf <- data.frame(TR=rep(1:nTR, ncol(tf)),
                     grouping.var=c(rep(group.label, nVar*nTR)),
                     color.var=c(sort(rep(paste("Comp", 1:nVar), nTR))),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    color.ls <- c(color.ls, paste("Comp", 1:nVar))
    color.vals <- c(color.vals, timbow(nVar))
  } else if (grepl("global-anatomy[.]1D", regressor.ls[i])) {
    group.label <- "Global Anatomical"
    uf <- data.frame(TR=rep(1:nTR, 1),
                     grouping.var=c(rep(group.label, nTR)),
                     color.var=c(rep(NA, nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if ("NA" %in% color.ls) {
      color.ls <- c(color.ls, "NA")
      color.vals <- c(color.vals, "#000000")
    }
  } else if (grepl("global-temporal[.]1D", regressor.ls[i])) {
    group.label <- "Global Temporal"
    uf <- data.frame(TR=rep(1:nTR, 1),
                     grouping.var=c(rep(group.label, nTR)),
                     color.var=c(rep(NA, nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if ("NA" %in% color.ls) {
      color.ls <- c(color.ls, "NA")
      color.vals <- c(color.vals, "#000000")
    }
  } else if (grepl("AD[+]mm[.]1D", regressor.ls[i])) {
    group.label <- "Absolute Displacement (mm)"
    uf <- data.frame(TR=rep(1:nTR, nVar),
                     grouping.var=c(rep(group.label, nVar*nTR)),
                     color.var=c(rep("X", nTR), rep("Y", nTR), rep("Z", nTR),
                                 rep("Roll", nTR), rep("Pitch", nTR), rep("Yaw", nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if (!("X" %in% color.ls)) { 
      color.ls <- c(color.ls, "X")
      color.vals <- c(color.vals, "#a80000")
    }
    if (!("Y" %in% color.ls)) {
      color.ls <- c(color.ls, "Y")
      color.vals <- c(color.vals, "#00a800")
    }
    if (!("Z" %in% color.ls)) {
      color.ls <- c(color.ls, "Z")
      color.vals <- c(color.vals, "#0000a8")
    }
    if (!("Roll" %in% color.ls)) {
      color.ls <- c(color.ls, "Roll")
      color.vals <- c(color.vals, "#a86400")
    }
    if (!("Pitch" %in% color.ls)) {
      color.ls <- c(color.ls, "Pitch")
      color.vals <- c(color.vals, "#00a864")
    }
    if (!("Yaw" %in% color.ls)) {
      color.ls <- c(color.ls, "Yaw")
      color.vals <- c(color.vals, "#6400a8")
    }
  } else if (grepl("RD[+]mm[.]1D", regressor.ls[i])) {
    group.label <- "Relative Displacement (mm)"
    uf <- data.frame(TR=rep(1:nTR, nVar),
                     grouping.var=c(rep(group.label, nVar*nTR)),
                     color.var=c(rep("X", nTR), rep("Y", nTR), rep("Z", nTR),
                                 rep("Roll", nTR), rep("Pitch", nTR), rep("Yaw", nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if (!("X" %in% color.ls)) { 
      color.ls <- c(color.ls, "X")
      color.vals <- c(color.vals, "#a80000")
    }
    if (!("Y" %in% color.ls)) {
      color.ls <- c(color.ls, "Y")
      color.vals <- c(color.vals, "#00a800")
    }
    if (!("Z" %in% color.ls)) {
      color.ls <- c(color.ls, "Z")
      color.vals <- c(color.vals, "#0000a8")
    }
    if (!("Roll" %in% color.ls)) {
      color.ls <- c(color.ls, "Roll")
      color.vals <- c(color.vals, "#a86400")
    }
    if (!("Pitch" %in% color.ls)) {
      color.ls <- c(color.ls, "Pitch")
      color.vals <- c(color.vals, "#00a864")
    }
    if (!("Yaw" %in% color.ls)) {
      color.ls <- c(color.ls, "Yaw")
      color.vals <- c(color.vals, "#6400a8")
    }
  } else if (grepl("FD[.]1D", regressor.ls[i])) {
    group.label <- "Framewise Displacement"
    uf <- data.frame(TR=rep(1:nTR, 1),
                     grouping.var=c(rep(group.label, nTR)),
                     color.var=c(rep(NA, nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if ("NA" %in% color.ls) {
      color.ls <- c(color.ls, "NA")
      color.vals <- c(color.vals, "#000000")
    }
  } else if (grepl("RMS[.]1D", regressor.ls[i])) {
    group.label <- "RMS"
    uf <- data.frame(TR=rep(1:nTR, 1),
                     grouping.var=c(rep(group.label, nTR)),
                     color.var=c(rep(NA, nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if ("NA" %in% color.ls) {
      color.ls <- c(color.ls, "NA")
      color.vals <- c(color.vals, "#000000")
    }
  } else if (grepl("spike[.]1D", regressor.ls[i])) {
    group.label <- "Spike"
    uf <- data.frame(TR=rep(1:nTR, 1),
                     grouping.var=c(rep(group.label, nTR)),
                     color.var=c(rep(NA, nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    if ("NA" %in% color.ls) {
      color.ls <- c(color.ls, "NA")
      color.vals <- c(color.vals, "#000000")
    }
  } else if (grepl("moco[+]12[.]1D", regressor.ls[i])) {
    group.label <- "MoCo 12df"
    uf <- data.frame(TR=rep(1:nTR, nVar),
                     grouping.var=c(rep(group.label, nVar*nTR)),
                     color.var=sort(rep(paste("affine", 1:nVar), nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    color.ls <- c(color.ls, paste("affine", 1:nVar))
    color.vals <- c(color.vals, timbow(nVar))
  } else {
    group.label <- "Regressor"
    uf <- data.frame(TR=rep(1:nTR, nVar),
                     grouping.var=c(rep(group.label, nVar*nTR)),
                     color.var=sort(rep(paste("var", 1:nVar), nTR)),
                     value=as.numeric(unlist(tf)), stringsAsFactors = FALSE)
    group.ls <- c(group.ls, group.label)
    color.ls <- c(color.ls, paste("var", 1:nVar))
    color.vals <- c(color.vals, timbow(nVar))
  }
  df <- rbind(df,uf)
}
df$grouping.var <- factor(df$grouping.var, levels = group.ls)
df$color.var <- factor(df$color.var, levels=color.ls)

ggplot(df, aes(x=TR, y=value, color=color.var)) +
  theme_minimal() +
  scale_color_manual(values = color.vals) +
  scale_x_continuous(expand=c(0,0)) +
  geom_hline(yintercept = 0, linetype="dotted") +
  facet_wrap(~grouping.var, scales="free_y", ncol=1, strip.position="left") +
  geom_line(size=1) +
  labs(title="Nuisance Regressors", y=NULL, x=NULL) +
  theme(axis.line.y = element_line(),
        strip.text.y.left = element_text(angle=0, size=12, hjust=1),
        strip.placement = "outside",
        axis.text.y = element_text(size=8),
        axis.text.x = element_blank(),
        axis.title = element_text(size=12),
        plot.title = element_text(size=12),
        plot.title.position = "plot")

                 ggsave(filename = "temp.png",
       path = "D:/tim/dev",
       plot = the.plot,
       device = "png",
       width = 7.5, height=0.5*nRGR, dpi=320)

