#!/bin/bash -e
#===============================================================================
# change flags in BIDS filename
# compliant with BIDs 1.2.2, and includes INPC-specific extensions
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-09
#===============================================================================
# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hmadi:f:v: --long input:,modify,add,delete,field:,value:,help -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
INPUT=
FIELD=
VALUE=
ACTION=
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -i | --input) INPUT="$2" ; shift 2 ;;
    -m | --modify) ACTION=modify ; shift ;;
    -a | --add) ACTION=add ; shift ;;
    -d | --delete) ACTION=delete ; shift ;;
    -f | --field) FIELD="$2" ; shift 2 ;;
    -v | --value) VALUE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FCN_NAME=($(basename "$0"))
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -i | --input <value>     BIDs compliant filepath'
  echo '  -m | --modify            modify an existing flag'
  echo '  -a | --add               add an additional flag'
  echo '  -d | --delete            delete an existing flag'
  echo '  -f | --field <value>     field to act on'
  echo '  -v | --value <value>     value to use'
  echo '  field options (in order):'
  echo '    sub, ses, task, acq, ce, rec, dir, run, mod*, echo, recording, proc,'
  echo '    site, mask, label, from, to, reg, prep, resid, xfm'
  echo '    modality [image modality at end of filename]'
  echo '    [*mod refers to "mod" as a flag, not the mdality without a flag at'
  echo '     the end of the filename]'
  echo '    -novel field will be appended before modality'
  echo ''
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================
# Gather input information ----------------------------------------------------
DNAME=$(dirname ${INPUT})
TEMP_NAME=$(basename ${INPUT})
TEMP_NAME=(${TEMP_NAME//./ })
FNAME=${TEMP_NAME[0]}
unset 'TEMP_NAME[0]'
EXT=$(IFS=. ; echo "${TEMP_NAME[*]}")

TEMP=(${FNAME//_/ })
OUTPUT_MODALITY=${TEMP[-1]}
for (( i=0; i<${#TEMP[@]}; i++ )); do
  unset TEMP2
  TEMP2=(${TEMP[${i}]//-/ })
  if [[ "${#TEMP2[@]}" == 2 ]]; then
    INPUT_FLAG+=(${TEMP2[0]})
    INPUT_VALUE+=(${TEMP2[1]})
  fi
done
N_FLAG=${#INPUT_FLAG[@]}

# loop over possible flags, modify, add, or delete-----------------------------
## modify flag ----------------------------------------------------------------
if [[ "${ACTION,,}" == "modify" ]]; then
  if [[ "${FIELD,,}" == "modality" ]]; then
    OUTPUT_MODALITY=${VALUE}
  else
    for (( i=0; i<${N_FLAG}; i++ )); do
      if [[ "${INPUT_FLAG,,}" == "${FIELD,,}" ]]; then
        INPUT_VALUE[${i}]="${VALUE}"
        break
      fi
    done
  fi
  OUTPUT_FLAG=(${INPUT_FLAG[@]})
  OUTPUT_VALUE=(${INPUT_VALUE[@]})
fi

## delete flag ----------------------------------------------------------------
if [[ "${ACTION,,}" == "delete" ]]; then
  for (( i=0; i<${N_FLAG}; i++ )); do
    if [[ "${INPUT_FLAG[${i}]}" == "${FIELD,,}" ]]; then
      unset 'INPUT_FLAG[${i}]'
      unset 'INPUT_VALUE[${i}]'
      break
    fi
  done
  OUTPUT_FLAG=(${INPUT_FLAG[@]})
  OUTPUT_VALUE=(${INPUT_VALUE[@]})
fi

## Add flag -------------------------------------------------------------------
BIDS_LS=("sub" "ses" "task" "acq" "ce" "rec" "dir" "run" "mod" "echo" "recording" "proc" "site" "mask" "label" "from" "to" "reg" "prep" "resid" "xfm")
N_BIDS=${#BIDS_LS[@]}
if [[ "${ACTION,,}" == "add" ]]; then
  for (( i=0; i<${N_BIDS}; i++ )); do
    if [[ "${FIELD,,}" == "${BIDS_LS[${i}]}" ]]; then
      OUTPUT_FLAG+=(${FIELD,,})
      OUTPUT_VALUE+=(${VALUE})
    fi
    for (( j=0; j<${N_FLAG}; j++ )); do
      if [[ "${INPUT_FLAG[${j}]}" == "${BIDS_LS[${i}]}" ]]; then
        OUTPUT_FLAG+=(${INPUT_FLAG[${j}]})
        OUTPUT_VALUE+=(${INPUT_VALUE[${j}]})
      fi
    done
  done
  if [[ ! "${BIDS_LS[@]}" =~ "${FIELD,,}" ]]; then
    OUTPUT_FLAG+=(${FIELD,,})
    OUTPUT_VALUE+=(${VALUE})
  fi
fi

# write output string ---------------------------------------------------------
OUTPUT_STR="${DNAME}/"
N_OUT=${#OUTPUT_FLAG[@]}
for (( i=0; i<${N_OUT}; i++ )); do
  OUTPUT_STR="${OUTPUT_STR}${OUTPUT_FLAG[${i}]}-${OUTPUT_VALUE[${i}]}_"
done
OUTPUT_STR="${OUTPUT_STR}${OUTPUT_MODALITY}.${EXT}"

# send output to terminal -----------------------------------------------------
echo ${OUTPUT_STR}

#==============================================================================
# End of function
#==============================================================================
exit 0
