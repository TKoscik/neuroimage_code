args <- commandArgs(trailingOnly = TRUE)

dir.project <- args[1]
dir.input <- args[2]
dir.inc.root <- "/Shared/inc_scratch/code"
if (length(args) > 4 ) {
  for (i in seq(4, length(args), 2)) {
    if (args[i] == "dir.inc.root") {
      dir.inc.root <- args[i+1]
    }
  }
}

## debug ----
# dir.input <- "/Shared/koscikt/temp/scratch/rawdata"
# dir.inc.root <- "/Shared/nopoulos/nimg_core"
# researcher <- "/Shared/koscikt"
# project <- "temp"
## ----

library(tools)
source(paste0(dir.inc.root, "/dicom/ses_decode.R"))

fls <- list.files(dir.input, pattern="sub-")
fls <- fls[grepl(fls, pattern="nii")]
subject <- unlist(strsplit(unlist(strsplit(fls[1], split="-"))[2], split="_"))[1]
session <- unlist(strsplit(unlist(strsplit(fls[1], split="-"))[3], split="_"))[1]
site <- unlist(strsplit(unlist(strsplit(fls[1], split="-"))[4], split="_"))[1]
dot <- inc_ses_decode(session)
dot <- sprintf("%s-%s-%sT%s:%s:%s", substr(dot,1,4), substr(dot,5,6), 
               substr(dot,7,8), substr(dot,9,10), substr(dot,11,12), substr(dot,13,14))
mod <- character(length(fls))
for (i in 1:length(fls)) {
  temp <- unlist(strsplit(fls[i], "_"))
  mod[i] <- unlist(strsplit(temp[length(temp)], "[.]"))[1]
}
mod <- factor(mod, levels=c("T1w", "T2w", "T1rho", "T1map", "T2map", "T2star",
                            "FLAIR", "SWAN", "swi", "FLASH", "PD", "PDmap",
                            "PDT2", "inplaneT1", "inplaneT2", "angio",
                            "defacemask", "dwi", "bold", "sbref", "spinecho",
                            "phasediff", "phase", "phase1", "phase2",
                            "magnitude", "magnitude1", "magnitude2",
                            "fieldmap", "epi"))
fls <- fls[order(mod)]
mod <- mod[order(mod)]

# save.dir <- paste0(researcher, "/", project, "/qc/dicom_conversion")
prefix <- paste0("sub-", subject, "_ses-", session, "_site-", site)
# dir.create(save.dir, recursive = TRUE, showWarnings = FALSE)
rmd.file <- paste0(dir.input, "/", prefix, "_qc-dcmConversion.Rmd")
rmd.fid <- file(rmd.file, "w")

# Save subject info for email message
xf <- data.frame(subject, session, site, dot)
write.table(xf, paste0(dir.input, "/", prefix, "_subject-info.tsv"), sep="\t",
            quote=FALSE, row.names=FALSE, col.names=TRUE)

