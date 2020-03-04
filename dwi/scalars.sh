#!/bin/bash

OPTS=`getopt -hvk --long researcher:,project:,group:,subject:,session:,prefix:,smoothing:,dir-scratch:,dir-nimgcore:,dir-pincsource:,keep,help,verbose -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S)
RESEARCHER=
PROJECT=
GROUP=
SUBJECT=
SESSION=
PREFIX=
SMOOTHING=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
KEEP=false
VERBOSE=0
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --smoothing) SMOOTHING="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------


#==============================================================================
# DWI Scalars
#==============================================================================

mkdir -p ${DIR_SCRATCH}

DIR_PREP=${RESEARCHER}/${PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
DIR_TENSOR=${RESEARCHER}/${PROJECT}/derivatives/dwi/tensor/sub-${SUBJECT}/ses-${SESSION}

if [ "${SMOOTHING}" != 0 ]; then
  fslmaths ${DIR_PREP}/All_dwi_hifi_eddy.nii.gz -s ${SMOOTHING} ${DIR_PREP}/All_dwi_hifi_eddy_smoothed.nii.gz
fi

if [ "${SMOOTHING}" != 0 ]; then
  dtifit \
    -k ${DIR_PREP}/All_dwi_hifi_eddy_smoothed.nii.gz \
    -o ${DIR_SCRATCH}/All_Scalar \
    -r ${DIR_PREP}/All.bvec \
    -b ${DIR_PREP}/All.bval \
    -m ${DIR_PREP}/DTI_mask.nii.gz 
else
  dtifit \
    -k ${DIR_PREP}/All_dwi_hifi_eddy.nii.gz \
    -o ${DIR_SCRATCH}/All_Scalar \
    -r ${DIR_PREP}/All.bvec \
    -b ${DIR_PREP}/All.bval \
    -m ${DIR_PREP}/DTI_mask.nii.gz 
fi
mv ${DIR_SCRATCH}/All_Scalar* ${DIR_TENSOR}/


rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

chgrp -R ${GROUP} ${DIR_PREP} > /dev/null 2>&1
chmod -R g+rw ${DIR_PREP} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_TENSOR} > /dev/null 2>&1
chmod -R g+rw ${DIR_TENSOR} > /dev/null 2>&1

