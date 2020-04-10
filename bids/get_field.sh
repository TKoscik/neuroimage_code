#!/bin/bash -e

#===============================================================================
# Get field value from BIDs filename.
# compliant with BIDs 1.2.2, and includes INPC-specific extensions
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-09
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hi:f: --long input:,field:,help -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
INPUT=
FIELD=
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -i | --input) INPUT="$2" ; shift 2 ;;
    -f | --field) FIELD="$2" ; shift 2 ;;
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
  echo '  -f | --field             field to retreive.'
  echo '  field options:'
  echo '    sub, ses, task, acq, ce, rec, dir, run, mod*, echo, recording, proc,'
  echo '    site, mask, label, from, to, reg, prep, resid, xfm' 
  echo '    modality [image modality at end of filename]'
  echo '    [*mod refers to "mod" as a flag, not the mdality without a flag at'
  echo '     the end of the filename]'
  echo ''
fi

#==============================================================================
# Start of function
#==============================================================================
OUTPUT=
temp=$(basename ${INPUT})
temp=(${temp//_/ })
if [[ "${FIELD,,}" == "modality" ]]; then
  OUTPUT=${temp[-1]}
else
  for (( i=0; i<${#temp[@]}; i++ )); do
    flag=(${temp[${i}]//-/ })
    if [[ "${flag[0]}" == "${FIELD,,}" ]]; then
      OUTPUT=${flag[1]}
      break
    fi
  done
fi
OUTPUT=(${OUTPUT//./ }) # remove file extensions if present
echo ${OUTPUT[0]}
#==============================================================================
# End of function
#==============================================================================
