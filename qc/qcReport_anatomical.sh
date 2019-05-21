#! /bin/bash

researcher=/Shared/harshmanl
project=ckd_bids
group=Research-harshmanlab
subject=CKD02
session=2pnytnt0zp
site=00100
image=corMPRAGE_T1w
image_type=T1w
space=HCPICBM
template=1mm

hpc_email=timothy-koscik@uiowa.edu
hpc_msgs=es
hpc_queue=CCOM,UI,PINC
hpc_pe="smp 8"
nimg_core_root=/Shared/nopoulos/nimg_core

prefix=sub-${subject}_ses-${session}_site-${site}

#-------------------------------------------------------------------------------
dir_job=${researcher}/${project}/code/qc_job
mkdir -p ${dir_job}
job_name=${dir_job}/${prefix}_img-${image}_qc.job

dir_rmd=${researcher}/${project}/code/qc_rmd
mkdir -p ${dir_rmd}
rmd_name=${dir_rmd}/${prefix}_img-${image}_qc.rmd

pdf_name=${prefix}_img-${image}_qc.pdf

dir_scratch=${researcher}/${project}/scratch

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
echo 'r_version=(`R --version`)' >> ${job_name}
echo 'source /Shared/pinc/sharedopt/apps/sourcefiles/afni_source.sh' >> ${job_name}
echo 'afni_version=${AFNIDIR##*/}' >> ${job_name}
echo '' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo '# Specify Analysis Variables' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo 'researcher='${researcher} >> ${job_name}
echo 'project='${project} >> ${job_name}
echo 'group='${group} >> ${job_name}
echo 'subject='${subject} >> ${job_name}
echo 'session='${session} >> ${job_name}
echo 'site='${site} >> ${job_name}
echo 'image='${image} >> ${job_name}
echo 'image_type='${image_type} >> ${job_name}
echo 'space='${space} >> ${job_name}
echo 'template='${template} >> ${job_name}
echo '' >> ${job_name}
echo 'prefix='${prefix} >> ${job_name}
echo '' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo '# Initial Log Entry' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo 'mkdir -p ${researcher}/${project}/log/hpc_output' >> ${job_name}
echo 'subject_log=${researcher}/${project}/log/${prefix}.log' >> ${job_name}
echo 'echo "#--------------------------------------------------------------------------------" >> ${subject_log}' >> ${job_name}
echo 'echo "task: anatomical_qc_report" >> ${subject_log}' >> ${job_name}
echo 'echo "software: R" >> ${subject_log}' >> ${job_name}
echo 'echo "version: "${r_version[2]} >> ${subject_log}' >> ${job_name}
echo 'echo "software: AFNI" >> ${subject_log}' >> ${job_name}
echo 'echo "version: "${afni_version} >> ${subject_log}' >> ${job_name}
echo 'echo "start_time: "${pipeline_start} >> ${subject_log}' >> ${job_name}
echo '' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo '# Run QC Report Generator' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo 'Rscript -e '\''library(rmarkdown); rmarkdown::render("'${rmd_name}'", "html_document")'\' >> ${job_name}
echo '' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo '# End of Script' >> ${job_name}
echo '#------------------------------------------------------------------------------' >> ${job_name}
echo 'chgrp -R ${group} ${researcher}/${project}/derivatives' >> ${job_name}
echo 'chmod -R g+rw ${researcher}/${project}/derivatives' >> ${job_name}
echo '' >> ${job_name}
echo 'date +"end_time: %Y-%m-%dT%H:%M:%S%z" >> ${subject_log}' >> ${job_name}
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
echo 'knitr::opts_chunk$set(echo=FALSE, warning=FALSE, message=FALSE, error=FALSE)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '# Inputs ----' >> ${rmd_name}
echo 'researcher <- "'${researcher}'"' >> ${rmd_name}
echo 'project <- "'${project}'"' >> ${rmd_name}
echo 'subject <- "sub-'${subject}'"' >> ${rmd_name}
echo 'session <- "ses-'${session}'"' >> ${rmd_name}
echo 'site <- "site-'${site}'"' >> ${rmd_name}
echo 'image <- "'${image}'"' >> ${rmd_name}
echo 'image.type <- "'${image_type}'"' >> ${rmd_name}
echo 'space <- "'${space}'"' >> ${rmd_name}
echo 'template <- "'${template}'"' >> ${rmd_name}
echo 'img.source <- "acq-'${image}'"' >> ${rmd_name}
echo 'img.mod <- "'${image_type}'"' >> ${rmd_name}
echo 'scratch.dir <- "'${dir_scratch}'"' >> ${rmd_name}
echo 'nimg.root <- "'${nimg_core_root}'"' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r}' >> ${rmd_name}
echo 'library(nifti.qc)' >> ${rmd_name}
echo 'library(nifti.io)' >> ${rmd_name}
echo 'library(nifti.draw)' >> ${rmd_name}
echo 'library(R.utils)' >> ${rmd_name}
echo 'library(ggplot2)' >> ${rmd_name}
echo 'library(viridis)' >> ${rmd_name}
echo 'library(reshape2)' >> ${rmd_name}
echo 'library(gridExtra)' >> ${rmd_name}
echo 'library(grid)' >> ${rmd_name}
echo 'library(raster)' >> ${rmd_name}
echo 'library(rgeos)' >> ${rmd_name}
echo 'library(moments)' >> ${rmd_name}
echo 'library(OpenImageR)' >> ${rmd_name}
echo 'library(kableExtra)' >> ${rmd_name}
echo 'library(GenKern)' >> ${rmd_name}
echo 'library(fitdistrplus)' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '__Anatomical Preprocessing Report__  ' >> ${rmd_name}
echo 'INC, `r format(Sys.time(), "%Y-%m-%d %H:%M:%S-%z")`  ' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'Researcher: __'${researcher}'__  ' >> ${rmd_name}
echo 'Project: __'${project}'__  ' >> ${rmd_name}
echo 'Participant: __sub-'${subject}'__  ' >> ${rmd_name}
echo 'Session: __ses-'${session}'__  ' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '<font size="1"> _Raw Image:_ '${researcher}'/'${project}'/nifti/sub-'${subject}'/ses-'${session}'/anat/'${prefix}'_acq-'${image}'.nii.gz</font>  ' >> ${rmd_name}
echo '<font size="1"> _Processed Native:_ '${researcher}'/'${project}'/derivatives/anat/native/'${prefix}'_'${image_type}'.nii.gz</font>  ' >> ${rmd_name}
echo '<font size="1"> _Processed Normalized:_ '${researcher}'/'${project}'/derivatives/anat/reg_'${space}'_'${template}'/'${prefix}'_reg-'${space}'+'${template}'_'${image_type}'.nii.gz</font>  ' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Gather Images}' >> ${rmd_name}
echo '# gather needed images' >> ${rmd_name}
echo 'source.file <- paste0(researcher, "/", project, "/nifti/", subject, "/", session, "/anat/", subject, "_", session, "_", site, "_", img.source, ".nii.gz")' >> ${rmd_name}
echo 'img.rigid <- paste0(scratch.dir, "/", subject, "_", session, "_rigid.nii")' >> ${rmd_name}
echo 'img.native <- paste0(scratch.dir, "/", subject, "_", session, "_native.nii")' >> ${rmd_name}
echo 'img.template <- paste0(scratch.dir, "/", subject, "_", session, "_template.nii")' >> ${rmd_name}
echo 'mask.air <- paste0(scratch.dir, "/", subject, "_", session, "_mask-air.nii")' >> ${rmd_name}
echo 'mask.brain <- paste0(scratch.dir, "/", subject, "_", session, "_mask-brain.nii")' >> ${rmd_name}
echo 'mask.brain.reg <- paste0(scratch.dir, "/", subject, "_", session, "_mask-brain-reg.nii")' >> ${rmd_name}
echo 'seg.label <- paste0(scratch.dir, "/", subject, "_", session, "_seg-label.nii")' >> ${rmd_name}
echo 'prob.csf <- paste0(scratch.dir, "/", subject, "_", session, "_seg-CSF.nii")' >> ${rmd_name}
echo 'prob.gm <- paste0(scratch.dir, "/", subject, "_", session, "_seg-GM.nii")' >> ${rmd_name}
echo 'prob.wm <- paste0(scratch.dir, "/", subject, "_", session, "_seg-WM.nii")' >> ${rmd_name}
echo 'img.noise <- paste0(scratch.dir, "/", subject, "_", session, "_noise.nii")' >> ${rmd_name}
echo 'img.biast1t2 <- paste0(scratch.dir, "/", subject, "_", session, "_biasFieldT1T2.nii")' >> ${rmd_name}
echo 'img.biasn4 <- paste0(scratch.dir, "/", subject, "_", session, "_biasFieldN4.nii")' >> ${rmd_name}
echo 'img.art.rigid <- paste0(scratch.dir, "/", subject, "_", session, "_artRigid.nii")' >> ${rmd_name}
echo 'img.art.native <- paste0(scratch.dir, "/", subject, "_", session, "_artNative.nii")' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r unzip files}' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/prep/", subject, "/", session, "/", subject, "_", session, "_", site, "_", img.source, "_prep-rigid.nii.gz"), destname=img.rigid, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/native/", subject, "_", session, "_", site, "_", img.mod, ".nii.gz"), destname=img.native, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/mask/", subject, "_", session, "_", site, "_mask-air.nii.gz"), destname=mask.air, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/mask/", subject, "_", session, "_", site, "_mask-brain.nii.gz"), destname=mask.brain, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(nimg.root, "/templates_human/", space, "/", template, "/", space, "_", template, "_", img.mod, ".nii.gz"), destname=img.template, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/reg_", space, "_", template, "/", subject, "_", session, "_", site, "_reg-", space, "+", template, "_T1w_brain.nii.gz"), destname=mask.brain.reg, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/segmentation/", subject, "_", session, "_", site, "_seg-label.nii.gz"), destname=seg.label, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/segmentation/", subject, "_", session, "_", site, "_seg-CSF.nii.gz"), destname=prob.csf, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/segmentation/", subject, "_", session, "_", site, "_seg-GM.nii.gz"), destname=prob.gm, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/segmentation/", subject, "_", session, "_", site, "_seg-WM.nii.gz"), destname=prob.wm, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/prep/", subject, "/", session, "/", subject, "_", session, "_", site, "_", img.source, "_prep-noise.nii.gz"), destname=img.noise, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/prep/", subject, "/", session, "/", subject, "_", session, "_", site, "_prep-biasFieldT1T2.nii.gz"), destname=img.biast1t2, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo 'gunzip(filename=paste0(researcher, "/", project, "/derivatives/anat/prep/", subject, "/", session, "/", subject, "_", session, "_", site, "_", img.mod, "_prep-biasFieldN4.nii.gz"), destname=img.biasn4, remove=FALSE, overwrite=TRUE)' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r WholeBrain QC}' >> ${rmd_name}
echo 'wbf <- data.frame(' >> ${rmd_name}
echo '  Metric = c("SNR", "SNR.D", "CNR", "QI.1", "QI.2", "CJV",' >> ${rmd_name}
echo '             "FWHM.average", "FWHM.x", "FWHM.y", "FWHM.z",' >> ${rmd_name}
echo '             "EFC", "FBER", "WM.to.MAX"),' >> ${rmd_name}
echo '  Raw.Value=numeric(13),' >> ${rmd_name}
echo '  Clean.Value=numeric(13))' >> ${rmd_name}
echo 'var.num <- 0' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- nii.qc.snr(' >> ${rmd_name}
echo '  img.nii=img.rigid, img.vol=1,' >> ${rmd_name}
echo '  mask.nii=mask.brain, mask.vol=1, mask.dir="gt", mask.thresh=0)' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- nii.qc.snr(' >> ${rmd_name}
echo '  img.nii=img.native, img.vol=1,' >> ${rmd_name}
echo '  mask.nii=mask.brain, mask.vol=1, mask.dir="gt", mask.thresh=0)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- nii.qc.snrd(' >> ${rmd_name}
echo '  img.nii=img.rigid, img.vol=1,' >> ${rmd_name}
echo '  mask.nii=mask.brain, mask.vol=1, mask.dir="gt", mask.thresh=0,' >> ${rmd_name}
echo '  air.nii=mask.air, air.vol=1, air.dir="eq", air.thresh=1)' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- nii.qc.snrd(' >> ${rmd_name}
echo '  img.nii=img.native, img.vol=1,' >> ${rmd_name}
echo '  mask.nii=mask.brain, mask.vol=1, mask.dir="gt", mask.thresh=0,' >> ${rmd_name}
echo '  air.nii=mask.air, air.vol=1, air.dir="eq", air.thresh=1)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- nii.qc.cnr(img.nii=img.rigid, img.vol=1,' >> ${rmd_name}
echo '  gm.nii=seg.label, gm.vol=1, gm.dir="eq", gm.thresh=2,' >> ${rmd_name}
echo '  wm.nii=seg.label, wm.vol=1, wm.dir="eq", wm.thresh=3,' >> ${rmd_name}
echo '  air.nii=mask.air, air.vol=1, air.dir="eq", air.thresh=1)' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- nii.qc.cnr(img.nii=img.native, img.vol=1,' >> ${rmd_name}
echo '  gm.nii=seg.label, gm.vol=1, gm.dir="eq", gm.thresh=2,' >> ${rmd_name}
echo '  wm.nii=seg.label, wm.vol=1, wm.dir="eq", wm.thresh=3,' >> ${rmd_name}
echo '  air.nii=mask.air, air.vol=1, air.dir="eq", air.thresh=1)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'invisible(nii.qc.artefacts(' >> ${rmd_name}
echo '  img.nii=img.rigid, img.vol=1L,' >> ${rmd_name}
echo '  air.nii=mask.air, air.vol=1L, air.dir="eq", air.thresh=1,' >> ${rmd_name}
echo '  save.dir=scratch.dir, file.name=paste0(subject, "_", session, "_artRigid.nii")))' >> ${rmd_name}
echo 'qi <- nii.qc.mortamet(' >> ${rmd_name}
echo '  img.nii=img.rigid, img.vol=1L,' >> ${rmd_name}
echo '  air.nii=mask.air, air.vol=1L, air.dir="eq", air.thresh=1,' >> ${rmd_name}
echo '  art.nii=img.art.rigid, art.vol=1L, art.dir="eq", art.thresh=1)' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- qi$qi1' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- NA' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- qi$qi2' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- NA' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- nii.qc.cjv(' >> ${rmd_name}
echo '  img.nii=img.rigid, img.vol=1L,' >> ${rmd_name}
echo '  gm.nii=seg.label, gm.vol=1L, gm.dir="eq", gm.thresh=2,' >> ${rmd_name}
echo '  wm.nii=seg.label, wm.vol=1L, wm.dir="eq", wm.thresh=3)' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- nii.qc.cjv(' >> ${rmd_name}
echo '  img.nii=img.native, img.vol=1L,' >> ${rmd_name}
echo '  gm.nii=seg.label, gm.vol=1L, gm.dir="eq", gm.thresh=2,' >> ${rmd_name}
echo '  wm.nii=seg.label, wm.vol=1L, wm.dir="eq", wm.thresh=3)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'fwhm.rigid <- nii.qc.fwhm(img.nii=img.rigid, mask.nii=mask.brain, save.dir=scratch.dir, file.name=paste0(subject, "_", session, "_rigid.fwhm.txt"))' >> ${rmd_name}
echo 'fwhm.native <- nii.qc.fwhm(img.nii=img.native, mask.nii=mask.brain, save.dir=scratch.dir, file.name=paste0(subject, "_", session, "_native.fwhm.txt"))' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- fwhm.rigid$average' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- fwhm.native$average' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- fwhm.rigid$x' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- fwhm.native$x' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- fwhm.rigid$y' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- fwhm.native$y' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- fwhm.rigid$z' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- fwhm.native$z' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- nii.qc.efc(img.nii=img.rigid, img.vol=1L)' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- nii.qc.efc(img.nii=img.native, img.vol=1L)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- nii.qc.fber(img.nii=img.rigid, img.vol=1L, brain.mask=mask.brain, brain.vol=1L, brain.dir="gt", brain.thresh = 0)' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- nii.qc.fber(img.nii=img.native, img.vol=1L, brain.mask=mask.brain, brain.vol=1L, brain.dir="gt", brain.thresh = 0)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'var.num <- var.num + 1' >> ${rmd_name}
echo 'wbf$Raw.Value[var.num] <- nii.qc.wm2max (img.nii=img.rigid, img.vol=1L, wm.nii=seg.label, wm.vol=1L, wm.dir="eq", wm.thresh=3)' >> ${rmd_name}
echo 'wbf$Clean.Value[var.num] <- nii.qc.wm2max (img.nii=img.native, img.vol=1L, wm.nii=seg.label, wm.vol=1L, wm.dir="eq", wm.thresh=3)' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r TissueClass QC}' >> ${rmd_name}
echo 'segf <- data.frame(' >> ${rmd_name}
echo '  Metric = c("Ratio.to.Whole.Brain", "rPVe", "SNR", "SNR.D",' >> ${rmd_name}
echo '             "Mean", "SD", "Median", "MAD", "Skewness", "Kurtosis",' >> ${rmd_name}
echo '             "quantile.05", "quantile.95"),' >> ${rmd_name}
echo '  CSF=numeric(12),' >> ${rmd_name}
echo '  GM=numeric(12),' >> ${rmd_name}
echo '  WM=numeric(12))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'segf$CSF[1] <- nii.qc.volfrac(' >> ${rmd_name}
echo '  whole.nii=seg.label, whole.vol=1L, whole.dir="gt", whole.thresh=1,' >> ${rmd_name}
echo '  part.nii=seg.label, part.vol=1L, part.dir="eq", part.thresh=1)' >> ${rmd_name}
echo 'segf$GM[1] <- nii.qc.volfrac(' >> ${rmd_name}
echo '  whole.nii=seg.label, whole.vol=1L, whole.dir="gt", whole.thresh=1,' >> ${rmd_name}
echo '  part.nii=seg.label, part.vol=1L, part.dir="eq", part.thresh=2)' >> ${rmd_name}
echo 'segf$WM[1] <- nii.qc.volfrac(' >> ${rmd_name}
echo '  whole.nii=seg.label, whole.vol=1L, whole.dir="gt", whole.thresh=1,' >> ${rmd_name}
echo '  part.nii=seg.label, part.vol=1L, part.dir="eq", part.thresh=3)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'segf$CSF[2] <- nii.qc.rpve(tissue.prob=prob.csf, tissue.vol=1L)' >> ${rmd_name}
echo 'segf$GM[2] <- nii.qc.rpve(tissue.prob=prob.gm, tissue.vol=1L)' >> ${rmd_name}
echo 'segf$WM[2] <- nii.qc.rpve(tissue.prob=prob.wm, tissue.vol=1L)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'segf$CSF[3] <- nii.qc.snr(img.nii=img.native, img.vol=1L, mask.nii=seg.label, mask.vol=1L, mask.dir="eq", mask.thresh=1)' >> ${rmd_name}
echo 'segf$GM[3] <- nii.qc.snr(img.nii=img.native, img.vol=1L, mask.nii=seg.label, mask.vol=1L, mask.dir="eq", mask.thresh=2)' >> ${rmd_name}
echo 'segf$WM[3] <- nii.qc.snr(img.nii=img.native, img.vol=1L, mask.nii=seg.label, mask.vol=1L, mask.dir="eq", mask.thresh=3)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'segf$CSF[4] <- nii.qc.snrd(img.nii=img.native, img.vol=1L, mask.nii=seg.label, mask.vol=1L, mask.dir="eq", mask.thresh=1, air.nii=mask.air, air.vol=1L, air.dir="eq", air.thresh=1)' >> ${rmd_name}
echo 'segf$GM[4] <- nii.qc.snrd(img.nii=img.native, img.vol=1L, mask.nii=seg.label, mask.vol=1L, mask.dir="eq", mask.thresh=2, air.nii=mask.air, air.vol=1L, air.dir="eq", air.thresh=1)' >> ${rmd_name}
echo 'segf$WM[4] <- nii.qc.snrd(img.nii=img.native, img.vol=1L, mask.nii=seg.label, mask.vol=1L, mask.dir="eq", mask.thresh=3, air.nii=mask.air, air.vol=1L, air.dir="eq", air.thresh=1)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'segf$CSF[5:12] <- as.numeric(nii.qc.descriptive(img.nii=img.native, img.vol=1L, mask.nii=seg.label, mask.vol=1L, mask.dir="eq", mask.thresh=1)$stats)' >> ${rmd_name}
echo 'segf$GM[5:12] <- as.numeric(nii.qc.descriptive(img.nii=img.native, img.vol=1L, mask.nii=seg.label, mask.vol=1L, mask.dir="eq", mask.thresh=2)$stats)' >> ${rmd_name}
echo 'segf$WM[5:12] <- as.numeric(nii.qc.descriptive(img.nii=img.native, img.vol=1L, mask.nii=seg.label, mask.vol=1L, mask.dir="eq", mask.thresh=3)$stats)' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r WB plot}' >> ${rmd_name}
echo 'inc.norms.wb <- read.csv(paste0(nimg.root, "/qc_norms/inc_'${image_type}'_wb.csv"), as.is=TRUE)' >> ${rmd_name}
echo 'if (source.file %in% inc.norms.wb$input.image) {' >> ${rmd_name}
echo '  inc.norms.wb[which(source.file == inc.norms.wb$input.image)[1], 3:15] <- as.matrix(t(wbf)[2,])' >> ${rmd_name}
echo '  inc.norms.wb[which(source.file == inc.norms.wb$input.image)[2], 3:15] <- as.matrix(t(wbf)[3,])' >> ${rmd_name}
echo '} else {' >> ${rmd_name}
echo '  tf <- data.frame(input.image = rep(source.file, 2),' >> ${rmd_name}
echo '                   Value = c("Raw", "Clean"),' >> ${rmd_name}
echo '                   SNR=as.numeric(wbf[1,2:3]),' >> ${rmd_name}
echo '                   SNR.D=as.numeric(wbf[2,2:3]),' >> ${rmd_name}
echo '                   CNR=as.numeric(wbf[3,2:3]),' >> ${rmd_name}
echo '                   QI.1=as.numeric(wbf[4,2:3]),' >> ${rmd_name}
echo '                   QI.2=as.numeric(wbf[5,2:3]),' >> ${rmd_name}
echo '                   CJV=as.numeric(wbf[6,2:3]),' >> ${rmd_name}
echo '                   FWHM.average=as.numeric(wbf[7,2:3]),' >> ${rmd_name}
echo '                   FWHM.x=as.numeric(wbf[8,2:3]),' >> ${rmd_name}
echo '                   FWHM.y=as.numeric(wbf[9,2:3]),' >> ${rmd_name}
echo '                   FWHM.z=as.numeric(wbf[10,2:3]),' >> ${rmd_name}
echo '                   EFC=as.numeric(wbf[11,2:3]),' >> ${rmd_name}
echo '                   FBER=as.numeric(wbf[12,2:3]),' >> ${rmd_name}
echo '                   WM.to.MAX=as.numeric(wbf[13,2:3]))' >> ${rmd_name}
echo '  inc.norms.wb <- rbind(inc.norms.wb, tf)' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo 'write.table(x=inc.norms.wb, file=paste0(nimg.root, "/qc_norms/inc_'${image_type}'_wb.csv"),' >> ${rmd_name}
echo '            row.names = FALSE, col.names=TRUE, quote = FALSE, sep = ",")' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'norm.vals <- read.csv(paste0(nimg.root, "/qc_norms/inc_'${image_type}'_wb.csv"), as.is=TRUE)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plotf <- wbf' >> ${rmd_name}
echo 'colnames(plotf) <- c("Metric", "Raw", "Clean")' >> ${rmd_name}
echo 'plotf <- melt(plotf, id.vars="Metric")' >> ${rmd_name}
echo 'plotf$lower <- numeric(nrow(plotf))*NA' >> ${rmd_name}
echo 'plotf$upper <- numeric(nrow(plotf))*NA' >> ${rmd_name}
echo 'plotf$norm <- numeric(nrow(plotf))' >> ${rmd_name}
echo 'for (i in 1:nrow(plotf)) {' >> ${rmd_name}
echo '  if (!is.na(plotf$value[i])) {' >> ${rmd_name}
echo '  norm.m <- mean(norm.vals[(norm.vals$Value==plotf$variable[i]), which(colnames(norm.vals)==plotf$Metric[i])])' >> ${rmd_name}
echo '  norm.sd <- sd(norm.vals[(norm.vals$Value==plotf$variable[i]), which(colnames(norm.vals)==plotf$Metric[i])])' >> ${rmd_name}
echo '  iqr <- IQR(norm.vals[(norm.vals$Value==plotf$variable[i]), which(colnames(norm.vals)==plotf$Metric[i])])' >> ${rmd_name}
echo '  plotf$value[i] <- (plotf$value[i] - norm.m) /norm.sd' >> ${rmd_name}
echo '  plotf$lower[i] <- (-iqr) / norm.sd' >> ${rmd_name}
echo '  plotf$upper[i] <- (iqr) / norm.sd' >> ${rmd_name}
echo '  }' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plotf$ok <- factor(((plotf$value > plotf$lower) & (plotf$value < plotf$upper))*1, levels=c(0,1,NA), labels=c("Check", "OK"))' >> ${rmd_name}
echo 'plotf$Metric <- factor(plotf$Metric, levels=c("WM.to.MAX", "FBER", "EFC", "FWHM.z", "FWHM.y", "FWHM.x", "FWHM.average", "CJV", "QI.2", "QI.1", "CNR", "SNR.D", "SNR"))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'if (!("Check" %in% plotf$ok)) {' >> ${rmd_name}
echo '  ok.colors <- "#64a8ff"' >> ${rmd_name}
echo '} else if (!("OK" %in% plotf$ok)) {' >> ${rmd_name}
echo '  ok.colors <- "#ff0000"' >> ${rmd_name}
echo '} else {' >> ${rmd_name}
echo '  ok.colors <- c("#ff0000", "#64a8ff")' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot1 <- ggplot(plotf, aes(x=Metric)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  geom_pointrange(aes(y=norm, ymin=lower, ymax=upper, group=variable, color=variable),' >> ${rmd_name}
echo '                  position=position_dodge(width=0.3), shape=124, size=1,' >> ${rmd_name}
echo '                  show.legend = FALSE) +' >> ${rmd_name}
echo '  scale_shape_manual(values=c(21,23)) +' >> ${rmd_name}
echo '  scale_color_manual(values=c("#a8a8a8", "#000000"), guide="none") +' >> ${rmd_name}
echo '  scale_fill_manual(values=ok.colors, guide="none") +' >> ${rmd_name}
echo '  geom_point(aes(y=value, shape=variable, group=variable, fill=ok),' >> ${rmd_name}
echo '             size=2, position=position_dodge(width=0.3)) +' >> ${rmd_name}
echo '  coord_flip() +' >> ${rmd_name}
echo '  labs(subtitle="Whole Brain", x="", y="Z-Score") +' >> ${rmd_name}
echo '  theme(legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.position = "bottom",' >> ${rmd_name}
echo '        legend.direction = "horizontal",' >> ${rmd_name}
echo '        legend.background = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8),' >> ${rmd_name}
echo '        plot.title = element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10),' >> ${rmd_name}
echo '        axis.title = element_text(size=10),' >> ${rmd_name}
echo '        axis.text.x = element_text(size=8),' >> ${rmd_name}
echo '        axis.text.y = element_text(size=8),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Seg plot}' >> ${rmd_name}
echo 'inc.norms.seg <- read.csv(paste0(nimg.root, "/qc_norms/inc_'${image_type}'_seg.csv"), as.is=TRUE)' >> ${rmd_name}
echo 'if (source.file %in% inc.norms.seg$input.image) {' >> ${rmd_name}
echo '  inc.norms.seg[which(source.file == inc.norms.seg$input.image)[1], 3:14] <- as.matrix(t(segf)[2,])' >> ${rmd_name}
echo '  inc.norms.seg[which(source.file == inc.norms.seg$input.image)[2], 3:14] <- as.matrix(t(segf)[3,])' >> ${rmd_name}
echo '  inc.norms.seg[which(source.file == inc.norms.seg$input.image)[3], 3:14] <- as.matrix(t(segf)[4,])' >> ${rmd_name}
echo '} else {' >> ${rmd_name}
echo '  tf <- data.frame(input.image = rep(source.file, 3),' >> ${rmd_name}
echo '                   Tissue = c("CSF", "GM", "WM"),' >> ${rmd_name}
echo '                   Ratio.to.Whole.Brain = as.numeric(segf[1, 2:4]),' >> ${rmd_name}
echo '                   rPVe = as.numeric(segf[2, 2:4]),' >> ${rmd_name}
echo '                   SNR = as.numeric(segf[3, 2:4]),' >> ${rmd_name}
echo '                   SNR.D = as.numeric(segf[4, 2:4]),' >> ${rmd_name}
echo '                   Mean = as.numeric(segf[5, 2:4]),' >> ${rmd_name}
echo '                   SD = as.numeric(segf[6, 2:4]),' >> ${rmd_name}
echo '                   Median = as.numeric(segf[7, 2:4]),' >> ${rmd_name}
echo '                   MAD = as.numeric(segf[8, 2:4]),' >> ${rmd_name}
echo '                   Skewness = as.numeric(segf[9, 2:4]),' >> ${rmd_name}
echo '                   Kurtosis = as.numeric(segf[10, 2:4]),' >> ${rmd_name}
echo '                   quantile.05 = as.numeric(segf[11, 2:4]),' >> ${rmd_name}
echo '                   quantile.95 = as.numeric(segf[12, 2:4]))' >> ${rmd_name}
echo '  inc.norms.seg <- rbind(inc.norms.seg, tf)' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo 'write.table(x=inc.norms.seg, file=paste0(nimg.root, "/qc_norms/inc_'${image_type}'_seg.csv"),' >> ${rmd_name}
echo '            row.names = FALSE, col.names=TRUE, quote = FALSE, sep = ",")' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'norm.vals <- read.csv(paste0(nimg.root, "/qc_norms/inc_'${image_type}'_seg.csv"), as.is=TRUE)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plotf <- segf' >> ${rmd_name}
echo 'plotf <- melt(plotf, id.vars="Metric")' >> ${rmd_name}
echo 'plotf$lower <- numeric(nrow(plotf))*NA' >> ${rmd_name}
echo 'plotf$upper <- numeric(nrow(plotf))*NA' >> ${rmd_name}
echo 'plotf$norm <- numeric(nrow(plotf))' >> ${rmd_name}
echo 'for (i in 1:nrow(plotf)) {' >> ${rmd_name}
echo '  if (!is.na(plotf$value[i])) {' >> ${rmd_name}
echo '  norm.m <- mean(norm.vals[(norm.vals$Tissue==plotf$variable[i]), which(colnames(norm.vals)==plotf$Metric[i])])' >> ${rmd_name}
echo '  norm.sd <- sd(norm.vals[(norm.vals$Tissue==plotf$variable[i]), which(colnames(norm.vals)==plotf$Metric[i])])' >> ${rmd_name}
echo '  iqr <- IQR(norm.vals[(norm.vals$Tissue==plotf$variable[i]), which(colnames(norm.vals)==plotf$Metric[i])])' >> ${rmd_name}
echo '  plotf$value[i] <- (plotf$value[i] - norm.m) /norm.sd' >> ${rmd_name}
echo '  plotf$lower[i] <- (-iqr) / norm.sd' >> ${rmd_name}
echo '  plotf$upper[i] <- (iqr) / norm.sd' >> ${rmd_name}
echo '  }' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plotf$ok <- factor(((plotf$value > plotf$lower) & (plotf$value < plotf$upper))*1, levels=c(0,1, NA), labels=c("Check", "OK"))' >> ${rmd_name}
echo 'plotf$Metric <- factor(plotf$Metric, levels=c("quantile.95", "quantile.05", "Kurtosis", "Skewness", "MAD", "Median", "SD", "Mean", "rPVe", "Ratio.to.Whole.Brain", "SNR.D", "SNR"))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'if (!("Check" %in% plotf$ok)) {' >> ${rmd_name}
echo '  ok.colors <- "#64a8ff"' >> ${rmd_name}
echo '} else if (!("OK" %in% plotf$ok)) {' >> ${rmd_name}
echo '  ok.colors <- "#ff0000"' >> ${rmd_name}
echo '} else {' >> ${rmd_name}
echo '  ok.colors <- c("#ff0000", "#64a8ff")' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot2 <- ggplot(plotf, aes(x=Metric)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  geom_pointrange(aes(y=norm, ymin=lower, ymax=upper, group=variable, color=variable),' >> ${rmd_name}
echo '                  position=position_dodge(width=0.3), shape=124, size=1,' >> ${rmd_name}
echo '                  show.legend = FALSE) +' >> ${rmd_name}
echo '  scale_shape_manual(values=c(21,23,22)) +' >> ${rmd_name}
echo '  scale_color_manual(values=c("#000000", "#646464", "#a8a8a8"), guide="none") +' >> ${rmd_name}
echo '  scale_fill_manual(values=ok.colors, guide="none") +' >> ${rmd_name}
echo '  coord_flip() +' >> ${rmd_name}
echo '  geom_point(aes(y=value, shape=variable, group=variable, fill=ok),' >> ${rmd_name}
echo '             size=2, position=position_dodge(width=0.3)) +' >> ${rmd_name}
echo '  labs(subtitle="by Tissue Class", x="", y="Z-Score") +' >> ${rmd_name}
echo '  theme(legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.position = "bottom",' >> ${rmd_name}
echo '        legend.direction = "horizontal",' >> ${rmd_name}
echo '        legend.background = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8),' >> ${rmd_name}
echo '        plot.title = element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10),' >> ${rmd_name}
echo '        axis.title = element_text(size=10),' >> ${rmd_name}
echo '        axis.text.x = element_text(size=8),' >> ${rmd_name}
echo '        axis.text.y = element_text(size=8),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Arrange QC plots, fig.width=9, fig.height=6, out.width="100%"}' >> ${rmd_name}
echo 'grid.arrange(textGrob("Quality Metrics", rot = 90),  plot1, plot2, ncol=, widths=c(0.1,1,1))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Raw Image, fig.width=9, fig.height=3, out.width="100%"}' >> ${rmd_name}
echo 'volume <- read.nii.volume(img.rigid, 1L)' >> ${rmd_name}
echo 'coords <- c(round(dim(volume)[1]/5*2), round(dim(volume)[2:3]/2))' >> ${rmd_name}
echo 'slice1 <- volume[coords[1], , ]' >> ${rmd_name}
echo 'slice2 <- volume[ , coords[2], ]' >> ${rmd_name}
echo 'slice3 <- volume[ , , coords[3]]' >> ${rmd_name}
echo 'rel.dims <- as.double(c(dim(slice1)[1], dim(slice2)[1], dim(slice3)[1]))' >> ${rmd_name}
echo 'rel.dims <- rel.dims / max(rel.dims)' >> ${rmd_name}
echo 'slice1 <- melt(slice1)' >> ${rmd_name}
echo 'slice2 <- melt(slice2)' >> ${rmd_name}
echo 'slice3 <- melt(slice3)' >> ${rmd_name}
echo 'min.val <- min(c(min(slice1$value), min(slice1$value), min(slice1$value)))' >> ${rmd_name}
echo 'max.val <- max(c(max(slice1$value), max(slice1$value), max(slice1$value)))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot1 <- ggplot(slice1, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_gradient(low="#000000", high="#ffffff", limits=c(min.val,max.val)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot2 <- ggplot(slice2, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_gradient(low="#000000", high="#ffffff", limits=c(min.val,max.val)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot3 <- ggplot(slice3, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_gradient(low="#000000", high="#ffffff", limits=c(min.val,max.val)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'grid.arrange(textGrob(label="Unprocessed", rot=90), plot1, plot2, plot3, nrow=1, widths=c(0.1,rel.dims))' >> ${rmd_name}
echo 'rm(list=c("volume", "coords", "slice1", "slice2", "slice3"))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Clean Image, fig.width=9, fig.height=3, out.width="100%"}' >> ${rmd_name}
echo 'volume <- read.nii.volume(img.native, 1L)' >> ${rmd_name}
echo 'coords <- c(round(dim(volume)[1]/5*2), round(dim(volume)[2:3]/2))' >> ${rmd_name}
echo 'slice1 <- volume[coords[1], , ]' >> ${rmd_name}
echo 'slice2 <- volume[ , coords[2], ]' >> ${rmd_name}
echo 'slice3 <- volume[ , , coords[3]]' >> ${rmd_name}
echo 'rel.dims <- as.double(c(dim(slice1)[1], dim(slice2)[1], dim(slice3)[1]))' >> ${rmd_name}
echo 'rel.dims <- rel.dims / max(rel.dims)' >> ${rmd_name}
echo 'slice1 <- melt(slice1)' >> ${rmd_name}
echo 'slice2 <- melt(slice2)' >> ${rmd_name}
echo 'slice3 <- melt(slice3)' >> ${rmd_name}
echo 'min.val <- min(c(min(slice1$value), min(slice1$value), min(slice1$value)))' >> ${rmd_name}
echo 'max.val <- max(c(max(slice1$value), max(slice1$value), max(slice1$value)))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot1 <- ggplot(slice1, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_gradient(low="#000000", high="#ffffff", limits=c(min.val,max.val)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot2 <- ggplot(slice2, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_gradient(low="#000000", high="#ffffff", limits=c(min.val,max.val)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot3 <- ggplot(slice3, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_gradient(low="#000000", high="#ffffff", limits=c(min.val,max.val)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'grid.arrange(textGrob(label="Cleaned", rot=90), plot1, plot2, plot3, nrow=1, widths=c(0.1,rel.dims))' >> ${rmd_name}
echo 'rm(list=c("volume", "coords", "slice1", "slice2", "slice3"))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Brain Extraction, fig.width=9, fig.height=9, out.width="100%"}' >> ${rmd_name}
echo 'img.brain <- read.nii.volume(img.native, 1)' >> ${rmd_name}
echo 'img.mask <- read.nii.volume(mask.brain, 1)' >> ${rmd_name}
echo 'n.row=5' >> ${rmd_name}
echo 'n.col=4' >> ${rmd_name}
echo 'which.slices <- numeric()' >> ${rmd_name}
echo 'for (i in 1:dim(img.brain)[1]) {' >> ${rmd_name}
echo '  slice = img.mask[i, , ]' >> ${rmd_name}
echo '  if (sum(slice) != 0) {' >> ${rmd_name}
echo '    which.slices <- c(which.slices, i)' >> ${rmd_name}
echo '  }' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo 'n.slices <- prod(n.row, n.col)' >> ${rmd_name}
echo 'if (length(which.slices) < n.slices) {' >> ${rmd_name}
echo '  calc.row <- floor(n.slices / n.col)' >> ${rmd_name}
echo '  if (calc.row < 1) {' >> ${rmd_name}
echo '    n.row <- 1' >> ${rmd_name}
echo '    n.col <- n.slices' >> ${rmd_name}
echo '  } else {' >> ${rmd_name}
echo '    n.row <- calc.row' >> ${rmd_name}
echo '    n.slices <- prod(n.row, n.col)' >> ${rmd_name}
echo '  }' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo 'slices <- which.slices[seq(0,length(which.slices)+1,length.out=n.slices+2)[-c(1,n.slices+2)]]' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'imgdims <- dim(img.brain)' >> ${rmd_name}
echo 'pixdims <- unlist(nii.hdr(img.native, "pixdim"))[2:4]' >> ${rmd_name}
echo 'base.size <- 1' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'slice.count <- 0' >> ${rmd_name}
echo 'brain.raster <- numeric()' >> ${rmd_name}
echo 'mask.raster <- numeric()' >> ${rmd_name}
echo 'for (i in 1:n.row) {' >> ${rmd_name}
echo '  brain.temp <- numeric()' >> ${rmd_name}
echo '  mask.temp <- numeric()' >> ${rmd_name}
echo '  for (j in 1:n.col) {' >> ${rmd_name}
echo '    slice.count <- slice.count + 1' >> ${rmd_name}
echo '    brain.temp <- rbind(brain.temp, resizeImage(img.brain[slices[slice.count], , ],' >> ${rmd_name}
echo '                                               width=imgdims[2]/(base.size/pixdims[2]),' >> ${rmd_name}
echo '                                               height=imgdims[3]/(base.size/pixdims[3])))' >> ${rmd_name}
echo '    mask.temp <- rbind(mask.temp, resizeImage(img.mask[slices[slice.count], , ],' >> ${rmd_name}
echo '                                               width=imgdims[2]/(base.size/pixdims[2]),' >> ${rmd_name}
echo '                                               height=imgdims[3]/(base.size/pixdims[3])))' >> ${rmd_name}
echo '  }' >> ${rmd_name}
echo '  brain.raster <- cbind(brain.temp, brain.raster)' >> ${rmd_name}
echo '  mask.raster <- cbind(mask.temp, mask.raster)' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo 'brain.raster <- melt(brain.raster)' >> ${rmd_name}
echo 'mask.raster <- melt(mask.raster)' >> ${rmd_name}
echo 'mask.raster <- rasterFromXYZ(mask.raster)' >> ${rmd_name}
echo 'mask.poly <- fortify(rasterToPolygons(mask.raster, fun=function(x){x != 0}, na.rm=TRUE, digits=1, dissolve=TRUE))' >> ${rmd_name}
echo 'rm(list=c("img.brain", "img.mask"))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'ggplot(brain.raster, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  coord_fixed(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_gradient(low="#ffffff", high="#000000", na.value="transparent") +' >> ${rmd_name}
echo '  geom_path(inherit.aes=FALSE,' >> ${rmd_name}
echo '            data=mask.poly, aes(x=long, y=lat, group=group),' >> ${rmd_name}
echo '            size=0.25, alpha=0.5, color="#ff0000", linetype="solid") +' >> ${rmd_name}
echo '  labs(title="Brain Extraction") +' >> ${rmd_name}
echo '  theme(plot.title = element_text(size=12),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_blank(),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_blank(),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing=margin(0,0,0,0, "null"))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Normalization, fig.width=9, fig.height=9, out.width="100%"}' >> ${rmd_name}
echo 'img.brain <- read.nii.volume(img.template, 1)' >> ${rmd_name}
echo 'img.mask <- read.nii.volume(mask.brain.reg, 1)' >> ${rmd_name}
echo 'n.row=5' >> ${rmd_name}
echo 'n.col=4' >> ${rmd_name}
echo 'which.slices <- numeric()' >> ${rmd_name}
echo 'for (i in 1:dim(img.brain)[3]) {' >> ${rmd_name}
echo '  slice = img.mask[ , ,i]' >> ${rmd_name}
echo '  if (sum(slice) != 0) {' >> ${rmd_name}
echo '    which.slices <- c(which.slices, i)' >> ${rmd_name}
echo '  }' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo 'n.slices <- prod(n.row, n.col)' >> ${rmd_name}
echo 'if (length(which.slices) < n.slices) {' >> ${rmd_name}
echo '  calc.row <- floor(n.slices / n.col)' >> ${rmd_name}
echo '  if (calc.row < 1) {' >> ${rmd_name}
echo '    n.row <- 1' >> ${rmd_name}
echo '    n.col <- n.slices' >> ${rmd_name}
echo '  } else {' >> ${rmd_name}
echo '    n.row <- calc.row' >> ${rmd_name}
echo '    n.slices <- prod(n.row, n.col)' >> ${rmd_name}
echo '  }' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo 'slices <- which.slices[seq(0,length(which.slices)+1,length.out=n.slices+2)[-c(1,n.slices+2)]]' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'imgdims <- dim(img.brain)' >> ${rmd_name}
echo 'pixdims <- unlist(nii.hdr(img.native, "pixdim"))[2:4]' >> ${rmd_name}
echo 'base.size <- 1' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'slice.count <- 0' >> ${rmd_name}
echo 'brain.raster <- numeric()' >> ${rmd_name}
echo 'mask.raster <- numeric()' >> ${rmd_name}
echo 'for (i in 1:n.row) {' >> ${rmd_name}
echo '  brain.temp <- numeric()' >> ${rmd_name}
echo '  mask.temp <- numeric()' >> ${rmd_name}
echo '  for (j in 1:n.col) {' >> ${rmd_name}
echo '    slice.count <- slice.count + 1' >> ${rmd_name}
echo '    brain.temp<- rbind(brain.temp, resizeImage(img.brain[ , , slices[slice.count]],' >> ${rmd_name}
echo '                                               width=imgdims[1]/(base.size/pixdims[1]),' >> ${rmd_name}
echo '                                               height=imgdims[2]/(base.size/pixdims[2])))' >> ${rmd_name}
echo '    mask.temp<- rbind(mask.temp, resizeImage(img.mask[, , slices[slice.count]],' >> ${rmd_name}
echo '                                               width=imgdims[1]/(base.size/pixdims[1]),' >> ${rmd_name}
echo '                                               height=imgdims[2]/(base.size/pixdims[2])))' >> ${rmd_name}
echo '  }' >> ${rmd_name}
echo '  brain.raster <- cbind(brain.temp, brain.raster)' >> ${rmd_name}
echo '  mask.raster <- cbind(mask.temp, mask.raster)' >> ${rmd_name}
echo '}' >> ${rmd_name}
echo 'brain.raster <- melt(brain.raster)' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'mask.m <- mean(as.numeric(mask.raster[mask.raster != 0]))' >> ${rmd_name}
echo 'mask.sd <- sd(as.numeric(mask.raster[mask.raster != 0]))' >> ${rmd_name}
echo 'mask.raster[mask.raster < (mask.m - mask.sd/2)] <- 0' >> ${rmd_name}
echo 'mask.raster[mask.raster > (mask.m + mask.sd/2)] <- 0' >> ${rmd_name}
echo 'mask.raster[mask.raster != 0] <- 1' >> ${rmd_name}
echo 'mask.raster <- melt(mask.raster)' >> ${rmd_name}
echo 'mask.raster <- rasterFromXYZ(mask.raster)' >> ${rmd_name}
echo 'mask.poly <- fortify(rasterToPolygons(mask.raster, fun=function(x){x != 0}, na.rm=TRUE, digits=1, dissolve=TRUE))' >> ${rmd_name}
echo 'rm(list=c("img.brain", "img.mask"))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'ggplot(brain.raster, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  coord_fixed(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_gradient(low="#ffffff", high="#000000", na.value="transparent") +' >> ${rmd_name}
echo '  geom_path(inherit.aes=FALSE,' >> ${rmd_name}
echo '            data=mask.poly, aes(x=long, y=lat, group=group),' >> ${rmd_name}
echo '            size=0.25, alpha=0.5, color="#00ff00", linetype="solid") +' >> ${rmd_name}
echo '  labs(title="Normalization") +' >> ${rmd_name}
echo '  theme(plot.title = element_text(size=12),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_blank(),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_blank(),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing=margin(0,0,0,0, "null"))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Noise, fig.width=9, fig.height=3, out.width="100%"}' >> ${rmd_name}
echo 'volume <- read.nii.volume(img.noise, 1L)' >> ${rmd_name}
echo 'coords <- c(round(dim(volume)[1]/5*2), round(dim(volume)[2:3]/2))' >> ${rmd_name}
echo 'slice1 <- volume[coords[1], , ]' >> ${rmd_name}
echo 'slice2 <- volume[ , coords[2], ]' >> ${rmd_name}
echo 'slice3 <- volume[ , , coords[3]]' >> ${rmd_name}
echo 'rel.dims <- as.double(c(dim(slice1)[1], dim(slice2)[1], dim(slice3)[1]))' >> ${rmd_name}
echo 'rel.dims <- rel.dims / max(rel.dims)' >> ${rmd_name}
echo 'slice1 <- melt(slice1)' >> ${rmd_name}
echo 'slice2 <- melt(slice2)' >> ${rmd_name}
echo 'slice3 <- melt(slice3)' >> ${rmd_name}
echo 'min.val <- min(c(min(slice1$value), min(slice1$value), min(slice1$value)))' >> ${rmd_name}
echo 'max.val <- max(c(max(slice1$value), max(slice1$value), max(slice1$value)))' >> ${rmd_name}
echo 'slice.legend <- melt(matrix(seq(min.val, max.val, length.out = 100), ncol=10, nrow=100))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot1 <- ggplot(slice1, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot2 <- ggplot(slice2, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot3 <- ggplot(slice3, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val)) +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot4 <- ggplot(slice.legend, aes(x=Var2, y=Var1, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis() +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=-Inf, label=round(min.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=0,' >> ${rmd_name}
echo '           color=viridis(1,begin=1,end=1,option="viridis"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=0,end=0,option="viridis"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=Inf, label=round(max.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=1,' >> ${rmd_name}
echo '           color=viridis(1,begin=0,end=0,option="viridis"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=1,end=1,option="viridis"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'grid.arrange(textGrob(label = "Noise", rot = 90),' >> ${rmd_name}
echo '             plot4, plot1, plot2, plot3, nrow=1,' >> ${rmd_name}
echo '             widths=c(0.25,0.1,rel.dims))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Bias T1T2, fig.width=9, fig.height=3, out.width="100%"}' >> ${rmd_name}
echo 'volume <- read.nii.volume(img.biast1t2, 1L)' >> ${rmd_name}
echo 'coords <- c(round(dim(volume)[1]/5*2), round(dim(volume)[2:3]/2))' >> ${rmd_name}
echo 'slice1 <- volume[coords[1], , ]' >> ${rmd_name}
echo 'slice2 <- volume[ , coords[2], ]' >> ${rmd_name}
echo 'slice3 <- volume[ , , coords[3]]' >> ${rmd_name}
echo 'rel.dims <- as.double(c(dim(slice1)[1], dim(slice2)[1], dim(slice3)[1]))' >> ${rmd_name}
echo 'rel.dims <- rel.dims / max(rel.dims)' >> ${rmd_name}
echo 'slice1 <- melt(slice1)' >> ${rmd_name}
echo 'slice2 <- melt(slice2)' >> ${rmd_name}
echo 'slice3 <- melt(slice3)' >> ${rmd_name}
echo 'min.val <- min(c(min(slice1$value), min(slice1$value), min(slice1$value)))' >> ${rmd_name}
echo 'max.val <- max(c(max(slice1$value), max(slice1$value), max(slice1$value)))' >> ${rmd_name}
echo 'slice.legend <- melt(matrix(seq(min.val, max.val, length.out = 100), ncol=10, nrow=100))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot1 <- ggplot(slice1, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="plasma") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot2 <- ggplot(slice2, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="plasma") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot3 <- ggplot(slice3, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="plasma") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot4 <- ggplot(slice.legend, aes(x=Var2, y=Var1, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(option="plasma") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=-Inf, label=round(min.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=0,' >> ${rmd_name}
echo '           color=viridis(1,begin=1,end=1,option="plasma"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=0,end=0,option="plasma"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=Inf, label=round(max.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=1,' >> ${rmd_name}
echo '           color=viridis(1,begin=0,end=0,option="plasma"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=1,end=1,option="plasma"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'grid.arrange(textGrob(label = "Bias Field - T1w/T2w", rot = 90),' >> ${rmd_name}
echo '             plot4, plot1, plot2, plot3, nrow=1,' >> ${rmd_name}
echo '             widths=c(0.25,0.1,rel.dims))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r Bias N4, fig.width=9, fig.height=3, out.width="100%"}' >> ${rmd_name}
echo 'volume <- read.nii.volume(img.biasn4, 1L)' >> ${rmd_name}
echo 'coords <- c(round(dim(volume)[1]/5*2), round(dim(volume)[2:3]/2))' >> ${rmd_name}
echo 'slice1 <- volume[coords[1], , ]' >> ${rmd_name}
echo 'slice2 <- volume[ , coords[2], ]' >> ${rmd_name}
echo 'slice3 <- volume[ , , coords[3]]' >> ${rmd_name}
echo 'rel.dims <- as.double(c(dim(slice1)[1], dim(slice2)[1], dim(slice3)[1]))' >> ${rmd_name}
echo 'rel.dims <- rel.dims / max(rel.dims)' >> ${rmd_name}
echo 'slice1 <- melt(slice1)' >> ${rmd_name}
echo 'slice2 <- melt(slice2)' >> ${rmd_name}
echo 'slice3 <- melt(slice3)' >> ${rmd_name}
echo 'min.val <- min(c(min(slice1$value), min(slice1$value), min(slice1$value)))' >> ${rmd_name}
echo 'max.val <- max(c(max(slice1$value), max(slice1$value), max(slice1$value)))' >> ${rmd_name}
echo 'slice.legend <- melt(matrix(seq(min.val, max.val, length.out = 100), ncol=10, nrow=100))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot1 <- ggplot(slice1, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="plasma") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot2 <- ggplot(slice2, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="plasma") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot3 <- ggplot(slice3, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="plasma") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot4 <- ggplot(slice.legend, aes(x=Var2, y=Var1, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(option="plasma") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=-Inf, label=round(min.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=0,' >> ${rmd_name}
echo '           color=viridis(1,begin=1,end=1,option="plasma"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=0,end=0,option="plasma"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=Inf, label=round(max.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=1,' >> ${rmd_name}
echo '           color=viridis(1,begin=0,end=0,option="plasma"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=1,end=1,option="plasma"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'grid.arrange(textGrob(label = "Bias Field - N4", rot = 90),' >> ${rmd_name}
echo '             plot4, plot1, plot2, plot3, nrow=1,' >> ${rmd_name}
echo '             widths=c(0.25,0.1,rel.dims))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r GM Posterior, fig.width=9, fig.height=3, out.width="100%"}' >> ${rmd_name}
echo 'volume <- read.nii.volume(prob.gm, 1L)' >> ${rmd_name}
echo 'coords <- c(round(dim(volume)[1]/5*2), round(dim(volume)[2:3]/2))' >> ${rmd_name}
echo 'slice1 <- volume[coords[1], , ]' >> ${rmd_name}
echo 'slice2 <- volume[ , coords[2], ]' >> ${rmd_name}
echo 'slice3 <- volume[ , , coords[3]]' >> ${rmd_name}
echo 'rel.dims <- as.double(c(dim(slice1)[1], dim(slice2)[1], dim(slice3)[1]))' >> ${rmd_name}
echo 'rel.dims <- rel.dims / max(rel.dims)' >> ${rmd_name}
echo 'slice1 <- melt(slice1)' >> ${rmd_name}
echo 'slice2 <- melt(slice2)' >> ${rmd_name}
echo 'slice3 <- melt(slice3)' >> ${rmd_name}
echo 'min.val <- min(c(min(slice1$value), min(slice1$value), min(slice1$value)))' >> ${rmd_name}
echo 'max.val <- max(c(max(slice1$value), max(slice1$value), max(slice1$value)))' >> ${rmd_name}
echo 'slice.legend <- melt(matrix(seq(min.val, max.val, length.out = 100), ncol=10, nrow=100))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot1 <- ggplot(slice1, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot2 <- ggplot(slice2, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot3 <- ggplot(slice3, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot4 <- ggplot(slice.legend, aes(x=Var2, y=Var1, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=-Inf, label=round(min.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=0,' >> ${rmd_name}
echo '           color=viridis(1,begin=1,end=1,option="cividis"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=0,end=0,option="cividis"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=Inf, label=round(max.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=1,' >> ${rmd_name}
echo '           color=viridis(1,begin=0,end=0,option="cividis"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=1,end=1,option="cividis"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'grid.arrange(textGrob(label = "GM Posterior", rot = 90),' >> ${rmd_name}
echo '             plot4, plot1, plot2, plot3, nrow=1,' >> ${rmd_name}
echo '             widths=c(0.25,0.1,rel.dims))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r WM Posterior, fig.width=9, fig.height=3, out.width="100%"}' >> ${rmd_name}
echo 'volume <- read.nii.volume(prob.wm, 1L)' >> ${rmd_name}
echo 'coords <- c(round(dim(volume)[1]/5*2), round(dim(volume)[2:3]/2))' >> ${rmd_name}
echo 'slice1 <- volume[coords[1], , ]' >> ${rmd_name}
echo 'slice2 <- volume[ , coords[2], ]' >> ${rmd_name}
echo 'slice3 <- volume[ , , coords[3]]' >> ${rmd_name}
echo 'rel.dims <- as.double(c(dim(slice1)[1], dim(slice2)[1], dim(slice3)[1]))' >> ${rmd_name}
echo 'rel.dims <- rel.dims / max(rel.dims)' >> ${rmd_name}
echo 'slice1 <- melt(slice1)' >> ${rmd_name}
echo 'slice2 <- melt(slice2)' >> ${rmd_name}
echo 'slice3 <- melt(slice3)' >> ${rmd_name}
echo 'min.val <- min(c(min(slice1$value), min(slice1$value), min(slice1$value)))' >> ${rmd_name}
echo 'max.val <- max(c(max(slice1$value), max(slice1$value), max(slice1$value)))' >> ${rmd_name}
echo 'slice.legend <- melt(matrix(seq(min.val, max.val, length.out = 100), ncol=10, nrow=100))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot1 <- ggplot(slice1, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot2 <- ggplot(slice2, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot3 <- ggplot(slice3, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot4 <- ggplot(slice.legend, aes(x=Var2, y=Var1, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=-Inf, label=round(min.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=0,' >> ${rmd_name}
echo '           color=viridis(1,begin=1,end=1,option="cividis"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=0,end=0,option="cividis"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=Inf, label=round(max.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=1,' >> ${rmd_name}
echo '           color=viridis(1,begin=0,end=0,option="cividis"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=1,end=1,option="cividis"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'grid.arrange(textGrob(label = "WM Posterior", rot = 90),' >> ${rmd_name}
echo '             plot4, plot1, plot2, plot3, nrow=1,' >> ${rmd_name}
echo '             widths=c(0.25,0.1,rel.dims))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r CSF Posterior, fig.width=9, fig.height=3, out.width="100%"}' >> ${rmd_name}
echo 'volume <- read.nii.volume(prob.csf, 1)' >> ${rmd_name}
echo 'coords <- c(round(dim(volume)[1]/5*2), round(dim(volume)[2:3]/2))' >> ${rmd_name}
echo 'slice1 <- volume[coords[1], , ]' >> ${rmd_name}
echo 'slice2 <- volume[ , coords[2], ]' >> ${rmd_name}
echo 'slice3 <- volume[ , , coords[3]]' >> ${rmd_name}
echo 'rel.dims <- as.double(c(dim(slice1)[1], dim(slice2)[1], dim(slice3)[1]))' >> ${rmd_name}
echo 'rel.dims <- rel.dims / max(rel.dims)' >> ${rmd_name}
echo 'slice1 <- melt(slice1)' >> ${rmd_name}
echo 'slice2 <- melt(slice2)' >> ${rmd_name}
echo 'slice3 <- melt(slice3)' >> ${rmd_name}
echo 'min.val <- min(c(min(slice1$value), min(slice1$value), min(slice1$value)))' >> ${rmd_name}
echo 'max.val <- max(c(max(slice1$value), max(slice1$value), max(slice1$value)))' >> ${rmd_name}
echo 'slice.legend <- melt(matrix(seq(min.val, max.val, length.out = 100), ncol=10, nrow=100))' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'plot1 <- ggplot(slice1, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot2 <- ggplot(slice2, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot3 <- ggplot(slice3, aes(x=Var1, y=Var2, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(limits=c(min.val, max.val), option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'plot4 <- ggplot(slice.legend, aes(x=Var2, y=Var1, fill=value)) +' >> ${rmd_name}
echo '  theme_bw() +' >> ${rmd_name}
echo '  coord_equal(expand=FALSE, clip="off") +' >> ${rmd_name}
echo '  scale_fill_viridis(option="cividis") +' >> ${rmd_name}
echo '  geom_raster() +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=-Inf, label=round(min.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=0,' >> ${rmd_name}
echo '           color=viridis(1,begin=1,end=1,option="cividis"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=0,end=0,option="cividis"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  annotate("label", x=-Inf, y=Inf, label=round(max.val,2),' >> ${rmd_name}
echo '           hjust=1, vjust=1,' >> ${rmd_name}
echo '           color=viridis(1,begin=0,end=0,option="cividis"),' >> ${rmd_name}
echo '           fill=viridis(1,begin=1,end=1,option="cividis"),' >> ${rmd_name}
echo '           label.r=unit(0, "null")) +' >> ${rmd_name}
echo '  theme(plot.title = element_blank(),' >> ${rmd_name}
echo '        legend.position="none",' >> ${rmd_name}
echo '        legend.title = element_blank(),' >> ${rmd_name}
echo '        legend.text = element_text(size=8, margin=margin(1,0,0,0,"null")),' >> ${rmd_name}
echo '        axis.title=element_blank(),' >> ${rmd_name}
echo '        axis.text=element_blank(),' >> ${rmd_name}
echo '        axis.ticks=element_blank(),' >> ${rmd_name}
echo '        plot.subtitle = element_text(size=10, margin = margin(0,0,0,0,"null")),' >> ${rmd_name}
echo '        plot.background=element_blank(),' >> ${rmd_name}
echo '        panel.background=element_rect(color="#000000"),' >> ${rmd_name}
echo '        panel.grid=element_blank(),' >> ${rmd_name}
echo '        panel.border=element_blank(),' >> ${rmd_name}
echo '        panel.spacing.x=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        panel.spacing.y=unit(c(0,0,0,0),"null"),' >> ${rmd_name}
echo '        plot.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        legend.margin=margin(0,0,0,0, "null"),' >> ${rmd_name}
echo '        panel.spacing = margin(0,0,0,0, "null"))' >> ${rmd_name}
echo 'grid.arrange(textGrob(label = "CSF Posterior", rot = 90),' >> ${rmd_name}
echo '             plot4, plot1, plot2, plot3, nrow=1,' >> ${rmd_name}
echo '             widths=c(0.25,0.1,rel.dims))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r}' >> ${rmd_name}
echo 'wbf[ ,2:3] <- round(wbf[ ,2:3], 3)' >> ${rmd_name}
echo 'segf[ ,2:4] <- round(segf[ ,2:4], 3)' >> ${rmd_name}
echo 'kable(wbf, caption="Whole Brain") %>%' >> ${rmd_name}
echo '  kable_styling(bootstrap_options = c("striped", "hover", "condensed", "responsive"),' >> ${rmd_name}
echo '                full_width = F, font_size=12, position="center")' >> ${rmd_name}
echo '' >> ${rmd_name}
echo 'kable(segf, caption="by Tissue Class") %>%' >> ${rmd_name}
echo '  kable_styling(bootstrap_options = c("striped", "hover", "condensed", "responsive"),' >> ${rmd_name}
echo '                full_width = F, font_size=12, position="center")' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
echo '```{r clean_scratch}' >> ${rmd_name}
echo 'fls.rm <- list.files(path=scratch.dir, pattern=paste0(subject, "_", session), full.names=TRUE)' >> ${rmd_name}
echo 'invisible(file.remove(fls.rm))' >> ${rmd_name}
echo '```' >> ${rmd_name}
echo '' >> ${rmd_name}
#qsub ${job_name}
