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
# Check and Fix Odd Dimensions
#==============================================================================
mkdir -p ${DIR_SCRATCH}

DIR_NATIVE=${RESEARCHER}/${PROJECT}/nifti/sub-${SUBJECT}/ses-${SESSION}/dwi

for i in ${DIR_NATIVE}/*_dwi.nii.gz; do

  IFS=x read -r -a DIM_TEMP <<< $(PrintHeader ${i} 2)
  DIMCHK=0

  for j in {0..2}; do

    if [ $((${DIM_TEMP[${j}]}%2)) -eq 1 ]; then
      DIM_TEMP[${j}]=$((${DIM_TEMP[${j}]}-1))
      DIMCHK=1
    fi

    if [ ${DIMCHK} -eq 1 ]; then
      fslroi ${i} ${DIR_SCRATCH}/temp.nii.gz 0 ${DIM_TEMP[0]} 0 ${DIM_TEMP[1]} 0 ${DIM_TEMP[2]}
      mv ${DIR_SCRATCH}/temp.nii.gz ${i}
    fi
  done
done


rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}


chgrp -R ${GROUP} ${DIR_NATIVE} > /dev/null 2>&1
chmod -R g+rw ${DIR_NATIVE} > /dev/null 2>&1




