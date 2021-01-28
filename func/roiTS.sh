#!/bin/bash -e
===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
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
ts-bold:,template:,space:,label:,\
help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
TS_BOLD=
LABEL=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
HELP=false
NO_LOG=false
TEMPLATE=
SPACE=

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --label) LABEL="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
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
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --template <value>       name of template to use, e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --label <value>          Name of label - NOT PATH'
  echo '                           e.g., WBCXN'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
if [ -f "${TS_BOLD}" ]; then
  DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${TS_BOLD})
  if [ -z "${PREFIX}" ]; then
    PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${TS_BOLD})
  fi
  if [ -z "${TEMPLATE}" ] | [ -z "${SPACE}" ]; then
    TEMPLATE_SPACE=$(${DIR_INC}/bids/get_space.sh -i ${TS_BOLD})
    TEMP=(${TEMPLATE_SPACE//+/ })
    TEMPLATE=${TEMP[0]}
    SPACE=${TEMP[1]}
  else
    TEMPLATE_SPACE=${TEMPLATE}+${SPACE}
  fi
else
  echo "The BOLD file does not exist. Exiting."
  exit 1
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/func/ts_${TEMPLATE_SPACE}+${LABEL}
fi
mkdir -p ${DIR_SAVE}

# gather ROI timeseries -------------------------------------------------------
fslmeants \
  -i ${TS_BOLD} \
  -o ${DIR_SAVE}/${PREFIX}_ts-${TEMPLATE_SPACE}+${LABEL}.csv \
  --label=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_label-${LABEL}.nii.gz
sed -i s/"  "/","/g ${DIR_SAVE}/${PREFIX}_ts-${TEMPLATE_SPACE}+${LABEL}.csv
sed -i s/",$"//g ${DIR_SAVE}/${PREFIX}_ts-${TEMPLATE_SPACE}+${LABEL}.csv

#===============================================================================
# End of function
#===============================================================================
exit 0

