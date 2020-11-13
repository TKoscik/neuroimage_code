#!/bin/bash -e
#===============================================================================
# Functional Timeseries - Temporal CompCorr
# Authors: Timothy R. Koscik
# Date: 2020-03-27
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${KEEP}" == "false" ]]; then
    if [[ -n ${DIR_SCRATCH} ]]; then
      if [[ -d ${DIR_SCRATCH} ]]; then
        if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
          rm -R ${DIR_SCRATCH}
        else
          rmdir ${DIR_SCRATCH}
        fi
      fi
    fi
  fi
  LOG_STRING=$(date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}")
  if [[ "${NO_LOG}" == "false" ]]; then
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
OPTS=$(getopt -o hl --long prefix:,\
ts-bold:,mask-brain:,\
dir-save:,dir-scratch:,\
help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
TS_BOLD=
MASK_BRAIN=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
HELP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --mask-brain) MASK_BRAIN="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --mask-brain <value>     full pathto brain mask'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
if [ -f "${TS_BOLD}" ]; then
  DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${TS_BOLD})
  SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${TS_BOLD} -f "sub")
  SESSION=$(${DIR_INC}/bids/get_field.sh -i ${TS_BOLD} -f "ses")
  DIR_SUBSES="sub-${SUBJECT}"
  if [[ -n ${SESSION} ]]; then
    DIR_SUBSES="${DIR_SUBSES}_ses-${SESSION}"
  fi
  if [ -z "${PREFIX}" ]; then
    PREFIX=$(${DIR_INC}/bids/get_bidsbase -s -i ${TS_BOLD})
  fi
else
  echo "The BOLD file does not exist. Exiting."
  exit 1
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/func/regressors/${DIR_SUBSES}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# ANTs tCompCorr --------------------------------------------------------------
ImageMath 4 ${DIR_SCRATCH}/${PREFIX}_tcompcorr.nii.gz \
  CompCorrAuto ${TS_BOLD} ${MASK_BRAIN} 6

cat ${DIR_SCRATCH}/${PREFIX}_tcompcorr_compcorr.csv | tail -n+2 > ${DIR_SCRATCH}/temp.1D
cut -d, -f1-1 ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_global-temporal.1D
cut -d, -f1-1 --complement ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_compcorr-temporal.1D

mv ${DIR_SCRATCH}/${PREFIX}_global-temporal.1D ${DIR_SAVE}/
mv ${DIR_SCRATCH}/${PREFIX}_compcorr-temporal.1D ${DIR_SAVE}/

#===============================================================================
# End of Function
#===============================================================================
exit 0

