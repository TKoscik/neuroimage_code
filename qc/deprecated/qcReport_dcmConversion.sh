#! /bin/bash

researcher=/Shared/koscikt_scratch
project=dm1_bids
subject=119
session=60153518
site=1+2

prefix=sub-${subject}_ses-${session}_site-${site}
dir_scratch=/Shared/koscikt_scratch/dm1_qc_scratch/${prefix}

hpc_email=timothy-koscik@uiowa.edu
hpc_msgs=es
hpc_queue=CCOM,UI,PINC
hpc_pe="smp 2"

#------------------------------------------------------------------------------
dir_job=${researcher}/${project}/code/qc_job
dir_rmd=${researcher}/${project}/code/qc_rmd
dir_qc=${researcher}/${project}/qc/dcmConversion
mkdir -p ${dir_job}
mkdir -p ${dir_rmd}
mkdir -p ${dir_qc}
job_name=${dir_job}/${prefix}_qc-dcmConversion.job
rmd_name=${dir_rmd}/${prefix}_qc-dcConversion.rmd
rmd_scratch=${dir_scratch}/${prefix}_qc-dcConversion.rmd
html_name=${prefix}_qc-dcConversion.html

#-------------------------------------------------------------------------------
# Write job file
#-------------------------------------------------------------------------------
echo 'Writing Job File '${job_name}
echo '#! /bin/bash' > ${job_name}
echo '#$ -M '${hpc_email} >> ${job_name}
echo '#$ -m '${hpc_msgs} >> ${job_name}
echo '#$ -q '${hpc_queue} >> ${job_name}
echo '#$ -pe '${hpc_pe} >> ${job_name}
echo '#$ -j y' >> ${job_name}
echo '#$ -o '${researcher}/${project}'/log/hpc_output/' >> ${job_name}
echo '' >> ${job_name}
echo 'pipeline_start=$(date +%Y-%m-%dT%H:%M:%S%z)' >> ${job_name}
echo '' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo '# set up software' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo 'module load R' >> ${job_name}
echo 'r_version=(`R --version`)' >> ${job_name}
echo '' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo '# Initial Log Entry' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo 'mkdir -p '${researcher}'/'${project}'/log/hpc_output' >> ${job_name}
echo 'subject_log='${researcher}'/'${project}'/log/${prefix}.log' >> ${job_name}
echo 'echo "#--------------------------------------------------------------------------------" >> ${subject_log}' >> ${job_name}
echo 'echo "task:dicom_conversion_qc_report" >> ${subject_log}' >> ${job_name}
echo 'echo "software:R,version:"${r_version[2]} >> ${subject_log}' >> ${job_name}
echo 'echo "start:"${pipeline_start} >> ${subject_log}' >> ${job_name}
echo '' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo '# Run QC Report Generator' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo 'mkdir -p '${dir_scratch} >> ${job_name}
echo 'cp '${rmd_name} '\' >> ${job_name}
echo '  '${rmd_scratch} >> ${job_name}
echo 'Rscript -e '\''library(rmarkdown); rmarkdown::render("'${rmd_scratch}'", "html_document")'\' >> ${job_name}
echo 'mv '${dir_scratch}/${html_name} '\' >> ${job_name}
echo '  '${dir_qc} >> ${job_name}
echo 'rm -rf '${dir_scratch} >> ${job_name}
echo '' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo '# End of Script' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo 'chgrp -R ${group} '${researcher}'/'${project}'/code > /dev/null 2>&1' >> ${job_name}
echo 'chgrp -R ${group} '${researcher}'/'${project}'/qc > /dev/null 2>&1' >> ${job_name}
echo 'chmod -R g+rw '${researcher}'/'${project}'/code > /dev/null 2>&1' >> ${job_name}
echo 'chmod -R g+rw '${researcher}'/'${project}'/qc > /dev/null 2>&1' >> ${job_name}
echo '' >> ${job_name}
echo 'date +"end: %Y-%m-%dT%H:%M:%S%z" >> ${subject_log}' >> ${job_name}
echo 'echo "#--------------------------------------------------------------------------------" >> ${subject_log}' >> ${job_name}
echo 'echo '' >> ${subject_log}' >> ${job_name}
echo '' >> ${job_name}

