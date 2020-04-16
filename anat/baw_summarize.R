args <- commandArgs(trailingOnly = TRUE)

input.tsv <- args[1]
input.stats <- args[2]
input.pixdim <- args[3]
input.lut <- args[4]

library(tools)

# DEBUG ----
#input.tsv <- "D:/data/sub-101_ses-1234abcd_tempVolSummary.tsv"
#input.stats <- "volume"
#input.pixdim <- "1x1x1"
#input.lut <- "D:/data/lut-baw+brain.tsv"
# ----

data <- read.csv(input.tsv, sep="\t")
lut <- read.csv(input.lut, sep="\t")

# parse input statistics
input.stats <- unlist(strsplit(input.stats, ","))
stats.key <- c("^Mean", "^NZMean", "^Sigma", "^NZSigma", "^Med", "^NZMed",
               "^Mode", "^NZMode", "^Min", "^NZMin", "^Max", "^NZMax",
               "^NZcount")
stats.label <- c("mean", "nzmean", "sigma", "nzsigma", "median", "nzmedian",
                 "mode", "nzmode", "min", "nzmin", "max", "nzmax", "volume")
which.stats <- which(stats.label %in% input.stats)

# Process input information, get voxel volume, and label index
voxel.sz <- prod(as.numeric(unlist(strsplit(input.pixdim, "x"))))
volume <- as.numeric(data[ ,grepl("^NZcount", x = colnames(data))]) * voxel.sz
labels <- unlist(strsplit(colnames(data[ ,grepl("^NZcount", x = colnames(data))]), "_"))
labels <- as.numeric(labels[seq(2,length(labels),2)])

# calculate stats for each ROI in LUT, using weighted average value where appropriate
out.mx <- matrix(NA, nrow=length(which.stats), ncol=ncol(lut)-1)
count <- 0
for (i in which.stats) {
  count <- count + 1
  if (i == length(stats.key)) {
    for (j in 2:ncol(lut)) {
      which.col <- lut$value[which(lut[ ,j])]
      which.idx <- which(labels %in% which.col)
      out.mx[count,j-1] <- sum(volume[which.idx])
    }
  } else {
    values <- as.numeric(data[ ,grepl(stats.key[i], x = colnames(data))])
    for (j in 2:ncol(lut)) {
      which.col <- lut$value[which(lut[ ,j])]
      which.idx <- which(labels %in% which.col)
      out.mx[count,j-1] <- weighted.mean(values[which.idx], volume[which.idx])
    }
  }
}

#Concatenate output with subject and session identifiers, date/time, and measure
df <- data.frame(participant_id = rep(unlist(strsplit(unlist(strsplit(input.tsv,"_"))[1],"-"))[2], length(which.stats)),
                 session_id = rep(unlist(strsplit(unlist(strsplit(input.tsv,"_"))[2],"-"))[2], length(which.stats)),
                 summary_date = rep(strftime(as.POSIXct(Sys.time(), "%Y-%m-%dT%H:%M:%S"), "%Y-%m-%dT%H:%M:%S%z"), length(which.stats)),
                 measure = stats.label[which.stats],
                 out.mx)

# Save output to same folder as input, append "_processed" to filename
write.table(df, file = paste0(file_path_sans_ext(input.tsv), "_processed.tsv"),
            append = FALSE, quote = FALSE, sep="\t", row.names = F, col.names = F)

