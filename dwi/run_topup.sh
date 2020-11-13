#!/bin/bash -e
#===============================================================================
# Run Topup
# Authors: Josh Cochran
# Date: 3/30/2020
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
OPTS=`getopt -o hl --long prefix:,\
dir-dwi:,config:,\
help,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
PREFIX=
DIR_DWI=
CONFIG=b02b0.cnf
KEEP=false
HELP=false
DRY_RUN=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --config) CONFIG="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------
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
  echo '  --config <value>         configuration file to use, default, b02b0.cnf'
  echo '  --dir-dwi <value>        dwi working directory'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
anyfile=($(ls ${DIR_DWI}/sub*.nii.gz))
if [ -z "${PREFIX}" ]; then
  SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f "sub")
  PREFIX="sub-${SUBJECT}"
  SESSION=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f "ses")
  if [[ -n ${SESSION} ]]; then
    PREFIX="${PREFIX}_ses-${SESSION}"
  fi
fi

# Topup ------------------------------------------------------------------------
topup \
  --imain=${DIR_DWI}/${PREFIX}_B0s+raw.nii.gz \
  --datain=${DIR_DWI}/${PREFIX}_B0sAcqParams.txt \
  --config=${CONFIG} \
  --out=${DIR_DWI}/topup_results \
  --iout=${DIR_DWI}/${PREFIX}_B0.nii.gz

# Extract mean B0 --------------------------------------------------------------
fslmaths ${DIR_DWI}/${PREFIX}_B0.nii.gz -Tmean ${DIR_DWI}/${PREFIX}_B0+mean.nii.gz

#==============================================================================
# End of function
#==============================================================================
exit 0

