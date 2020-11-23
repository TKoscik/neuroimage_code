#!/bin/bash -e
#===============================================================================
# Get field value from BIDs filename.
# compliant with BIDs 1.2.2, and includes INPC-specific extensions
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-09
#===============================================================================
# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hmadi:f:v: \
--long input:,mod,add,del,field:,value:,/
help -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
INPUT=
FIELD=
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -i | --input) INPUT="$2" ; shift 2 ;
    -m | --mod) ACTION=modify ; shift ;
    -a | --add) ACTION=add ; shift ;
    -d | --del) ACTION=delete ; shift ;;
    -f | --field) FIELD="$2" ; shift 2 ;
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
  echo '  -i | --input             BIDs compliant filepath'
  echo '  -f | --field             field to retreive.'
  echo '  field options:'
  echo '    sub, ses, task, acq, ce, rec, dir, run, mod*, echo, recording, proc,'
  echo '    site, mask, label, from, to, reg, prep, resid, xfm' 
  echo '    modality [image modality at end of filename]'
  echo '    [*mod refers to "mod" as a flag, not the mdality without a flag at'
  echo '     the end of the filename]'
  echo ''
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================


# Gather input information ----------------------------------------------------
DNAME=$(dirname ${INPUT})
FNAME=$(basename ${INPUT})
filename=$(basename -- "$fullfile")
extension="${filename##*.}"
filename="${filename%.*}"


TEMP=(${FNAME//_/ })
TEMP=(${FNAME//-/ })
INPUT_MODALITY=${TEMP[-1]}
unset TEMP[-1]
for (( i=0; i<=${#TEMP[@]}; i+=2 )); do
  INPUT_FLAG+=(${TEMP[${i}]})
done
for (( i=1; i<=${#TEMP[@]}; i+=2 )); do
  INPUT_VALUE+=(${TEMP[${i}]})
done
N_FLAG=${#INPUT_FLAG[@]}

# loop over possible flags, modify, add, or delete
if [[ "${ACTION,,}" == "modify" ]]; then
  for (( i=0; i<${N_FLAG}; i++ )); do
    if [[ "${INPUT_FLAG,,}" == "${FIELD,,}" ]]; then
      INPUT_VALUE[${i}]=${VALUE}
      break
    fi
  done
  OUTPUT_FLAG=(${INPUT_FLAG[@]})
  OUTPUT_VALUE=(${INPUT_VALUE[@]})
fi

if [[ "${ACTION,,}" == "delete" ]]; then
  for (( i=0; i<${N_FLAG}; i++ )); do
    if [[ "${INPUT_FLAG,,}" == "${FIELD,,}" ]]; then
      unset INPUT_FLAG[${i}]
      unset INPUT_VALUE[${i}]
      break
    fi
  done
  OUTPUT_FLAG=(${INPUT_FLAG[@]})
  OUTPUT_VALUE=(${INPUT_VALUE[@]})
fi

BIDS_LS=("sub" "ses" "task" "acq" "ce" "rec" "dir" "run" "mod" "echo" "recording" "proc" "site" "mask" "label" "from" "to" "reg" "prep" "resid" "xfm")
N_BIDS=${#BIDS_LS[@]}
if [[ -n ${ADD} ]]; then
  for (( i=0; i<${N_BIDS}; i++ )); do
    for (( j=0; i<${N_FLAG}; i++ )); do
      if [[ "${INPUT_FLAG[${j}]}" == "${FLAG_LS[${i}]}" ]]; then
        OUTPUT_FLAG+=(${INPUT_FLAG[${j}]})
        OUTPUT_VALUE+=(${INPUT_VALUE[${j}]})
      elif [[ "${FIELD,,}" =~ "${FLAG_LS[${i}]}" ]]; then
        OUTPUT_FLAG+=(${FIELD})
        OUTPUT_VALUE+=(${VALUE})
      fi
    done
  done
fi

# write output
OUTPUT_STR="${DNAME}/"
N_OUT=${#OUTPUT_FLAG[@]}
for (( i=0; i<${N_OUT}; i++ )); do
  OUTPUT_STR="${OUTPUT_STR}${OUTPUT_FLAG[${i}]}-${OUTPUT_VALUE[${i}]}_"
done
OUTPUT_STR="{OUTPUT_STR::-1}

#==============================================================================
# End of function
#==============================================================================
exit 0


