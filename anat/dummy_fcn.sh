#!/bin/bash -e

#===============================================================================
# Function to test exit status, clean up and logging
# Authors: Timothy R. Koscik, PhD
# Date: 2020-04-14
#===============================================================================
# Preamble----------------------------------------------------------------------
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
SUCCESS=0
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)

# actions on exit, write to logs, clean scratch
function egress {
  ERROR_CODE=$?
  echo ${ERROR_CODE}
  
  FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
  if [[ ! -f ${FCN_LOG} ]]; then
    echo -e 'operator\tstart\tend\tsuccess' > ${FCN_LOG}
  fi
  LOG_STRING=`date +"${OPERATOR}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${SUCCESS}"`
  echo -e ${LOG_STRING} >> ${FCN_LOG}

  if [[ -v NO_LOG ]]; then
    if [[ "${NO_LOG}" == "false" ]]; then
      PROJECT_LOG=/Shared/inc_scratch/log/test_project.log
      echo -e ${LOG_STRING} >> ${PROJECT_LOG}
    fi
  fi

  if [[ -d ${DIR_SCRATCH} ]]; then
    if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
      rm -R ${DIR_SCRATCH}/*
    fi
    rmdir ${DIR_SCRATCH}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hel --long no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
ERROR=false
HELP=false
NO_LOG=false
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -e ERROR=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
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
  echo '  -e                       force an error output'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  exit 0
fi

if [[ "${ERROR}" == "true" ]];
 exit 1
fi

SUCCESS=1
exit 0
