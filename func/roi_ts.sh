#!/bin/bash -x

PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false

#set -u

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  #if [[ "${DEBUG}" = false ]]; then
  if [[ "${KEEP}" = false ]]; then
    if [[ -n "${DIR_SCRATCH}" ]]; then
      if [[ -d "${DIR_SCRATCH}" ]]; then
        if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
          rm -R ${DIR_SCRATCH}
        else
          rmdir ${DIR_SCRATCH}
        fi
      fi
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" = false ]]; then
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

OPTS=`getopt -o hl --long prefix:,\
ts-bold:,template:,space:,label:,\
dir-code:,dir-template:,dir-pincsource:,\
help,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
PREFIX=
TS_BOLD=
LABEL=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
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
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-template) DIR_TEMPLATE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo 'Author: Timothy R. Koscik, PhD'
  echo 'Date:   2020-03-27'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
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
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-template <value>   directory where INC templates are stored,'
  echo '                           default: ${DIR_TEMPLATE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

if [ -f "${TS_BOLD}" ]; then
  DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${TS_BOLD}`
  TEMPLATE_SPACE=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "reg"`
  SESSION=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "ses"`
  TASK=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "task"`
  RUN=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "run"`
  if [ -z "${PREFIX}" ]; then
    PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${TS_BOLD}`
  fi
  #declare -A TEMP=()
  TEMP=(${TEMPLATE_SPACE//+/ })
  TEMPLATE=${TEMP[0]}
  SPACE=${TEMP[1]}

  # TEMPLATE=HCPICBM
  # SPACE=2mm
  # LABEL=WBCXN
else
  echo "The BOLD file does not exist. Exiting."
  echo "Check paths, file names, and arguments."
  exit 1
fi

# Set IS_SES variable
if [ -z "${SESSION}" ]; then
  IS_SES=false
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/func/ts_${TEMPLATE_SPACE}+${LABEL}
fi
mkdir -p ${DIR_SAVE}


#==============================================================================
# gather ROI timeseries
#==============================================================================
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

