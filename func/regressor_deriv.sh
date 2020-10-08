#!/bin/bash -e

#===============================================================================
# create derivative of regressor from 1D file
# Authors: Timothy R. Koscik, PhD
# Date: 2020-10-08
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false

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
OPTS=`getopt -o hl --long regressor:,dir-save:,\
help,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
REGRESSOR=
DIR_SAVE=
DIR_CODE=/Shared/inc_scratch/code
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --regressor) OTHER_INPUTS="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done
### NOTE: DIR_CODE, DIR_PINCSOURCE may be deprecated and possibly replaced
#         by DIR_INC for version 0.0.0.0. Specifying the directory may
#         not be necessary, once things are sourced

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --regressor <value>      directory listing for a *.1D regressor file'
  echo '  --dir-save <value>       directory to save output, optional'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================

if [ -z "${DIR_SAVE}" ]; then
  DIR_PROJECT=$(${DIR_CODE}/bids/get_dir.sh -i ${REGRESSOR})
  SUBJECT=$(${DIR_CODE}/bids/get_field.sh -i ${REGRESSOR} -f "sub")
  SESSION=$(${DIR_CODE}/bids/get_field.sh -i ${REGRESSOR} -f "ses")
  DIR_SAVE=${DIR_PROJECT}/derivatives/func/regressor/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SAVE}

Rscript ${DIR_CODE}/func/regressor_deriv.R ${REGRESSOR} ${DIR_SAVE}

#===============================================================================
# End of Function
#===============================================================================

# Exit function ---------------------------------------------------------------
exit 0


