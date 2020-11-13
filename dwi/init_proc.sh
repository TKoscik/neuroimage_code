#!/bin/bash -e
#===============================================================================
# Initialize Diffusion Preprocessing
# - select dwi files to process together
# - setup working directory, persistent across sections
# Authors: Timothy R. Koscik
# Date: 2020-06-16
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
dwi:,dir-prep:,\
help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DWI=
DIR_PREP=
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dwi) DWI="$2" ; shift 2 ;;
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
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --dwi <value>            Comma-separated list of DWI files to process'
  echo '                           together'
  echo '  --dir-prep <value>       directory to copy dwi files for processing'
  echo '                           will be persistent after function'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
DWI=(${DWI//,/ })
N_DWI=${#DWI[@]}

# Set up BIDs compliant variables and workspace --------------------------------
PROJECT=$(${DIR_INC}/bids/get_project.sh -i ${DWI[0]})
if [ -z "${DIR_PREP}" ]; then
  SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${DWI[0]} -f "sub")
  SESSION=$(${DIR_INC}/bids/get_field.sh -i ${DWI[0]} -f "ses")
  f [ -z "${PREFIX}" ]; then
  PREFIX="sub-${SUBJECT}"
  if [[ -n ${SESSION} ]]; then
    PREFIX="${PREFIX}_ses-${SESSION}"
  fi
fi
  DIR_PREP=/Shared/inc_scratch/${PROJECT}_${PREFIX}_DWIprep_${DATE_SUFFIX}
fi
mkdir -p ${DIR_PREP}

for (( i=0; i<${N_DWI}; i++ )); do
  NAME_BASE=${DWI[${i}]}
  NAME_BASE=${NAME_BASE::-7}
  cp ${DWI[${i}]} ${DIR_PREP}/
  cp ${NAME_BASE}.json ${DIR_PREP}/
  cp ${NAME_BASE}.bval ${DIR_PREP}/
  cp ${NAME_BASE}.bvec ${DIR_PREP}/
done
echo ${DIR_PREP}
#===============================================================================
# End of Function
#===============================================================================
exit 0