#-------------------------------------------------------------------------------
# Write RMD file
#-------------------------------------------------------------------------------
echo 'Writing RMD File '${rmd_name}
echo '---' > ${rmd_name}
echo 'output: html_document' >> ${rmd_name}
echo '---' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r setup, include=FALSE}' >> ${rmd_name}
echo 'rm(list=ls())' >> ${rmd_name}
echo 'gc()' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'knitr::opts_chunk$set(echo = FALSE)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'pkg.ls <- c("nifti.io", "htmltools", "R.utils",' >> ${rmd_name}
echo '            "ggplot2", "reshape2", "gridExtra", "grid")' >> ${rmd_name}
echo 'for (i in pkg.ls) { eval(parse(text=sprintf("library(%s)", i))) }' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '__DICOM to NIfTI Conversion Report__  ' >> ${rmd_name}
echo 'Inc, `r format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")`  ' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'Researcher: __'${researcher}'__  ' >> ${rmd_name}
echo 'Project: __'${project}'__  ' >> ${rmd_name}
echo 'Participant: __sub-'${subject}'__  ' >> ${rmd_name}
echo 'Session: __ses-'${session}'__  ' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{bash}' >> ${rmd_name}
echo 'tree -f '${researcher}'/'${project}'/nifti/sub-'${subject}'/ses-'${session}' \' >> ${rmd_name}
echo '  -H '${dir_scratch}'/'${prefix}'_nifti-tree.html \' >> ${rmd_name}
echo '  -o '${dir_scratch}'/'${prefix}'_nifti-tree.html \' >> ${rmd_name}
echo '  -T "" --nolinks --noreport' >> ${rmd_name}
echo "sed -i '31d' "${dir_scratch}"/"${prefix}"_nifti-tree.html" >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'for i in {1..13}; do' >> ${rmd_name}
echo "  sed -i '"'$d'"' "${dir_scratch}"/"${prefix}"_nifti-tree.html" >> ${rmd_name}
echo 'done' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'echo "</body>" >> '${dir_scratch}'/'${prefix}'_nifti-tree.html' >> ${rmd_name}
echo 'echo "</html>" >> '${dir_scratch}'/'${prefix}'_nifti-tree.html' >> ${rmd_name}
echo 'echo "" >> '${dir_scratch}'/'${prefix}'_nifti-tree.html' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'cp '${researcher}'/'${project}'/nifti/sub-'${subject}'/ses-'${session}'/anat/*.nii.gz \' >> ${rmd_name}
echo '  '${dir_scratch}'/' >> ${rmd_name}
echo 'cp '${researcher}'/'${project}'/nifti/sub-'${subject}'/ses-'${session}'/dwi/*.nii.gz \' >> ${rmd_name}
echo '  '${dir_scratch}'/' >> ${rmd_name}
echo 'cp '${researcher}'/'${project}'/nifti/sub-'${subject}'/ses-'${session}'/func/*.nii.gz \' >> ${rmd_name}
echo '  '${dir_scratch}'/' >> ${rmd_name}
echo 'cp '${researcher}'/'${project}'/nifti/sub-'${subject}'/ses-'${session}'/fmap/*.nii.gz \' >> ${rmd_name}
echo '  '${dir_scratch}'/' >> ${rmd_name}
echo 'gunzip '${dir_scratch}'/*.nii.gz' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo ${researcher}'/'${project}'/nifti/sub-'${subject}'/ses-'${session}'  ' >> ${rmd_name}
echo '```{r}' >> ${rmd_name}
echo 'includeHTML("'${dir_scratch}'/'${prefix}'_nifti-tree.html")' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r}' >> ${rmd_name}
echo 'nii.dir <- "'${researcher}'/'${project}'/nifti/sub-'${subject}'/ses-'${session}'"' >> ${rmd_name}
echo 'img.dir <- "'${dir_scratch}'"' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'nii.ls <- c(list.files(paste0(nii.dir, "/anat"), pattern=".nii.gz"),' >> ${rmd_name}
echo '            list.files(paste0(nii.dir, "/dwi"), pattern=".nii.gz"),' >> ${rmd_name}
echo '            list.files(paste0(nii.dir, "/func"), pattern=".nii.gz"),' >> ${rmd_name}
echo '            list.files(paste0(nii.dir, "/fmap"), pattern=".nii.gz"))' >> ${rmd_name}
echo 'img.ls <- list.files(img.dir, pattern="nii")' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'mod.ls <- rev(c("T1w", "T2w", "FLAIR", "PD", "T1rho", "swi", "T2map", "T2star", "dwi", "bold", "fieldmap", "phase", "magnitude"))' >> ${rmd_name}
echo 'for (i in mod.ls) {' >> ${rmd_name}
echo '  reorder <- grep(i, nii.ls)' >> ${rmd_name}
echo '  if (length(reorder) != 0) { nii.ls <- c(nii.ls[reorder], nii.ls[-reorder]) }' >> ${rmd_name}
echo '  reorder <- grep(i, img.ls)' >> ${rmd_name}
echo '  if (length(reorder) != 0) { img.ls <- c(img.ls[reorder], img.ls[-reorder]) }' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r fig.height=3, fig.width=9}' >> ${rmd_name}
echo 'theme.obj <- theme(plot.title = element_blank(),' >> ${rmd_name}
echo '                     legend.position="none",' >> ${rmd_name}
echo '                     legend.title = element_blank(),' >> ${rmd_name}
echo '                     legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '                     axis.title=element_blank(),' >> ${rmd_name}
echo '                     axis.text=element_blank(),' >> ${rmd_name}
echo '                     axis.ticks=element_blank(),' >> ${rmd_name}
echo '                     plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '                     plot.background=element_blank(),' >> ${rmd_name}
echo '                     panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '                     panel.grid=element_blank(),' >> ${rmd_name}
echo '                     panel.border=element_blank(),' >> ${rmd_name}
echo '                     panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '                     panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '                     plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '                     legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '                     panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'for (i in 1:length(img.ls)) {' >> ${rmd_name}
echo '  bg.nii <- sprintf("%s/%s", img.dir, img.ls[i])' >> ${rmd_name}
echo '  img.dims <- nii.dims(bg.nii)' >> ${rmd_name}
echo '  coords <- c(round(img.dims[1]/5*2), round(img.dims[2:3]/2))' >> ${rmd_name}
echo '  volume <- read.nii.volume(bg.nii, 1)' >> ${rmd_name}
echo '  x <- melt(volume[coords[1], , ])' >> ${rmd_name}
echo '  y <- melt(volume[ , coords[2], ])' >> ${rmd_name}
echo '  z <- melt(volume[ , , coords[3]])' >> ${rmd_name}
echo '  ' >> ${rmd_name}
echo '  pixdim <- unlist(nii.hdr(bg.nii, "pixdim"))[2:4]' >> ${rmd_name}
echo '  ' >> ${rmd_name}
echo '  plot.x <- ggplot() +' >> ${rmd_name}
echo '    theme_bw() +' >> ${rmd_name}
echo '    coord_fixed(ratio=pixdim[3]/pixdim[2],expand=FALSE, clip="off") +' >> ${rmd_name}
echo '    geom_raster(data=x, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '    scale_fill_gradientn(colors=c("#000000", "#ffffff")) +' >> ${rmd_name}
echo '    theme.obj' >> ${rmd_name}
echo '  plot.y <- ggplot() +' >> ${rmd_name}
echo '    theme_bw() +' >> ${rmd_name}
echo '    coord_fixed(ratio=pixdim[3]/pixdim[1],expand=FALSE, clip="off") +' >> ${rmd_name}
echo '    geom_raster(data=y, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '    scale_fill_gradientn(colors=c("#000000", "#ffffff")) +' >> ${rmd_name}
echo '    theme.obj' >> ${rmd_name}
echo '  plot.z <- ggplot() +' >> ${rmd_name}
echo '    theme_bw() +' >> ${rmd_name}
echo '    coord_fixed(ratio=pixdim[2]/pixdim[1],expand=FALSE, clip="off") +' >> ${rmd_name}
echo '    geom_raster(data=z, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '    scale_fill_gradientn(colors=c("#000000", "#ffffff")) +' >> ${rmd_name}
echo '    theme.obj' >> ${rmd_name}
echo '  grid.arrange(plot.x, plot.y, plot.z, nrow=1, top=nii.ls[i], clip=T, respect=T, padding=unit(1,"lines"))' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '' >> ${rmd_name}

qsub ${job_name}

