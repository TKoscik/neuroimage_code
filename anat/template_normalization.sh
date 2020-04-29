#!/bin/bash -e

#===============================================================================
# Rigid Alignment of Images to Template
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-23
# Software: ANTs
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
DEBUG=false
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v DIR_PROJECT ]]; then
      PROJECT_LOG=${DIR_PROJECT}/log/${PREFIX}.log
      if [[ ! -f ${PROJECT_LOG} ]]; then
        echo -e 'operator\tfunction\tstart\tend\texit_status' > ${PROJECT_LOG}
      fi
      echo -e ${LOG_STRING} >> ${PROJECT_LOG}
    fi
  fi
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hdvl --long group:,prefix:,\
image:,mask:,mask-dil:,orig-space:,template:,space:,\
affine-only,hardcore,stack-xfm,\
dir-save:,dir-scratch:,dir-code:,dir-template:,dir-pincsource:,\
help,debug,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
IMAGE=
MASK=
MASK_DIL=5
ORIG_SPACE=
TEMPLATE=HCPICBM
SPACE=1mm
AFFINE_ONLY=false
HARDCORE=false
STACK_XFM=false
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -d | --debug) DEBUG=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --mask-dilation) MASK_DIL="$2" ; shift 2 ;;
    --orig-space) ORIG_SPACE="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --affine-only) AFFINE_ONLY=true ; shift ;;
    --hardcore) HARDCORE=true ; shift ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-template) DIR_TEMPLATE="$2" ; shift 2 ;;
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
  echo '  -d | --debug             keep scratch folder for debugging'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --image <value>          full path to image(s) to align.'
  echo '                           Input images as commaseparated list,'
  echo '                           must be coregistered'
  echo '  --mask <value>           full path to fixed image mask, or comma-'
  echo '                           separated fixed and moving masks,'
  echo '                           e.g., [fixed_mask.nii.gz,moving-mask.nii.gz]'
  echo '  --mask-dilation <value>  Amount to dilate mask to avoid edge'
  echo '                           effects of registration'
  echo '  --orig-space <value>     label for original spacing, default=native'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --affine-only            No non-linear registration steps.'
  echo '                           (potentially useful for building'
  echo '                           within-subject averages), default=false'
  echo '  --hardcore               Use hardcore non-linear registration,'
  echo '                           may provide more-accurate fine-scale'
  echo '                           registrations, however much more'
  echo '                           time-consuming. default=false'
  echo '  --stack-xfm              save a stacked version of the transform,'
  echo '                           default=false'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-template <value>   directory where INC templates are stored,'
  echo '                           default: ${DIR_TEMPLATE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                       default: /Shared/pinc/sharedopt/apps/sourcefiles'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${IMAGE}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE}`
fi

DIR_XFM=${RESEARCHER}/${PROJECT}/derivatives/xfm
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_XFM}

#===============================================================================
# Start of Function
#===============================================================================
IMAGE=(${IMAGE//,/ })
NUM_IMAGE=${#IMAGE[@]}
MASK=(${MASK//,/ })
NUM_MASK=${#MASK[@]}

# get and set modalities for output and fixed image targets
DIR_TEMPLATE=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}
for (( i=0; i<${NUM_IMAGE}; i++ )); then
  MOD+=(`${DIR_CODE}/bids/get_field.sh -i ${IMAGE[${i}]} -f "modality"`)
  if [[ "${MOD[${i}]}" == "T2w" ]]; then
    FIXED_IMAGE+=(${DIR_TEMPLATE}/${TEMPLATE}_${SPACE}_T2w.nii.gz)
  else
    FIXED_IMAGE+=(${DIR_TEMPLATE}/${TEMPLATE}_${SPACE}_T1w.nii.gz)
  fi
fi

# set output flags and create save directory as needed
if [[ -z "${ORIG_SPACE}" ]]; then
  ORIG_SPACE=`${DIR_CODE}/bids/get_space_label.sh -i ${IMAGE[0]}`
fi
FROM=${MOD[0]}+${ORIG_SPACE}
TO=${TEMPLATE}+${SPACE}
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/reg_to-${TO}
fi
mkdir -p ${DIR_SAVE}

# dilate mask if requested
if [ -n ${MASK} ]; then
  if [[ "${MASK_DIL}" > 0 ]]; then
    for (( i=0; i<${NUM_MASK}; i++ )); do
      ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+dil${MASK_DIL}.nii.gz \
        MD ${MASK[${i}]} ${MASK_DIL}
      MASK[${i}]=${DIR_SCRATCH}/${PREFIX}_mask-brain+dil${MASK_DIL}.nii.gz
    done
  fi
fi

# register to template
reg_fcn="antsRegistration"
reg_fcn="${reg_fcn} -d 3 --float 1 --verbose ${VERBOSE} -u 1 -z 1"
reg_fcn="${reg_fcn} -o ${DIR_SCRATCH}/xfm_"
reg_fcn="${reg_fcn} -r [${FIXED_IMAGE[0],${IMAGE[0]},1]"
reg_fcn="${reg_fcn} -t Rigid[0.2]"
for (( i=0; i<${NUM_IMAGE}; i++ )); do
  reg_fcn="${reg_fcn} -m Mattes[${FIXED_IMAGE[${i}]},${IMAGE[${i}]},1,32,Regular,0.25]"
fi
reg_fcn="${reg_fcn} -x [NULL,NULL]"
reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
reg_fcn="${reg_fcn} -f 8x8x4x2x1"
reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
reg_fcn="${reg_fcn} -t Affine[0.5]"
for (( i=0; i<${NUM_IMAGE}; i++ )); do
  reg_fcn="${reg_fcn} -m Mattes[${FIXED_IMAGE[${i}]},${IMAGE[${i}]},1,32,Regular,0.25]"
done
reg_fcn="${reg_fcn} -x [NULL,NULL]"
reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
reg_fcn="${reg_fcn} -f 8x8x4x2x1"
reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
reg_fcn="${reg_fcn} -t Affine[0.1]"
for (( i=0; i<${NUM_IMAGE}; i++ )); do
  reg_fcn="${reg_fcn} -m Mattes[${FIXED_IMAGE[${i}]},${IMAGE[${i}]},1,64,Regular,0.30]"
done
if [ -n ${MASK} ]; then
  if [[ "${NUM_MASK}" == "1" ]]; then
    reg_fcn="${reg_fcn} -x ${MASK}"
  else
    reg_fcn="${reg_fcn} -x [${MASK[0]},${MASK[1]}]"
  fi
else
  reg_fcn="${reg_fcn} -x [NULL,NULL]"
fi
reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
reg_fcn="${reg_fcn} -f 8x8x4x2x1"
reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
if [[ "${AFFINE_ONLY}" == "false" ]]; then
  if [[ "${HARDCORE}" == "false" ]]; then
    reg_fcn="${reg_fcn} -t SyN[0.1,3,0]"
    for (( i=0; i<${NUM_IMAGE}; i++ )); do
      reg_fcn="${reg_fcn} -m CC[${FIXED_IMAGE[${i}]},${IMAGE[${i}]},1,4]"
    done
    if [ -n ${MASK} ]; then
      if [[ "${NUM_MASK}" == "1" ]]; then
        reg_fcn="${reg_fcn} -x ${MASK}"
      else
        reg_fcn="${reg_fcn} -x [${MASK[0]},${MASK[1]}]"
      fi
    else
      reg_fcn="${reg_fcn} -x [NULL,NULL]"
    fi
    reg_fcn="${reg_fcn} -c [100x70x50x20,1e-6,10]"
    reg_fcn="${reg_fcn} -f 8x8x4x2x1"
    reg_fcn="${reg_fcn} -s 3x2x1x0vox"
  else
    reg_fcn="${reg_fcn} -t BsplineSyN[0.5,48,0]"
    for (( i=0; i<${NUM_IMAGE}; i++ )); do
      reg_fcn="${reg_fcn} -m CC[${FIXED_IMAGE[${i}]},${IMAGE[${i}]},1,4]"
    done
    if [ -n ${MASK} ]; then
      if [[ "${NUM_MASK}" == "1" ]]; then
        reg_fcn="${reg_fcn} -x ${MASK}"
      else
        reg_fcn="${reg_fcn} -x [${MASK[0]},${MASK[1]}]"
      fi
    else
      reg_fcn="${reg_fcn} -x [NULL,NULL]"
    fi
    reg_fcn="${reg_fcn} -c [2000x1000x1000x100x40,1e-6,10]"
    reg_fcn="${reg_fcn} -f 8x6x4x2x1"
    reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
    reg_fcn="${reg_fcn} -t BsplineSyN[0.1,48,0]"
    for (( i=0; i<${NUM_IMAGE}; i++ )); do
      reg_fcn="${reg_fcn} -m CC[$${FIXED_IMAGE[${i}]},${IMAGE[${i}]},1,6]"
    done
    if [ -n ${MASK} ]; then
      if [[ "${NUM_MASK}" == "1" ]]; then
        reg_fcn="${reg_fcn} -x ${MASK}"
      else
        reg_fcn="${reg_fcn} -x [${MASK[0]},${MASK[1]}]"
      fi
    else
      reg_fcn="${reg_fcn} -x [NULL,NULL]"
    fi
    reg_fcn="${reg_fcn} -c [20,1e-6,10]"
    reg_fcn="${reg_fcn} -f 1"
    reg_fcn="${reg_fcn} -s 0vox"
  fi
fi
eval ${reg_fcn}


# Apply registration to all modalities
for (( i=0; i<${NUM_IMAGE}; i++ )); do
  OUT_NAME=${DIR_SAVE}/${PREFIX}_reg-${TO}_${MOD[${i}]}.nii.gz
  xfm_fcn="antsApplyTransforms -d 3 -n BSpline[3]"
  xfm_fcn="${xfm_fcn} -i ${IMAGE[${i}]}"
  xfm_fcn="${xfm_fcn} -o ${OUT_NAME}"
  if [[ "${AFFINE_ONLY}" == "false" ]]; then
    xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz"
  fi
  xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat"
  xfm_fcn="${xfm_fcn} -r ${FIXED_IMAGE[0]}"
  eval ${xfm_fcn}
done

# create and save stacked transforms
if [[ "${AFFINE_ONLY}" == "false" ]]; then
  if [[ "${STACK_XFM}" == "true" ]]; then
    antsApplyTransforms -d 3 \
      -o [${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-stack.nii.gz,1] \
      -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz \
      -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
      -r ${FIXED_IMAGE[0]}
    antsApplyTransforms -d 3 \
      -o [${DIR_XFM}/${PREFIX}_from-${TO}_to-${FROM}_xfm-stack.nii.gz,1] \
      -t ${DIR_SCRATCH}/xfm_1InverseWarp.nii.gz \
      -t [${DIR_SCRATCH}/xfm_0GenericAffine.mat,1] \
      -r ${FIXED_IMAGE[0]}
  fi
fi

# move transforms to appropriate location
if [[ "${AFFINE_ONLY}" == "false" ]]; then
  if [[ "${HARDCORE}" == "false" ]]; then
    mv ${DIR_SCRATCH}/xfm_1Warp.nii.gz \
      ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-syn.nii.gz
    mv ${DIR_SCRATCH}/xfm_1InverseWarp.nii.gz \
      ${DIR_XFM}/${PREFIX}_from-${TO}_to-${FROM}_xfm-syn.nii.gz
  else
    mv ${DIR_SCRATCH}/xfm_1Warp.nii.gz \
      ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-bspline.nii.gz
    mv ${DIR_SCRATCH}/xfm_1InverseWarp.nii.gz \
      ${DIR_XFM}/${PREFIX}_from-${TO}_to-${FROM}_xfm-bspline.nii.gz
  fi
fi
mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-affine.mat

#===============================================================================
# End of Function
#===============================================================================
exit 0

