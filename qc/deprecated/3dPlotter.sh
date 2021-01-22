#!/bin/bash -e 
#===============================================================================
# Creates a 3D interactive plot of an image, with or without a overlay in a HTML file
# Authors: Josh Cochran
# Date: 4/30/2020
#===============================================================================
PPROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${KEEP}" == "false" ]]; then
    if [[ -n ${DIR_SCRATCH} ]]; then
      if [[ -d ${DIR_SCRATCH} ]]; then
        if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
          rm -R ${DIR_SCRATCH}
        else
          rmdir ${DIR_SCRATCH}
        fi
      fi
    fi
  fi
  LOG_STRING=$(date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}")
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v ${DIR_PROJECT} ]]; then
      PROJECT_LOG=${DIR_PROJECT}/log/${PREFIX}.log
      if [[ ! -f ${PROJECT_LOG} ]]; then
        echo -e 'operator\tfunction\tstart\tend\texit_status' > ${PROJECT_LOG}
      fi
      echo -e ${LOG_STRING} >> ${PROJECT_LOG}
    fi
  fi
}
trap egress EXIT
 
# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hl --long image:,mask:,name:,\
dir-save:,dir-scratch:,\
help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"
 
# Set default values for function ---------------------------------------------
IMAGE=
MASK=
DIR_SAVE=
NAME=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=0
 
while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --name) NAME="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --image <value>          base image'
  echo '  --mask <value>           overlay image'
  echo '  --name <value>           output name of the file'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# downsample if bigger than 1mm isotropic
SPACE=$(${DIR_INC}/generic/nii_info.sh -i ${IMAGE} -f space)
SPACE=(${SPACE//,/ })
for i in {0..2}; do
  if [[ "${SPACE[${i}]}" < "1" ]]; then
    BNAME=$(basename ${IMAGE})
    ResampleImage 3 ${IMAGE} ${DIR_SCRATCH}/${BNAME} 1x1x1 0 0 6
    IMAGE=${DIR_SCRATCH}/${BNAME}
    if [[ -n ${MASK} ]]; then
      BNAME=$(basename ${MASK})
      antsApplyTransforms -d 3 -n NearestNeighbor \
        -i ${MASK} \
        -o ${DIR_SCRATCH}/${BNAME} \
        -r ${IMAGE} 
      MASK=${DIR_SCRATCH}/${BNAME}
    fi
    break
  fi
done

# write python job -------------------------------------------------------------
PY=${DIR_SCRATCH}/3dPlot.py
if [ -z "${MASK}" ]; then
  echo "from nilearn import plotting" >> ${PY}
  echo "import os" >> ${PY}
  echo "import nibabel as nib" >> ${PY}
  echo "" >> ${PY}
  echo "T1Variable = nib.load(os.path.join('"${IMAGE}"'))" >> ${PY}
  echo "html_view = plotting.view_img(T1Variable)" >> ${PY}
  echo "html_view.save_as_html('"${DIR_SAVE}/${NAME}".html')" >> ${PY}
  python ${PY}
else
  echo "from nilearn import plotting" >> ${PY}
  echo "import os" >> ${PY}
  echo "import nibabel as nib" >> ${PY}
  echo "" >> ${PY}
  echo "overlayVariable = nib.load(os.path.join('"${MASK}"'))" >> ${PY}
  echo "T1Variable = nib.load(os.path.join('"${IMAGE}"'))" >> ${PY}
  echo "" >> ${PY}
  echo "html_view = plotting.view_img(overlayVariable, bg_img=T1Variable)" >> ${PY}
  echo "html_view.save_as_html('"${DIR_SAVE}/${NAME}".html')" >> ${PY}
  python ${PY}
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0

