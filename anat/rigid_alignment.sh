#!/bin/bash -e

#===============================================================================
# Rigid Alignment of Images to Template
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-23
# Software: ANTs
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false

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
OPTS=`getopt -o hvl --long prefix:,\
image:,template:,space:,target:,\
dir-save:,dir-scratch:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
TEMPLATE=HCPICBM
SPACE=1mm
TARGET=T1w
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --target) TARGET="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
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
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --image <value>          full path to image to align'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --target <value>         Modality of image to warp to, e.g., T1w'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_CODE}/bids/get_dir.sh -i ${IMAGE})
SUBJECT=$(${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "sub")
SESSION=$(${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "ses")
if [ -z "${PREFIX}" ]; then
  PREFIX=$(${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE})
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}
  if [ -n "${SESSION}" ]; then
    DIR_SAVE=${DIR_SAVE}/ses-${SESSION}
  fi
fi
if [ -z "${SESSION}" ]; then
  DIR_XFM=${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}
else
  DIR_XFM=${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
fi

mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

# get image modality from filename ---------------------------------------------
MOD=($(${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "modality"))

# resample template image to desired output spacing ----------------------------
# always push image to an isotropic spacing to prevent issues with voxel
# aliasing varying by orientation
if [ -d ${DIR_TEMPLATE}/${TEMPLATE}/${SPACE} ]; then
  echo "resampling image to ${SPACE} isotropic spacing."
  DIR_TEMPLATE=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}
  FIXED=${DIR_TEMPLATE}/${TEMPLATE}_${SPACE}_${TARGET}.nii.gz
else
  dir_temp=($(ls -d ${DIR_TEMPLATE}/${TEMPLATE}/*um))
  if [ -n ${dir_temp} ]; then
    dir_temp=($(ls -d ${DIR_TEMPLATE}/${TEMPLATE}/*mm))
  fi
  DIR_TEMPLATE=${dir_temp[0]}
  space_temp=${DIR_TEMPLATE##*/}
  FIXED=${DIR_SCRATCH}/fixed_image.nii.gz
  TEMP_SPACE=${SPACE}
  TEMP_SPACE=${TEMP_SPACE//mm/}
  TEMP_SPACE=${TEMP_SPACE//um/}
  UNIT=${SPACE:(-2)}
  if [[  "${UNIT}" == "um" ]]; then
    TEMP_SPACE=$(echo "${TEMP_SPACE}/1000" | bc -l | awk '{printf "%0.3f", $0}')
  fi
  ResampleImage 3 \
    ${DIR_TEMPLATE}/${TEMPLATE}_${space_temp}_${TARGET}.nii.gz \
    ${FIXED} \
    ${TEMP_SPACE}x${TEMP_SPACE}x${TEMP_SPACE} 0 0 6
fi

# rigid registration -----------------------------------------------------------
if [[ "${MOD}" == "${TARGET}" ]]; then
  HIST_MATCH=1
else
  HIST_MATCH=0
fi
antsRegistration \
  -d 3 --float 1 --verbose ${VERBOSE} -u ${HIST_MATCH} -z 1 \
  -r [${FIXED},${IMAGE},1] \
  -t Rigid[0.1] \
  -m MI[${FIXED},${IMAGE},1,32,Regular,0.25] \
  -c [2000x2000x1000x1000,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -o ${DIR_SCRATCH}/xfm_

# apply transform --------------------------------------------------------------
antsApplyTransforms -d 3 \
  -i ${IMAGE} \
  -o ${DIR_SCRATCH}/${PREFIX}_prep-rigid+${TEMPLATE}+${SPACE}_${MOD}.nii.gz \
  -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
  -n BSpline[3] \
  -r ${FIXED}

# move files to appropriate locations ------------------------------------------
mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-${MOD}+raw_to-${TEMPLATE}+${SPACE}_xfm-rigid.mat
mv ${DIR_SCRATCH}/${PREFIX}_prep-rigid+${TEMPLATE}+${SPACE}_${MOD}.nii.gz \
  ${DIR_SAVE}/

#===============================================================================
# End of Function
#===============================================================================
exit 0

