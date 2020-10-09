#!/bin/bash -e

#===============================================================================
# Functional Timeseries - Anatomical CompCorr
# Authors: Timothy R. Koscik
# Date: 2020-03-27
#===============================================================================

PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${KEEP}" = false ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" = false ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v ${DIR_PROJECT} ]]; then
      PROJECT_LOG=${DIR_PROJECT}/log/${PREFIX}.log
      if [[ ! -f ${PROJECT_LOG} ]]; then
        echo -e 'operator\tfunction\tstart\tend\texit_status' > ${PROJECT_LOG}
      fi
      echo -e ${LOG_STRING} >> ${PROJECT_LOG}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hl --long prefix:,\
ts-bold:,label-tissue:,value-csf:,value-wm:,\
dir-save:,dir-scratch:,\
help,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
PREFIX=
TS_BOLD=
LABEL_TISSUE=
VALUE_CSF=1
VALUE_WM=3
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --label-tissue) LABEL_TISSUE="$2" ; shift 2 ;;
    --value-csf) VALUE_CSF="$2" ; shift 2 ;;
    --value-wm) VALUE_WM="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --label-tissue <value>   Full path to file containing tissue type labels'
  echo '  --value-csf <value>      numeric value indicating CSF in label file, default=1'
  echo '  --value-wm <value>       numeric value indicating WM in label file, default=3'
  echo '  --dir-save <value>       directory to save output, default:'
  echo '                             DIR_PROJECT/derivatives/func/regressor/sub-###/ses-###'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi
#===============================================================================
# Start of Function
#===============================================================================

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

if [ -f "${TS_BOLD}" ]; then
  DIR_PROJECT=$(${DIR_CODE}/bids/get_dir.sh -i ${TS_BOLD})
  SUBJECT=$(${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "sub")
  SESSION=$(${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "ses")
  if [ -z "${PREFIX}" ]; then
    PREFIX=$(${DIR_CODE}/bids/get_bidsbase -s -i ${TS_BOLD})
  fi
else
  echo "The BOLD file does not exist. Exiting."
  exit 1
fi

# Set DIR_SAVE variable
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/func
fi
if [ -n "${SESSION}" ]; then
  DIR_REGRESSORS=${DIR_SAVE}/regressors/sub-${SUBJECT}/ses-${SESSION}
else
  DIR_REGRESSORS=${DIR_SAVE}/regressors/sub-${SUBJECT}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_REGRESSORS}

# ANTs 3 Tissue Regressors (aCompCorr) ----------------------------------------
ImageMath 4 ${DIR_SCRATCH}/${PREFIX}_acompcorr.nii.gz \
  ThreeTissueConfounds ${TS_BOLD} ${LABEL_TISSUE} ${VALUE_CSF} ${VALUE_WM}

cat ${DIR_SCRATCH}/${PREFIX}_acompcorr_compcorr.csv | tail -n+2 > ${DIR_SCRATCH}/temp.1D
cut -d, -f1-1 ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_global-anatomy.1D
cut -d, -f1-1 --complement ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_compcorr-anatomy.1D

mv ${DIR_SCRATCH}/${PREFIX}_global-anatomy.1D ${DIR_REGRESSORS}/
mv ${DIR_SCRATCH}/${PREFIX}_compcorr-anatomy.1D ${DIR_REGRESSORS}/

#===============================================================================
# End of Function
#===============================================================================

exit 0

