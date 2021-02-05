#!/bin/bash -e
#===============================================================================
# Wrapper to extract some basic info from NIfTI headers
# Authors: Timothy R. Koscik, PhD
# Date: 2021-01-28
#===============================================================================
# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hijf --long image1:,image2:,field:,help -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
IMAGE1=
IMAGE2=
FIELD=

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -i | --image) IMAGE1="$2" ; shift 2 ;;
    -j | --image) IMAGE2="$2" ; shift 2 ;;
    -f | --field) FIELD="$2" ; shift 2 ;;
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
  echo '  -i | --image1 <value>     image 1, nii or nii.gz file'
  echo '  -j | --image2 <value>     image 2, nii or nii.gz file'
  echo '  -f | --field <value>     comma delimited string indicating information'
  echo '                           to compare'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
FIELD=(${FIELD//,/ })
info_fcn='DIFF_CHK=$(nifti_tool -diff_hdr'
for (( i=0; i<${#FIELD[@]}; i++ )); do
  info_fcn="${info_fcn} -field ${FIELD[${i}]}"
done
info_fcn="${info_fcn} -infiles ${IMAGE1} ${IMAGE2})"

if [[ -n "${DIFF_CHK}" ]]; then
  echo "true";
else
  echo "false"
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0


