args <- commandArgs(trailingOnly = TRUE)

library(ggplot2, quietly=T)
library(viridis, quietly=T)

# inputs:
# palette: colon-delimited list of palettes to use, corresponding to the color
#          scales to be used per layer in image. Within each colon-delimited,
#          there needs to be either a named palette or a comma-separated list of
#          HEX colors
#     Examples:
#     -"palette", "grayscale:hot:cold"
#       -> BG gray, FG 1 hot, FG 2 cold
#     -"palette", "grayscale:#000000,#FF0000:#000000,#00FF00:#000000,#0000FF"
#       -> BG gray, FG 1 black to red, FG 2 black to green, FG 3 black to blue
# order: comma-delimited list of doirections for randomizing or reversing the
#        order of colors in the palette. Optional, if length of ospecificed
#        order is 1, that order will be used for all palettes. or specifiy
#        unique values for each palette. Values can be "r", "rand", "random";
#        or "rev", "reverse", "inverse"

# parse inputs -----------------------------------------------------------------
color.palette <- character(0)
color.n <- 200
color.order <- "normal"
color.bg <- "#000000"
no.png <- FALSE
dir.save <- "~"
prefix <- NULL

for (i in seq(1,length(args))) {
  if (args[i] == "palette") {
    color.palette <- args[i+1]
  } else if (args[i] %in% c("n", "number", "num.colors")) {
    color.n <- as.numeric(args[i+1])
  } else if (args[i] %in% c("order", "color.order")) {
    color.order <- args[i+1]
  } else if (args[i] %in% c("bg", "background")) {
    color.bg <- args[i+1]
  } else if (args[i] %in% c("plot", "png")) {
    no.png <- FALSE
  } else if (args[i] %in% c("dir.save")) {
    dir.save <- args[i+1]
  } else if (args[i] %in% c("prefix")) {
    prefix <- args[i+1]
  }
}

if (is.null(prefix)) {
  tn <- length(list.files(dir.save, pattern="CBAR"))
  prefix <- sprintf("CBAR_%0.0f", tn)
}

# get color palette ------------------------------------------------------------
color.ls <- character(0)
cpal <- character(0)
if (color.palette == "timbow") {
  cpal <- colorRampPalette(c("#440154FF", "#482878FF", "#3E4A89FF", 
    "#31688EFF", "#26828EFF", "#1F9E89FF", "#35B779FF", "#6DCD59FF",
    "#B4DE2CFF", "#FDE725FF", "#F8E125FF", "#FDC926FF", "#FDB32FFF",
    "#FA9E3BFF", "#F58B47FF", "#ED7953FF", "#E3685FFF", "#D8576BFF",
    "#CC4678FF"))
  color.ls <- cpal(color.n)
}
if (color.palette %in% c("viridis", "magma", "inferno", "plasma", "cividis")) {
  cpal <- colorRampPalette(viridis(19, option=color.palette))
  color.ls <- cpal(color.n)
}
if (grepl("cubehelix", color.palette)) {
  temp <- unlist(strsplit(color.palette, split=","))
  start <- 0.5
  r <- -1.5
  hue <- 2
  gamma <- 1
  if (length(temp) > 1) {
    for (i in 2:length(temp)) {
      params <- unlist(strsplit(temp[i]))
      if (params[1] == "start") {
        start <- as.numeric(params[2])
      } else if (params[1] == "r") {
        r <- as.numeric(params[2])
      } else if (params[1] == "hue") {
        hue <- as.numeric(params[2])
      } else if (params[1] == "gamma") {
        gamma <- as.numeric(params[2])
      }
    }
  }
  M = matrix(c(-0.14861, -0.29227, 1.97294, 1.78277, -0.90649, 0), ncol = 2)
  lambda = seq(0, 1, length.out = color.n)
  l = rep(lambda^gamma, each = 3)
  phi = 2 * pi * (start/3 + r * lambda)
  t = rbind(cos(phi), sin(phi))
  cpal = l + hue * l * (1 - l)/2 * (M %*% t)
  cpal = pmin(pmax(cpal, 0), 1)
  cpal = apply(cpal, 2, function(x) rgb(x[1], x[2], x[3]))
  color.ls <- cpal(color.n)
}
if (color.palette == "hot") {
  cpal <- colorRampPalette(c("#7F0000", "#FF0000", "#FF7F00", "#FFFF00", "#FFFF7F"))
  color.ls <- cpal(color.n)
}
if (color.palette == "cold") {
  cpal <- colorRampPalette(rev(c("#00007F", "#0000FF", "#007FFF", "#00FFFF", "#7FFFFF")))
  color.ls <- cpal(color.n)
}
if (color.palette %in% c("grayscale", "grayscale", "gray", "grey")) {
  cpal <- colorRampPalette(c("#000000", "#FFFFFF"))
  color.ls <- cpal(color.n)
}
if (color.palette == "rainbow") {
  cpal <- colorRampPalette(c("#FF0000", "#FFFF00", "#00FF00", "#00FFFF", "#0000FF", "#FF00FF"))
  color.ls <- cpal(color.n)
}
if (length(cpal) == 0) {
  cpal <- colorRampPalette(unlist(strsplit(color.palette, split=",")))
  color.ls <- cpal(color.n)
}
  
if (color.order %in% c("r", "rand", "random")) {
  color.ls <- sample(color.ls, color.n, replace = F)
}
if (color.order %in% c("rev", "reverse", "inverse", "inv", "i")) {
  color.ls <- rev(color.ls)
}

if (no.png == FALSE) {
  plotf <- data.frame(x=rep(1,color.n), y=1:color.n, val=color.ls)
  color.bar <- ggplot(plotf, aes(x=x,y=y,fill=val)) +
    theme_void() +
    geom_raster(fill=plotf$val) +
    theme(legend.position="none",
          plot.margin = margin(0.1, 0.1, 0.1, 0.1, "cm"),
          plot.background = element_rect(fill=color.bg, color=color.bg))
 ggsave(filename = paste0(prefix, ".png"),
        path = dir.save, plot = color.bar,
        device = "png", width=0.5, height=5, units = "cm", dpi = 320)
}

color.rgb <- format(t(col2rgb(color.ls))/255, digits=4)
color.bg <- format(t(col2rgb(color.bg))/255, digits=4)

# Write look up table for overlay image
if (file.exists(paste0(dir.save, "/", prefix, ".lut"))) {
  file.remove(paste0(dir.save, "/", prefix, ".lut"), showWarnings=FALSE)
}
fid <- file(paste0(dir.save, "/", prefix, ".lut"), open="a", encoding = "UTF-8")
writeLines(c(
  "%!VEST-LUT", "%%BeginInstance", "<<", "/SavedInstanceClassName /ClassLUT",
  "/PseudoColorMinimum 0.00", "/PseudoColorMaximum 1.00",
  "/PseudoColorMinControl /Low", "/PseudoColorMaxControl /High", "/PseudoColormap ["),
   con=fid, sep="\n")
writeLines(sprintf("<-color{%s,%s,%s}->", color.bg[,1], color.bg[,2], color.bg[,3]), con=fid, sep="\n")
writeLines(sprintf("<-color{%s,%s,%s}->", color.rgb[,1], color.rgb[,2], color.rgb[,3]), con=fid, sep="\n")
writeLines(c("]", ">>", "", "%%EndInstance", "%%EOF"), con=fid, sep="\n")
close(fid)

