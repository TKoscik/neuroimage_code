#!/bin/bash -e

#===============================================================================
# Pull a named column from a tab-delimited file
# Authors: Timothy R. Koscik, PhD
# Date: 2020-09-03
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hifd --long input:,field:,delim:,help -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
HELP=false
INPUT=
FIELD=
DELIM=NULL

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -i | --input) INPUT="$2" ; shift 2 ;;
    -f | --field) FIELD="$2" ; shift 2 ;;
    -d | --delim) DELIM="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -i | --input             tsv file to read from'
  echo '  -f | --field             string identifying field to be read'
  echo '  -d | --delim             delimiter to use'
  echo ''
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
if [[ "${DELIM}" == "NULL" ]]; then
  FNAME=$(basename -- "${INPUT}")
  echo $FNAME
  EXT="${FNAME##*.}"
  echo $EXT
  if [[ "${EXT,,}" = "tsv" ]]; then
    DELIM=\t
    echo $DELIM
  elif [[ "${EXT,,}" == "csv" ]]; then
    DELIM=,
  fi
fi

HDR=(`head -1 ${INPUT}`)
HDR=(${HDR}//${DELIM}/ )
echo $HDR
WHICH_COL=NULL
for i in "${!HDR[@]}"; do
   if [[ "${HDR[${i}]}" == "${FIELD}" ]]; then
       WHICH_COL=${i}
   fi
done

if [[ "${WHICH_COL}" == "NULL" ]]; then
  echo NULL
else
  WHICH_COL=$((WHICH_COL+1))
  cut -d${DELIM} -f${WHICH_COL} < ${INPUT}
fi


#===============================================================================
# End of Function
#===============================================================================

# Exit function ---------------------------------------------------------------
exit 0

