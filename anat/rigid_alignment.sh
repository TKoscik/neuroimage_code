#!/bin/bash -e

#===============================================================================
# Rigid Alignment of Images to Template
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-23
# Software: ANTs
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvl --long group:,prefix:,\
image:,template:,space:,target:,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
IMAGE=
TEMPLATE=HCPICBM
SPACE=1mm
TARGET=T1w
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --target) TARGET="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
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
  echo 'Author: <<author names>>'
  echo 'Date:   <<date of authorship>>'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --image <value>          full path to image to align'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --target <value>         Modality of image to warp to, e.g., T1w'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: /Shared/nopoulos/nimg_core'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                       default: /Shared/pinc/sharedopt/apps/sourcefiles'
  echo ''
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${IMAGE}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${IMAGE} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${IMAGE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_NIMGCORE}/code/bids/get_bidsbase -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
DIR_XFM=${RESEARCHER}/${PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

#===============================================================================
# Start of Function
#===============================================================================
# get image modality from filename ---------------------------------------------
MOD=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${IMAGE} -f "modality"`)

# resample template image to desired output spacing ----------------------------
# always push image to an isotropic spacing to prevent issues with voxel
# aliasing varying by orientation
if [ -d ${DIR_NIMGCORE}/templates_human/${TEMPLATE}/${SPACE} ]; then
  echo "resampling image to ${SPACE} isotropic spacing."
  DIR_TEMPLATE=${DIR_NIMGCORE}/templates_human/${TEMPLATE}/${SPACE}
  FIXED=${DIR_TEMPLATE}/${TEMPLATE}_${SPACE}_${TARGET}.nii.gz
else
  dir_temp=(`ls -d ${DIR_NIMGCORE}/templates_human/${TEMPLATE}/*um`)
  if [ -n ${dir_temp} ]; then
    dir_temp=(`ls -d ${DIR_NIMGCORE}/templates_human/${TEMPLATE}/*mm`)
  fi
  DIR_TEMPLATE=${dir_temp[0]}
  space_temp=${DIR_TEMPLATE##*/}
  FIXED=${DIR_SCRATCH}/fixed_image.nii.gz
  SPACE=${SPACE//mm/}
  SPACE=${SPACE//um/}
  ResampleImage 3 \
    ${DIR_TEMPLATE}/${TEMPLATE}_${space_temp}_${TARGET}.nii.gz \
    ${FIXED} \
    ${SPACE}x${SPACE}x${SPACE} 0 0 6
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
  -o ${DIR_SCRATCH}/${PREFIX}_prep-rigid_${MOD}.nii.gz \
  -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
  -n BSpline[3] \
  -r ${FIXED}

# move files to appropriate locations ------------------------------------------
mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-${MOD}+raw_to-${TEMPLATE}+${SPACE}_xfm-rigid.mat
mv ${DIR_SCRATCH}/${PREFIX}_prep-rigid.nii.gz \
  ${DIR_SAVE}/${PREFIX}_reg-${TEMPLATE}+${SPACE}_${MOD}.nii.gz

#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

