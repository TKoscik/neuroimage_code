#!/bin/bash -e

#===============================================================================
# Wrapper to apply ComBat Harmonization to 3D brain datasets
# Authors: Timothy Koscik
# Date: 2020-04-27
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
DEBUG=false
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v DIR_PROJECT ]]; then
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
OPTS=`getopt -o hdl --long group:,prefix:,\
dir-image:, file-image:,mask:,file-tsv:,\
var-participant:,var-session:,var-batch:,var-model:,\
dir-save:,dir-scratch:,dir-code:,\
help,debug,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
DIR_IMAGE=
FILE_IMAGE=
MASK=
FILE_TSV=
PARTICIPANT=participant_id
SESSION=session_id
BATCH=
MODEL=NULL
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -d | --debug) DEBUG=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-image) DIR_IMAGE="$2" ; shift 2 ;;
    --file-image) FILE_IMAGE="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --file-tsv) FILE_TSV="$2" ; shift 2 ;;
    --var-participant) PARTICIPANT="$2" ; shift 2 ;;
    --var-session) SESSION="$2" ; shift 2 ;;
    --var-batch) BATCH="$2" ; shift 2 ;;
    --var-model) MODEL="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
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
  echo '  -d | --debug             keep scratch folder for debugging'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dir-image <value>      Directory listing of folder to apply combat'
  echo '                           harmonization to all files. Batch informtion'
  echo '                           must be included in input tsv to be included.'
  echo '  --file-image <value>     Alternatively to dir-image, a comma-separated'
  echo '                           list of files to harmonize can be included.'
  echo '                           if dir-image is provided this input is ignored.'
  echo '  --mask <value>           Path to a binary mask covering voxels to'
  echo '                           include in harmonization. Out put will be'
  echo '                           masked to this region'
  echo '  --file-tsv <value>       Path to a dataset including participant_id,'
  echo '                           session_id, and batch variable'
  echo '  --var-participant <value> A string indicating the name of the variable'
  echo '                           to be used as the participant identifier.'
  echo '                           default=participant_id'
  echo '  --var-session <value>    A string indicating the name of the session'
  echo '                           session identifier, default=session_id'
  echo '  --var-batch <value>      A string indicating the name of the variable'
  echo '                           to be use in ComBat Harmonization, i.e., the'
  echo '                           the variable whose effect is to be removed'
  echo '                           from the dataset.'
  echo '  --var-model <value>      The predictor model, whose effects are to be'
  echo '                           excluded from ComBat harmonization'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-template <value>   directory where INC templates are stored,'
  echo '                           default: ${DIR_TEMPLATE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${INPUT_FILE}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#===============================================================================
# Start of Function
#===============================================================================
# <<body of function here>>
# insert comments for important chunks
# move files to appropriate locations
#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}/
fi

# Exit function ---------------------------------------------------------------
exit 0

