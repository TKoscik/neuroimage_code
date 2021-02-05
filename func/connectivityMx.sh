#!/bin/bash -e

#===============================================================================
# Generate connectivity matrices from 4D time series data
# Authors: Timothy R. Koscik, PhD
# Date: 2020-10-16
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(unname -s)"
HARDWARE="$(uname -m)"
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
KEEP=false
NO_LOG=false
umask 007

echo "this function is not fully implemented, aborting"
exit 1

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  PROC_STOP=$(date +%Y-%m-%dT%H:%M:%S%z)
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
  if [[ "${NO_LOG}" == "false" ]]; then
    ${DIR_INC}/log/logBenchmark.sh --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    ${DIR_INC}/log/logProject.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    ${DIR_INC}/log/logSession.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvkl --long prefix:,\
other-inputs:,template:,space:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
TS_CSV=
GET_Z=false
GET_P=false
MAKE_FIG=false
FORMAT="long_dataframe"
APPEND_SUMMARY=true

DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
HELP=false

VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --other-inputs) OTHER_INPUTS="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
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
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --other-inputs <value>   other inputs necessary for function'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
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
DIR_PROJECT=`${DIR_INC}/bids/get_dir.sh -i ${INPUT_FILE}`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_INC}/bids/get_bidsbase.sh -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  SUBJECT=`${DIR_INC}/bids/get_field.sh -i ${INPUT_FILE} -f "sub"`
  SESSION=`${DIR_INC}/bids/get_field.sh -i ${INPUT_FILE} -f "ses"`
  DIR_SUBSES="sub-${SUBJECT}"
  if [[ -n ${SESSION} ]]; then
    DIR_SUBSES="${DIR_SUBSES}_ses-${SESSION}"
  fi
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/${DIR_SUBSES}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# <<body of function here>>
# insert comments for important chunks
# move files to appropriate locations

#===============================================================================
# End of Function
#===============================================================================
exit 0

