#!/bin/bash -e
#===============================================================================
# convert spacing string to from label to string for ANTs function
# Authors: Timothy R. Koscik, PhD
# Date: 2021-01-13
#===============================================================================
# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hi: --long input:,help -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
INPUT=
DIR_INC=/Shared/inc_scratch/code
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
  echo '  -i | --input             file path to find BIDs Project directory'
  echo ''
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================
UNIT=${INPUT:(-2)}
SPACE_LABEL=${INPUT//mm/}
SPACE_LABEL=${SPACE_LABEL//um/}
SPACE_VALS=(${SPACE_LABEL//x/ })
N_DIMS=${#SPACE_VALS[@]}

if [[ "${N_DIMS}" == "1" ]]; then
  SPACE_VALS+=(${SPACE_VALS[0]})
  SPACE_VALS+=(${SPACE_VALS[0]})
  N_DIMS=3
fi

for (( i=0; i<3; i++ )); do
  if [[  "${UNIT}" == "um" ]]; then
      SPACE_VALS[${i}]=$(echo "${SPACE_VALS[${i}]}/1000" | bc -l | awk '{printf "%0.3f", $0}')
  fi
done
SPACE_FCN=($(IFS=x ; echo "${SPACE_VALS[*]}"))
echo ${SPACE_FCN}
#==============================================================================
# End of function
#==============================================================================
exit 0


