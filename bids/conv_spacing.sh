#!/bin/bash -e
#===============================================================================
# convert spacing string to from label to string for ANTs function
# Authors: Timothy R. Koscik, PhD
# Date: 2021-01-13
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hi: --long input:,help -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
INPUT=
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -i | --input) INPUT="$2" ; shift 2 ;;
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
  echo '  -i | --input             spacing label to convert to x delimited'
  echo '                           string for function'
  echo ''
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================
UNIT=${INPUT:(-2)}
SIZE=${INPUT//mm/}
SIZE=${SIZE//um/}
VALS=(${SIZE//x/ })
if [[ "${#VALS[@]}" == "1" ]]; then
  VALS=(${VALS[0]} ${VALS[0]} ${VALS[0]})
fi
for (( i=0; i<3; i++ )); do
  if [[  "${UNIT}" == "um" ]]; then
      VALS[${i}]=$(echo "${VALS[${i}]}/1000" | bc -l | awk '{printf "%0.3f", $0}')
  fi
done
VALS=($(IFS=x ; echo "${VALS[*]}"))
echo ${VALS}

#==============================================================================
# End of function
#==============================================================================
exit 0

