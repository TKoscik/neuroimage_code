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
# Topup
#==============================================================================

mkdir -p ${DIR_SCRATCH}

DIR_PREP=${RESEARCHER}/${PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}

rm ${DIR_PREP}/*brain.nii.gz
rm ${DIR_PREP}/*mask.nii.gz
rm ${DIR_PREP}/*hifi_b0*.nii.gz
rm ${DIR_PREP}/*eddy*
rm ${DIR_PREP}/*topup*

topup \
  --imain=${DIR_PREP}/All_B0s.nii.gz \
  --datain=${DIR_PREP}/All_B0sAcqParams.txt \
  --config=b02b0.cnf \
  --out=${DIR_PREP}/topup_results \
  --iout=${DIR_PREP}/All_hifi_b0.nii.gz
fslmaths ${DIR_PREP}/All_hifi_b0.nii.gz -Tmean ${DIR_PREP}/All_hifi_b0_mean.nii.gz




rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}


chgrp -R ${GROUP} ${DIR_PREP} > /dev/null 2>&1
chmod -R g+rw ${DIR_PREP} > /dev/null 2>&1