# Write RMD file ---------------------------------------------------------------
write("---", rmd.fid, sep="\n", append=FALSE)
write("output: html_document", rmd.fid, sep="\n", append=TRUE)
write("---", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write("```{r setup, include=FALSE}", rmd.fid, sep="\n", append=TRUE)
write("rm(list=ls())", rmd.fid, sep="\n", append=TRUE)
write("gc()", rmd.fid, sep="\n", append=TRUE)
write("knitr::opts_chunk$set(echo = FALSE)", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write('pkg.ls <- c("nifti.io", "htmltools", "R.utils", "ggplot2", "reshape2", "gridExtra", "grid")', rmd.fid, sep="\n", append=TRUE)
write('for (i in pkg.ls) { eval(parse(text=sprintf("library(%s)", i))) }', rmd.fid, sep="\n", append=TRUE)
write("```", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write("### __DICOM to NIfTI Conversion Report__  ", rmd.fid, sep="\n", append=TRUE)
write('#### Iowa Neuroimage Processing Core, `r format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")`  ', rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write("***", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write(paste0("Parent Directory: __", dir.project, "__  "), rmd.fid, sep="\n", append=TRUE)
write(paste0("Subject: __", subject, "__  "), rmd.fid, sep="\n", append=TRUE)
write(paste0("Session: __", session, "__  "), rmd.fid, sep="\n", append=TRUE)
write(paste0("Date of Scan: __", dot, "__  "), rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write("***", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write(paste0(dir.project, "/rawdata/sub-", subject, "/ses-", session, "/  "), rmd.fid, sep="\n", append=TRUE)
write("```{bash}", rmd.fid, sep="\n", append=TRUE)
write(paste0("tree -f ", dir.project, "/rawdata/sub-", subject, "/ses-", session, " \\"), rmd.fid, sep="\n", append=TRUE)
write(paste0("  -H ", dir.input, "/", prefix, "_rawdata-tree.html \\"), rmd.fid, sep="\n", append=TRUE)
write(paste0("  -o ", dir.input, "/", prefix, "_rawdata-tree.html \\"), rmd.fid, sep="\n", append=TRUE)
write('  --nolinks --noreport', rmd.fid, sep="\n", append=TRUE)
write(paste0("sed -i \'31d\' ", dir.input, "/", prefix, "_rawdata-tree.html"), rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write("for i in {1..13}; do", rmd.fid, sep="\n", append=TRUE)
write(paste0("  sed -i \'$d\' ", dir.input, "/", prefix, "_rawdata-tree.html"), rmd.fid, sep="\n", append=TRUE)
write("done", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write(paste0("echo \"</body>\" >> ", dir.input, "/", prefix, "_rawdata-tree.html"), rmd.fid, sep="\n", append=TRUE)
write(paste0("echo \"</html>\" >> ", dir.input, "/", prefix, "_rawdata-tree.html"), rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write("```", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write("```{r}", rmd.fid, sep="\n", append=TRUE)
write(paste0("x <- readLines(\"", dir.input, "/", prefix, "_rawdata-tree.html\")"), rmd.fid, sep="\n", append=TRUE)
write("x <- x[-which(x==\"\\t<h1>Directory Tree</h1><p>\")]", rmd.fid, sep="\n", append=TRUE)
write(paste0("writeLines(x, con=\"", dir.input, "/", prefix, "_rawdata-tree.html\", sep = \"\\n\")"), rmd.fid, sep="\n", append=TRUE)
write(paste0("includeHTML(\"", dir.input, "/", prefix, "_rawdata-tree.html\")"), rmd.fid, sep="\n", append=TRUE)
write("```", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)
write("***", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)

write("```{r}", rmd.fid, sep="\n", append=TRUE)
write("theme.obj <- theme(plot.title = element_blank(),", rmd.fid, sep="\n", append=TRUE)
write("                     legend.position=\"none\",", rmd.fid, sep="\n", append=TRUE)
write("                     legend.title = element_blank(),", rmd.fid, sep="\n", append=TRUE)
write("                     legend.text = element_text(size=8, margin=margin(1,0,0,0,\"null\")),", rmd.fid, sep="\n", append=TRUE)
write("                     axis.title=element_blank(),", rmd.fid, sep="\n", append=TRUE)
write("                     axis.text=element_blank(),", rmd.fid, sep="\n", append=TRUE)
write("                     axis.ticks=element_blank(),", rmd.fid, sep="\n", append=TRUE)
write("                     plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,\"null\")),", rmd.fid, sep="\n", append=TRUE)
write("                     plot.background=element_blank(),", rmd.fid, sep="\n", append=TRUE)
write("                     panel.background=element_rect(color=\"#000000\"),", rmd.fid, sep="\n", append=TRUE)
write("                     panel.grid=element_blank(),", rmd.fid, sep="\n", append=TRUE)
write("                     panel.border=element_blank(),", rmd.fid, sep="\n", append=TRUE)
write("                     panel.spacing.x=unit(c(0,0,0,0),\"null\"),", rmd.fid, sep="\n", append=TRUE)
write("                     panel.spacing.y=unit(c(0,0,0,0),\"null\"),", rmd.fid, sep="\n", append=TRUE)
write("                     plot.margin=margin(0,0,0,0, \"null\"),", rmd.fid, sep="\n", append=TRUE)
write("                     legend.margin=margin(0,0,0,0, \"null\"),", rmd.fid, sep="\n", append=TRUE)
write("                     panel.spacing = margin(0,0,0,0, \"null\"))", rmd.fid, sep="\n", append=TRUE)
write("```", rmd.fid, sep="\n", append=TRUE)
write("", rmd.fid, sep="\n", append=TRUE)

for (i in 1:length(fls)) {
  write("```{r fig.height=3, fig.width=9}", rmd.fid, sep="\n", append=TRUE)
  write(paste0("img <- \"", dir.input, "/", fls[i], "\""), rmd.fid, sep="\n", append=TRUE)
  write(paste0("fig.title <- unlist(strsplit(\"", fls[i], "\", \"[.]\"))[1]"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("img.dims <- nii.dims(img)"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("coords <- c(round(img.dims[1]/5*2), round(img.dims[2:3]/2))"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("volume <- read.nii.volume(img, 1)"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("x <- melt(volume[coords[1], , ])"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("y <- melt(volume[ , coords[2], ])"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("z <- melt(volume[ , , coords[3]])"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("pixdim <- unlist(nii.hdr(img, \"pixdim\"))[2:4]"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("plot.x <- ggplot() +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  theme_bw() +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  coord_fixed(ratio=pixdim[3]/pixdim[2],expand=FALSE, clip=\"off\") +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  geom_raster(data=x, aes(x=Var1, y=Var2, fill=value)) +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  scale_fill_gradientn(colors=c(\"#000000\", \"#ffffff\")) +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  theme.obj"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("plot.y <- ggplot() +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  theme_bw() +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  coord_fixed(ratio=pixdim[3]/pixdim[1],expand=FALSE, clip=\"off\") +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  geom_raster(data=y, aes(x=Var1, y=Var2, fill=value)) +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  scale_fill_gradientn(colors=c(\"#000000\", \"#ffffff\")) +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  theme.obj"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("plot.z <- ggplot() +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  theme_bw() +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  coord_fixed(ratio=pixdim[2]/pixdim[1],expand=FALSE, clip=\"off\") +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  geom_raster(data=z, aes(x=Var1, y=Var2, fill=value)) +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  scale_fill_gradientn(colors=c(\"#000000\", \"#ffffff\")) +"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("  theme.obj"), rmd.fid, sep="\n", append=TRUE)
  write(paste0("grid.arrange(plot.x, plot.y, plot.z, nrow=1, top=fig.title, clip=T, respect=T, padding=unit(1,\"lines\"))"), rmd.fid, sep="\n", append=TRUE)
  write("```", rmd.fid, sep="\n", append=TRUE)
  write("", rmd.fid, sep="\n", append=TRUE)
  
  tmp_txt <- readLines(paste0(dir.input, "/", file_path_sans_ext(fls[i]), "_scanDescription.txt"))
  tmp_txt <- substr(tmp_txt, 6, nchar(tmp_txt)-2)
  write(paste0(tmp_txt, "  "), rmd.fid, sep="\n", append=TRUE)
  write("", rmd.fid, sep="\n", append=TRUE)
  write("***", rmd.fid, sep="\n", append=TRUE)
  write("", rmd.fid, sep="\n", append=TRUE)
}
close(rmd.fid)

library(rmarkdown)
rmarkdown::render(rmd.file, "html_document")

