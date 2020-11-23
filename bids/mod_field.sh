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
FNAME=$(basename ${INPUT})
DNAME=$(dirname ${INPUT})

TEMP=(${FNAME//_/ })
TEMP=(${FNAME//-/ })

MODALITY=${TEMP[-1]}
unset TEMP[-1]

for (( i=0; i<=${#TEMP[@]}; i+=2 )); do
  FLAG+=(${TEMP[${i}]})
done
for (( i=1; i<=${#TEMP[@]}; i+=2 )); do
  VALUE+=(${TEMP[${i}]})
done

if [[ -n ${MOD} ]]; then
  MOD=(${MOD//,/ })
  for (( i=0; i<${#MOD[@]}; i++)) {
    *** loop over flags to find match, then overwrite value
  } 
fi

if [[ -n ${DEL} ]]; then
  *** loop over flags and keep only good ones, i.e., not in delete variable... do the same for values 
fi

if [[ -n ${ADD} ]]; then
  *** loop over possible flags add if in name already add if requested, do the same for value, make sure in BIDS order
fi


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
exit 0


