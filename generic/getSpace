#!/bin/bash -e
#===============================================================================
# Get the spacing label from BIDS-IA format
# 1. use reg field if exists in file name, or parse directory
# 2. if reg_* exists in directory structure, pull space from reg_* folder name
# 3. if in derivatives folder assume "native" space
# 4. if in rawdata or nifti(deprecated) folder, assume "raw" space
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-12
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
SPACE=$(getField -i ${INPUT} -f reg)
if [[ -z ${SPACE} ]]; then
  DIR_INPUT=($(dirname ${INPUT}))
  if [[ "${DIR_INPUT,,}" == *"reg_"* ]]; then
    SPACE=(${DIR_INPUT//reg_/ })
    SPACE=${SPACE[-1]}
    SPACE=(${SPACE//// })
    SPACE=${SPACE[0]}
    SPACE=${SPACE//_/+}
  elif [[ "${DIR_INPUT,,}" == *"derivatives"* ]]; then
    SPACE="native"
  elif [[ "${DIR_INPUT,,}" == *"nifti"* ]] || [[ "${DIR_INPUT,,}" == *"rawdata"* ]]; then
    SPACE="raw"
  fi
fi
echo ${SPACE}

#==============================================================================
# End of function
#==============================================================================
exit 0

