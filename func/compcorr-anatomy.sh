#!/bin/bash -e

OPTS=`getopt -hvk --long researcher:,project:,group:,subject:,session:,prefix:,ts-bold:,label-tissue:,value-csf:,value-wm:,dir-scratch:,dir-nimgcore:,dir-pincsource:,keep,help,verbose -n 'parse-options' -- "$@"`
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
TS_BOLD=
LABEL_TISSUE=
VALUE_CSF=1
VALUE_WM=3
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
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --label-tissue) LABEL_TISSUE="$2" ; shift 2 ;;
    --value-csf) VALUE_CSF="$2" ; shift 2 ;;
    --value-wm) VALUE_WM="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------

#==============================================================================
# ANTs 3 Tissue Regressors (aCompCorr)
#==============================================================================
mkdir -p ${DIR_SCRATCH}

ImageMath 4 ${DIR_SCRATCH}/${PREFIX}_acompcorr.nii.gz ThreeTissueConfounds ${TS_BOLD} ${LABEL_TISSUE} ${VALUE_CSF} ${VALUE_WM}

cat ${DIR_SCRATCH}/${PREFIX}_acompcorr_compcorr.csv | tail -n+2 > ${DIR_SCRATCH}/temp.1D
cut -d, -f1-1 ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_global-anatomy.1D
cut -d, -f1-1 --complement ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_compcorr-anatomy.1D

DIR_REGRESSORS=${RESEARCHER}/${PROJECT}/derivatives/func/regressors/sub-${SUBJECT}/ses-${SESSION}
mkdir -p ${DIR_REGRESSORS}

mv ${DIR_SCRATCH}/${PREFIX}_global-anatomy.1D ${DIR_REGRESSORS}/
mv ${DIR_SCRATCH}/${PREFIX}_compcorr-anatomy.1D ${DIR_REGRESSORS}/

rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}
