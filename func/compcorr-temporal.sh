#!/bin/bash -e

#===============================================================================
# Functional Timeseries - Temporal CompCorr
# Authors: Timothy R. Koscik
# Date: 2020-03-27
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -hvkl --long group:,prefix:,\
ts-bold:,mask-brain:,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
keep,help,verbose -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

ATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
TS_BOLD=
MASK_BRAIN=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
KEEP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --mask-brain) MASK_BRAIN="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${TS_BOLD}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "ses"`
TASK=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "task"`
RUN=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "run"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}_task-${TASK}_run-${run}
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/func
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#==============================================================================
# ANTs tCompCorr
#==============================================================================
ImageMath 4 ${DIR_SCRATCH}/${PREFIX}_tcompcorr.nii.gz CompCorrAuto ${TS_BOLD} ${MASK_BRAIN} 6

cat ${DIR_SCRATCH}/${PREFIX}_tcompcorr_compcorr.csv | tail -n+2 > ${DIR_SCRATCH}/temp.1D
cut -d, -f1-1 ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_global-temporal.1D
cut -d, -f1-1 --complement ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_compcorr-temporal.1D

DIR_REGRESSORS=${DIR_SAVE}/regressors/sub-${SUBJECT}/ses-${SESSION}
mkdir -p ${DIR_REGRESSORS}

mv ${DIR_SCRATCH}/${PREFIX}_global-temporal.1D ${DIR_REGRESSORS}/
mv ${DIR_SCRATCH}/${PREFIX}_compcorr-temporal.1D ${DIR_REGRESSORS}/

rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

