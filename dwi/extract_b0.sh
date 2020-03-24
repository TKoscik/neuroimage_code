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
# B0 extracter
#==============================================================================

mkdir -p ${DIR_SCRATCH}

DIR_NATIVE=${RESEARCHER}/${PROJECT}/nifti/sub-${SUBJECT}/ses-${SESSION}/dwi
DIR_PREP=${RESEARCHER}/${PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}

for i in ${DIR_NATIVE}/*_dwi.nii.gz; do

  NAMEBASE=$( basename $i )
  NAMEBASE=${NAMEBASE::-11}
  DTINAME=${i::-11}
  B0s=($(cat ${DTINAME}_dwi.bval))
  mkdir ${DIR_SCRATCH}/split

  fslsplit ${i} ${DIR_SCRATCH}/split/${NAMEBASE}-split-0000 -t

  for j in ${!B0s[@]}; do 
    k=$(echo "(${B0s[${j}]}/10)" | bc)
    if [ ${k} -ne 0 ]; then
      rm ${DIR_SCRATCH}/split/${NAMEBASE}-split-*000${j}.nii.gz
    fi
  done

  fslmerge -t ${DIR_PREP}/${NAMEBASE}_b0 ${DIR_SCRATCH}/split/${NAMEBASE}*

  rm -r ${DIR_SCRATCH}/split
done



rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}


chgrp -R ${GROUP} ${DIR_PREP} > /dev/null 2>&1
chmod -R g+rw ${DIR_PREP} > /dev/null 2>&1

