#!/bin/bash -e
#===============================================================================
# Function Description
# Authors: Timothy R. Koscik, PhD
# Date: 2020-06-15
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
OPTS=$(getopt -o hvl --long prefix:,\
b0-image:,dil:,\
dir-code:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
B0_IMAGE=
DIL=5
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --b0-image) B0_IMAGE="$2" ; shift 2 ;;
    --dil) DIL="$2" ; shift 2 ;;
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
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --b0-image <value>       b0 image'
  echo '  --dil <value>            value of dilation'
  echo '                           default: 5'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
if [ -z "${PREFIX}" ]; then
  SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${B0_IMAGE} -f "sub")
  PREFIX="sub-${SUBJECT}"
  SESSION=$(${DIR_INC}/bids/get_field.sh -i ${B0_IMAGE} -f "ses")
  if [[ -n ${SESSION} ]]; then
    PREFIX="${PREFIX}_ses-${SESSION}"
  fi
fi

DIR_DWI=$(dirname "${B0_IMAGE}") 
bet ${B0_IMAGE} ${DIR_DWI}/${PREFIX}_mod-B0_mask-brain.nii.gz -m -n
mv ${DIR_DWI}/${PREFIX}_mod-B0_mask-brain_mask.nii.gz \
  ${DIR_DWI}/${PREFIX}_mod-B0_mask-brain.nii.gz
ImageMath 3 ${DIR_DWI}/${PREFIX}_mod-B0_mask-brain+dil${DIL}.nii.gz \
  MD ${DIR_DWI}/${PREFIX}_mod-B0_mask-brain.nii.gz ${DIL}
#===============================================================================
# End of Function
#===============================================================================

# Exit function ---------------------------------------------------------------
exit 0

