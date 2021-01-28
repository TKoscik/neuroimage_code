#!/bin/bash -e
#===============================================================================
# Summarize scanner information and add to scanner.tsv
# Authors: Timothy R. Koscik, PhD
# Date: 2020-12-01
#===============================================================================

PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
umask 007

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o ha --long dir-project:,all:,participant_id:,session_id:,dir-save:,help -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DIR_PROJECT=
ALL=true
PID=
SID=
DIR_SAVE=

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    --participant_id) PID="$2" ; shift 2 ;;
    --session-id) SID="$2" ; shift 2 ;;
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
  echo '  -a | --all               use participants.tsv and summarize all'
  echo '  --dir-project <value>    project directory'
  echo '  --participant-id <value> participant id, comma separated list'
  echo '  --session-id <value>     required if in directory structure,'
  echo '                           comma separated list'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default = ${DIR_PROJECT}/rawdata/'
  echo ''
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
if [[ "${ALL}" == "true" ]]; then
  PARTICIPANT_TSV=${DIR_PROJECT}/participants.tsv
  PID=($(${DIR_INC}/bids/get_column.sh -i ${PARTICIPANT_TSV} -f participant_id))
  SID=($(${DIR_INC}/bids/get_column.sh -i ${PARTICIPANT_TSV} -f session_id))
  PID=("${PID[@]:1}")
  SID=("${SID[@]:1}")
else
  PID=(${PID//,/ })
  SID=(${SID//,/ })
fi
N=${#PID[@]}

if [[ -z ${DIR_SAVE} ]]; then
  DIR_SAVE=${DIR_PROJECT}/rawdata
fi

SAVE_FILE=${DIR_SAVE}/scanner.tsv
TABS=$(printf '\t')
if [[ ! -f ${SAVE_FILE} ]]; then
  touch ${SAVE_FILE}
  if [[ -n ${SID} ]]; then
    echo "participant_id${TABS}session_id${TABS}scanner_field${TABS}scanner_vendor${TABS}scanner_model${TABS}scanner_serial${TABS}scanner_software${TABS}scanner_coilReceive${TABS}scanner_coil" >> ${SAVE_FILE}
  else
    echo "participant_id${TABS}scanner_field${TABS}scanner_vendor${TABS}scanner_model${TABS}scanner_serial${TABS}scanner_software${TABS}scanner_coilReceive${TABS}scanner_coil" >> ${SAVE_FILE}
  fi
fi

JSON_FIELDS=("MagneticFieldStrength" "Manufacturer" "ManufacturersModelName" "DeviceSerialNumber" "SoftwareVersions" "ReceiveCoilName" "CoilString")
JSON_N=${#JSON_FIELDS[@]}
for (( i=0; i<${N}; i++ )); do
  unset OUT_STR
  OUT_STR="${PID[${i}]}"
  if [[ -n ${SID} ]]; then
    OUT_STR="${OUT_STR}${TABS}${SID[${i}]}"
  fi
  unset JSON_LS
  SEARCH_PATH=${DIR_PROJECT}/rawdata/sub-${PID[${i}]}
  if [[ -n ${SID} ]]; then
    SEARCH_PATH=${SEARCH_PATH}/ses-${SID[${i}]}
  fi
  JSON_LS=($(find ${SEARCH_PATH} -type f -name "*.json"))
  for (( j=0; j<${JSON_N}; j++ )); do
   unset JSON_VALUE
    for (( k=0; k<${#JSON_LS[@]}; k++ )); do
      json_str='JSON_VALUE=$(jq -c '"'."${JSON_FIELDS[${j}]}"'"' ${JSON_LS[${k}]})'
      eval ${json_str}
      if [[ "${JSON_VALUE}" != "null" ]]; then
        break
      fi
    done
    OUT_STR="${OUT_STR}${TABS}${JSON_VALUE}"
  done
  OUT_STR=${OUT_STR//\"/}
  echo "${OUT_STR}" >> ${SAVE_FILE}
done

#===============================================================================
# End of Function
#===============================================================================
exit 0

