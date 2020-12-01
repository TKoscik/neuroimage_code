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
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DIR_PROJECT=
ALL=true
PARTICIPANT_ID=
SESSION_ID=
DIR_SAVE=

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    --participant_id) PARTICIPANT_ID="$2" ; shift 2 ;;
    --session-id) SESSION_ID="$2" ; shift 2 ;;
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
  PARTICIPANT_ID=($(${DIR_INC}/bids/get_column.sh -i ${PARTICIPANT_TSV} -f "participant_id"))
  SESSION_ID=($(${DIR_INC}/bids/get_column.sh -i ${PARTICIPANT_TSV} -f "session_id"))
  PARTICIPANT_ID=("${PARTICIPANT_ID[@]:1}")
  SESSION_ID=("${SESSION_ID[@]:1}")
else
  PARTICIPANT_ID=(${PARTICIPANT_ID//,/ })
  SESSION_ID=(${SESSION_ID//,/ })
fi
N=${#PARTICIPANT_ID[@]}

if [[ -z ${DIR_SAVE} ]]; then
  DIR_SAVE=${DIR_PROJECT}/rawdata
fi

SAVE_FILE=${DIR_SAVE}/scanner.tsv
TABS=$(printf '\t')
if [[ ! -f ${SAVE_FILE} ]]; then
  touch ${SAVE_FILE}
  if [[ -n ${SESSION_ID} ]]; then
    echo "participant_id${TABS}session_id${TABS}scanner_field${TABS}scanner_vendor${TABS}scanner_model${TABS}scanner_serial${TABS}scanner_software${TABS}scanner_coilReceive${TABS}scanner_coil" >> ${SAVE_FILE}
  else
    echo "participant_id${TABS}scanner_field${TABS}scanner_vendor${TABS}scanner_model${TABS}scanner_serial${TABS}scanner_software${TABS}scanner_coilReceive${TABS}scanner_coil" >> ${SAVE_FILE}
  fi
fi

JSON_FIELDS=("MagneticFieldStrength" "Manufacturer" "ManufacturersModelName" "DeviceSerialNumber" "SoftwareVersions" "ReceiveCoilName" "CoilString")
JSON_N=${#JSON_FIELDS[@]}
for (( i=0; i<${N}; i++ )); do
  unset OUT_STR
  OUT_STR="${PARTICIPANT_ID[${i}]}"
  if [[ -n ${SESSION_ID} ]]; then
    OUT_STR="${OUT_STR}${TABS}${SESSION_ID[${i}]}"
  fi
  unset JSON_LS
  JSON_LS=($(find ${DIR_PROJECT}/rawdata/sub-${PARTICIPANT_ID[${i}]} -type f -name "*.json"))
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


