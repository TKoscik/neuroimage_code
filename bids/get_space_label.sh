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

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
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
  echo 'Author: Timothy R. Koscik, PhD'
  echo 'Date: 2020-03-12'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -i | --input             file path to find BIDs Project directory'
  echo ''
fi

#==============================================================================
# Start of function
#==============================================================================
SPACE=(`dirname ${INPUT}`)
SPACE=(${SPACE//// })
SPACE=${SPACE[-1]}
SPACE=(${SPACE//-/ })
SPACE=${SPACE[-1]}
SPACE=(${SPACE//_/ })
SPACE=${SPACE[-1]}
if [[ "${SPACE,,}" == "nifti" ]] || [[ "${SPACE,,}" == "rawdata" ]]; then
  SPACE="raw"
fi
echo ${SPACE}
#==============================================================================
# End of function
#==============================================================================

