#!/bin/bash -e

#===============================================================================
# Smooth DWI image
# Authors: Josh Cochran
# Date: 7/1/2020
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
OPTS=`getopt -o hv --long prefix:,\
image:,smoothing:,\
dir-dwi:,dir-scratch:,dir-code:,dir-pincsource:,\
help,verbose -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
SMOOTHING=
DIR_DWI=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --smoothing) SMOOTHING="$2" ; shift 2 ;;
    --dir-dwi) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
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
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --image <value>          image to be smoothed'
  echo '  --smoothing <value>      size of the smoothing kernal'
  echo '  --dir-dwi <value>        dwi working directory'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${IMAGE}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE}`
fi


#===============================================================================
# Start of Function
#===============================================================================

fslmaths ${IMAGE} -s ${SMOOTHING} ${DIR_DWI}/${PREFIX}_dwi+corrected_smoothed.nii.gz

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

