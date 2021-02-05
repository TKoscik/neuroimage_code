#!/bin/bash -e
#===============================================================================
# Wrapper to extract some basic info from NIfTI headers
# Authors: Timothy R. Koscik, PhD
# Date: 2021-01-28
#===============================================================================
# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hif --long image:,field:,help -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
IMAGE=
FIELD=

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -i | --image) IMAGE="$2" ; shift 2 ;;
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
  echo '  -i | --image <value>     nii or nii.gz file'
  echo '  -f | --field <value>     string indicating information to extract'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
unset OUTPUT
if [[ "${FIELD,,}" == "origin" ]]; then
  OUTPUT+=($(nifti_tool -disp_hdr -field qoffset_x -quiet -infiles ${IMAGE}))
  OUTPUT+=($(nifti_tool -disp_hdr -field qoffset_y -quiet -infiles ${IMAGE}))
  OUTPUT+=($(nifti_tool -disp_hdr -field qoffset_z -quiet -infiles ${IMAGE}))
elif [[ "${FIELD,,}" == "spacing" ]] || [[ "${FIELD,,}" == "space" ]]; then
  OUTPUT($(nifti_tool -disp_hdr -field pixdim -quiet -infiles ${IMAGE}))
  OUTPUT=(${OUTPUT[@]:1:3})
elif [[ "${FIELD,,}" == "size" ]] || [[ "${FIELD,,}" == "voxels" ]]; then
  OUTPUT=($(nifti_tool -disp_hdr -field dim -quiet -infiles ${IMAGE}))
  OUTPUT=(${OUTPUT[@]:1:3})
elif [[ "${FIELD,,}" == "volumes" ]] || [[ "${FIELD,,}" == "numtr" ]] || [[ "${FIELD,,}" == "trs" ]]; then
  OUTPUT=($(nifti_tool -disp_hdr -field dim -quiet -infiles ${IMAGE}))
  OUTPUT=(${OUTPUT[@]:4:1})
elif [[ "${FIELD,,}" == "tr" ]]; then
  OUTPUT($(nifti_tool -disp_hdr -field pixdim -quiet -infiles ${IMAGE}))
  OUTPUT=(${OUTPUT[@]:4:1})
elif [[ "${FIELD,,}" == "orient" ]] || [[ "${FIELD,,}" == "orientation" ]]; then
  OUTPUT=($(3dinfo -orient ${IMAGE}))
else
  OUTPUT($(nifti_tool -disp_hdr -field ${FIELD} -quiet -infiles ${IMAGE}))
fi
echo ${OUTPUT}

#===============================================================================
# End of Function
#===============================================================================
exit 0

