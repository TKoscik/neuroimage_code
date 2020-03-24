#!/bin/bash

OPTS=`getopt -hvk --long researcher:,project:,group:,subject:,session:,prefix:,dir-scratch:,dir-nimgcore:,dir-pincsource:,keep,help,verbose -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
RESEARCHER=
PROJECT=
GROUP=
SUBJECT=
SESSION=
PREFIX=
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
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------


#==============================================================================
# Eddy Correction
#==============================================================================

mkdir -p ${DIR_SCRATCH}

DIR_PREP=${RESEARCHER}/${PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
DIR_CORRECTED=${RESEARCHER}/${PROJECT}/derivatives/dwi/corrected

eddy_openmp \
  --data_is_shelled \
  --imain=${DIR_PREP}/All_dwis.nii.gz \
  --mask=${DIR_PREP}/DTI_mask.nii.gz \
  --acqp=${DIR_PREP}/All_dwisAcqParams.txt \
  --index=${DIR_PREP}/All_index.txt \
  --bvecs=${DIR_PREP}/All.bvec \
  --bvals=${DIR_PREP}/All.bval \
  --topup=${DIR_PREP}/topup_results \
  --out=${DIR_PREP}/All_dwi_hifi_eddy.nii.gz

cp ${DIR_PREP}/All_dwi_hifi_eddy.nii.gz ${DIR_CORRECTED}/${PREFIX}_dwi.nii.gz


rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}


chgrp -R ${GROUP} ${DIR_PREP} > /dev/null 2>&1
chmod -R g+rw ${DIR_PREP} > /dev/null 2>&1
chgrp ${GROUP} ${DIR_CORRECTED}/${PREFIX}_dwi.nii.gz > /dev/null 2>&1
chmod g+rw ${DIR_CORRECTED}/${PREFIX}_dwi.nii.gz > /dev/null 2>&1
