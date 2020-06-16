#!/bin/bash -e

#===============================================================================
# Initialize Diffusion Preprocessing
# - select dwi files to process together
# - setup working directory, persistent across sections
# Authors: Timothy R. Koscik
# Date: 2020-06-16
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
OPTS=`getopt -o hl --long group:,prefix:,\
dwi-list:,dir-prep:,\
help,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
DWI_LIST=
DIR_PREP=
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dwi-list) DWI_LIST="$2" ; shift 2 ;;
    --dir-prep) DIR_PREP="$2" ; shift 2 ;;
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
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dwi-list <value>       Comma-separated list of DWI files to process'
  echo '                           together'
  echo '  --dir-prep <value>       directory to copy dwi files for processing'
  echo '                           will be persistent after function'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
if [ -z "${DIR_PREP}" ]; then
  PROJECT=`${DIR_CODE}/bids/get_project.sh -i ${INPUT_FILE}`
  SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "sub"`
  SESSION=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "ses"`
  DIR_PREP=/Shared/inc_scratch/${PROJECT}_sub-${SUBJECT}_ses-${SESSION}_DWIprep_${DATE_SUFFIX}
fi
mkdir -p ${DIR_PREP}

#===============================================================================
# Start of Function
#===============================================================================
DWI_LIST=${DWI_LIST//,/ }
N_DWI=${#DWI_LIST[@]}
for (( i=0; i<${N_DWI}; i++ )); do
  DWI=${DWI_LIST[${i}]}
  NAME_BASE=${DWI::-11}
  cp ${DWI} ${DIR_PREP}/
  cp ${NAME_BASE}.json ${DIR_PREP}/
  cp ${NAME_BASE}.bval ${DIR_PREP}/
  cp ${NAME_BASE}.bvec ${DIR_PREP}/
done
echo ${DIR_PREP}
#===============================================================================
# End of Function
#===============================================================================

# Exit function ---------------------------------------------------------------
exit 0

