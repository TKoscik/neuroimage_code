#!/bin/bash -e
#===============================================================================
# Make Plots of Regressors
# Authors: Timothy R. Koscik, PhD
# Date: 2020-10-08
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(uname -s)"
HARDWARE="$(uname -m)"
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
KEEP=false
NO_LOG=false
umask 007

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
    logBenchmark --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    if [[ -n "${DIR_PROJECT}" ]]; then
      logProject --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
      --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      if [[ -n "${SID}" ]]; then
        logSession --operator ${OPERATOR} \
        --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
        --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
        --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      fi
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hl --long regressors:,do-corr:,dir-save:,\
help,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
REGRESSORS=
DO_CORR="false"
DIR_SAVE=
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --regressors) REGRESSORS="$2" ; shift 2 ;;
    --do-corr) DO_CORR="true" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
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
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --regressors <value>     csv list of file paths *.1D regressor files'
  echo '  --do-corr                make a correlation plot as well'
  echo '  --dir-save <value>       directory to save output, optional'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
DIR_PROJECT=$(getDir -i ${REGRESSOR})
PID=$(getField -i ${REGRESSOR} -f sub)
SID=$(getField -i ${REGRESSOR} -f ses)
if [[ -z "${DIR_SAVE}" ]]; then
  DIR_SAVE=$(dirname ${REGRESSOR})
fi
mkdir -p ${DIR_SAVE}

Rscript ${INC_R}/regressorPlot.R \
  ${REGRESSORS} \
  ${DIR_SAVE} \
  "doCorr=${DO_CORR^^}"

#===============================================================================
# End of Function
#===============================================================================
exit 0


