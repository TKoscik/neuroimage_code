#!/bin/bash -e

#===============================================================================
# Apply power proportion to variables in a datafile
# Authors: Timothy R. Koscik, PhD.
# Date: 2020-04-16
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)

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
OPTS=`getopt -o hla:b: --long group:,prefix:,\
input:,measure:,adjust:,ignore:,by:,no-retry,max-iter:,if-fail:,no-rescale,save-params,\
dir-save:,dir-code:,\
help,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
INPUT=
MEASURE=mean
ADJUST=all
IGNORE=
BY=
NO_RETRY=true
MAX_ITER=1000
IF_FAIL=0,1
NO_RESCALE=true
SAVE_PARAMS=false
DIR_SAVE=
DIR_CODE=/Shared/inc_scratch/code
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -a) A_START="$2" ; shift 2 ;;
    -b) B_START="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --input) INPUT="$2" ; shift 2 ;;
    --measure) MEASURE="$2" ; shift 2 ;;
    --adjust) ADJUST="$2" ; shift 2 ;;
    --ignore) IGNORE="$2" ; shift 2 ;;
    --by) BY="$2" ; shift 2 ;;
    --no-retry) RETRY=false ; shift ;;
    --max-iter) MAX_ITER="$2" ; shift 2 ;;
    --if-fail) IF_FAIL="$2" ; shift 2 ;;
    --no-rescale) RESCALE=false ; shift ;;
    --save-params) SAVE_PARAMS=true ; shift ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  -a <value>               initial value for alpha parameter'
  echo '  -b <value>               initial value for beta parameter'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --input <value>          full path to csv or tsv file'
  echo '  --adjust <value>         comma-separated list of variable names to adjust'
  echo '                           default=all, to adjust all numeric variables'
  echo '                           variables named: participant_id, session_id,'
  echo '                             summary_date will always be ignored'
  echo '  --ignore <value>         comma-separated list of variable names to ignore,'
  echo '                           ignore will supersede adjust if both provided'
  echo '  --by <value>             string indicating which variable to use for'
  echo '                           power proportioning the other variables'
  echo '                           default=icv'
  echo ''
  echo ''
  echo ''
  echo ''
  echo ''
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
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
