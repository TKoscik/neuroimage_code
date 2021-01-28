#!/bin/bash -e
#===============================================================================
# Get BIDS project name from file name
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-09
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
  echo '  -i | --input             file path to find BIDs Project directory'
  echo ''
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================
PROJECT=
temp=$(dirname ${INPUT})
temp=(${temp//// })
for (( i=0; i<${#temp[@]}; i++ )); do
  if [[ "${temp[i]}" == "code" ]]; then break; fi
  if [[ "${temp[i]}" == "derivatives" ]]; then break; fi
  if [[ "${temp[i]}" == "log" ]]; then break; fi
  if [[ "${temp[i]}" == "rawdata" ]]; then break; fi
  if [[ "${temp[i]}" == "sourcedata" ]]; then break; fi
  if [[ "${temp[i]}" == "summary" ]]; then break; fi
  if [[ "${temp[i]}" == "nifti" ]]; then break; fi
  PROJECT="${temp[${i}]}"
done
echo ${PROJECT}

#==============================================================================
# End of function
#==============================================================================
exit 0

