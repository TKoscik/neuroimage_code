#!/bin/bash -e

#===============================================================================
# Get base BIDS filename.
# Strip directory, file extension, and modality
# compliant with BIDs 1.2.2, and includes INPC-specific extensions
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-09
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hsi: --long input:,strip-mod,help -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
INPUT=
STRIP_MOD=FALSE
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -i | --input) INPUT="$2" ; shift 2 ;;
    -s | --strip-mod) STRIP_MOD=true ; shift ;;
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
  echo 'Date: 2020-03-09'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -i | --input             BIDs compliant filepath'
  echo '  -s | --strip-mod         logical to strip modality from end'
  echo ''
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================
OUTPUT=
temp=$(basename ${INPUT})
temp=(${temp//./ })
OUTPUT=${temp[0]}

if [[ "${STRIP_MOD}" == "true" ]]; then
  unset temp
  temp=(${OUTPUT//_/ })
  unset 'temp[${#temp[@]}-1]'
  OUTPUT="${temp[@]}"
  OUTPUT=${OUTPUT// /_}
fi
echo ${OUTPUT[0]}
#==============================================================================
# End of function
#==============================================================================
exit 0

