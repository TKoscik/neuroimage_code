#!/bin/bash -e
#===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
#===============================================================================
# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hif --long image:,field:,help -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
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
if [[ "${FIELD,,}" == "origin" ]]; then
  OUT=$(PrintHeader ${IMAGE} 0)
fi
if [[ "${FIELD,,}" == "spacing" ]] || [[ "${FIELD,,}" == "space" ]]; then
  OUT=$(PrintHeader ${IMAGE} 1)
fi
if [[ "${FIELD,,}" == "size" ]] || [[ "${FIELD,,}" == "voxels" ]]; then
  OUT=$(PrintHeader ${IMAGE} 2)
fi
if [[ "${FIELD,,}" == "volumes" ]] || [[ "${FIELD,,}" == "num-tr" ]] || [[ "${FIELD,,}" == "trs" ]]; then
  OUT=$(PrintHeader ${IMAGE} | grep Dimens | cut -d ',' -f 4 | cut -d ']' -f 1)
fi
if [[ "${FIELD,,}" == "tr" ]]; then
  OUT=$(PrintHeader ${IMAGE} | grep "Voxel Spac" | cut -d ',' -f 4 | cut -d ']' -f 1)
fi

echo ${OUT}
#===============================================================================
# End of Function
#===============================================================================

