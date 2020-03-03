#!/bin/bash -e

#===============================================================================
# Rigid Alignment of Images to Template
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-23
# Software: ANTs
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvl --long researcher:,project:,group:,subject:,session:,prefix:,\
image:,mask:,mask-dil:,orig-space:,template:,space:,affine-only,hardcore,stack-xfm,
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S)
RESEARCHER=
PROJECT=
GROUP=
SUBJECT=
SESSION=
PREFIX=
IMAGE=
MASK=
MASK_DIL=5
ORIG_SPACE=native
TEMPLATE=HCPICBM
SPACE=1mm
AFFINE_ONLY=false
HARDCORE=false
STACK_XFM=false
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
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE+="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --mask-dilation) MASK_DIL="$2" ; shift 2 ;;
    --orig-space) ORIG_SPACE="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --affine-only) AFFINE_ONLY=true ; shift ;;
    --hardcore) HARDCORE=true ; shift ;;
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
  echo '  --researcher <value>     directory containing the project,'
  echo '                           e.g. /Shared/koscikt'
  echo '  --project <value>        name of the project folder, e.g., iowa_black'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --subject <value>        subject identifer, e.g., 123'
  echo '  --session <value>        session identifier, e.g., 1234abcd'
  echo '  --image <value>          full path to image to align'
  echo '  --mask <value>           full path to fixed image mask, or comma-'
  echo '                           separated fixed and moving masks,'
  echo '                           e.g., [fixed_mask.nii.gz,moving-mask.nii.gz]'
  echo '  --mask-dilation <value>  Amount to dilate mask to avoid edge'
  echo '                           effects of registration'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --affine-only            No non-linear registration steps.'
  echo '                           (potentially useful for building'
  echo '                           within-subject averages)'
  echo '  --hardcore               Use hardcore non-linear registration,'
  echo '                           may provide more-accurate fine-scale'
  echo '                           registrations, however much more'
  echo '                           time-consuming.'
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

# Get time stamp for log -------------------------------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

# Setup directories ------------------------------------------------------------
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${RESEARCHER}/${PROJECT}/derivatives/anat/reg_${TEMPLATE}_${SPACE}
fi
DIR_XFM=${RESEARCHER}/${PROJECT}/derivatives/xfm
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

# set output prefix if not provided --------------------------------------------
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

#===============================================================================
# Start of Function
#===============================================================================
NUM_IMAGE=${#IMAGE[@]}

# get and set modalities for output and fixed image targets
DIR_TEMPLATE=${DIR_NIMGCORE}/templates_human/${TEMPLATE}/${SPACE}
for (( i=0; i<${NUM_IMAGE}; i++ )); then
  MOD_TEMP=(`basename "${IMAGE[${i}]%.nii.gz}"`)
  MOD+=(${MOD_TEMP##*_})
  if [[ "${MOD[${i}]}" == "T2w" ]]; then
    FIXED_IMAGE+=(${DIR_TEMPLATE}/${TEMPLATE}_${SPACE}_T1w.nii.gz)
  else
    FIXED_IMAGE+=(${DIR_TEMPLATE}/${TEMPLATE}_${SPACE}_T1w.nii.gz)
  fi
fi

# dilate mask if requested
if [[ "${MASK_DIL}" > 0 ]]; then
  ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+dil${MASK_DIL}.nii.gz \
    MD ${MASK} ${MASK_DIL}
  MASK=${DIR_SCRATCH}/${PREFIX}_mask-brain+dil${MASK_DIL}.nii.gz
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
if [ -z ${MASK} ]; then
  reg_fcn="${reg_fcn} -x ${MASK}"
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
    if [ -z ${MASK} ]; then
      reg_fcn="${reg_fcn} -x ${MASK}"
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
    if [ -z ${MASK} ]; then
      reg_fcn="${reg_fcn} -x ${MASK}"
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
    if [ -z ${MASK} ]; then
      reg_fcn="${reg_fcn} -x ${MASK}"
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
  OUT_NAME=${DIR_SCRATCH}/${PREFIX}_reg-${TEMPLATE}+${SPACE}_${MOD[${i}]}.nii.gz
  xfm_fcn="antsApplyTransforms -d 3 -n BSpline[3]"
  xfm_fcn="${xfm_fcn} -i ${IMAGE[${i}]}"
  xfm_fcn="${xfm_fcn} -o ${OUT_NAME}"
  if [[ "${AFFINE_ONLY}" == "false" ]]; then
    xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz"
  fi
  xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat"
  xfm_fcn="${xfm_fcn} -r ${FIXED_IMAGE[0]}"
  eval ${xfm_fcn}
  mv ${OUT_NAME} ${DIR_SAVE}/
done

# set output flags
FROM=${MOD[0]}+${ORIG_SPACE}
TO=${TEMPLATE}+${SPACE}

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

# Clean workspace --------------------------------------------------------------
touch ${DIR_SCRATCH}/f.chk
rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${RESEARCHER}/${PROJECT}/log/sub-${SUBJECT}_ses-${SESSION}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi
