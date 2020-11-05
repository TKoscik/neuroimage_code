#!/bin/bash -e

#===============================================================================
# Get the spacing label from BIDS-IA format
#  -this function assumes images are in one of these directories"
#    -*/rawdata/  [*/nifti/ for local, backward compatibility]
#    -*/native/
#    -*/*_to-${SPACE_LABEL}/
#  - if none of these directories are true the function will return everything
#    trailing the last "-" or "_" (whichever comes last) in the the name of the
#    lowest level directory
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-12
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hi: --long input:,help -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
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
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -i | --input             file path to find BIDs Project directory'
  echo ''
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================
# 1. use reg field if exists in file name, or parse directory
# 2. if reg_* exists in directory structure, pull space from reg_* folder name
# 3. if in derivatives folder assume "native" space
# 4. if in rawdata or nifti(deprecated) folder, assume "raw" space
SPACE=$(${DIR_INC}/bids/get_field.sh -i ${INPUT} -f reg)
if [[ -z ${SPACE} ]]; then
  DIR_INPUT=($(dirname ${INPUT}))
  if [[ "${DIR_INPUT}" == *"reg_"* ]]; then
    SPACE=(${DIR_INPUT//reg_/ })
    SPACE=${SPACE[-1]}
    SPACE=(${SPACE//// })
    SPACE=${SPACE[0]}
  elif [[ "${SPACE}" == *"derivatives"* ]]; then
    SPACE="native"
  elif [[ "${SPACE,,}" == "nifti" ]] || [[ "${SPACE,,}" == "rawdata" ]]; then
    SPACE="raw"
  else
  fi
fi
echo ${SPACE}  
#==============================================================================
# End of function
#==============================================================================
exit 0

