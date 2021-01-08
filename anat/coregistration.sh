#!/bin/bash -e
#===============================================================================
# Coregistration of neuroimages
# Authors: Timothy R. Koscik
# Date: 2020-09-03
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
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
OPTS=$(getopt -o hvkln --long prefix:,\
fixed:,fixed-mask:,moving:,moving-mask:,\
nonbrain,rigid-only,affine-only,hardcore,stack-xfm,\
mask-dil:,interpolation:,\
template:,space:,\
apply-to:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
FIXED=NULL
FIXED_MASK=NULL
MOVING=NULL
MOVING_MASK=NULL
MASK_DIL=2
NONBRAIN=false
INTERPOLATION=BSpline[3]
RIGID_ONLY=false
AFFINE_ONLY=false
HARDCORE=false
STACK_XFM=false
TEMPLATE=HCPICBM
SPACE=1mm
APPLY_TO=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=0
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --fixed) FIXED="$2" ; shift 2 ;;
    --fixed-mask) FIXED_MASK="$2" ; shift 2 ;;
    --moving) MOVING="$2" ; shift 2 ;;
    --moving-mask) MOVING_MASK="$2" ; shift 2 ;;
    --mask-dil) MASK_DIL="$2" ; shift 2 ;;
    --interpolation) INTERPOLATION="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --n | --nonbrain) NONBRAIN=true ; shift ;;
    --rigid-only) RIGID_ONLY=true ; shift ;;
    --affine-only) AFFINE_ONLY=true ; shift ;;
    --hardcore) HARDCORE=true ; shift ;;
    --stack-xfm) STACK_XFM=true ; shift ;;
    --apply-to) APPLY_TO="$2" ; shift ;;
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
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --fixed <value>          Optional target image to warp to, will'
  echo '                           use a template (HCPICBM) by default. This'
  echo '                           argument is only necessary if not using a'
  echo '                           premade template as the target of'
  echo '                           registration'
  echo '  --fixed-mask <value>     mask corresponding to specified fixed image'
  echo '  --moving <value>         Image to be warped to fixed image or template'
  echo '  --moving-mask <value>    mask for image to be warped, e.g., brain mask'
  echo '  --mask-dil <value>       Amount to dilate mask (to allow'
  echo '                           transformations to extend to edges of desired'
  echo '                           region); default=2 voxels'
  echo '  --interpolation <value>  Interpolation method to use, default=BSpline[3]'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --rigid-only             perform only rigid registration'
  echo '  --affine-only            perform rigid and affine registration only'
  echo '  --hardcore               perform rigid, affine, and BSplineSyN'
  echo '                           registration default is rigid, affine, SyN'
  echo '  --stack-xfm              stack affine and syn registrations after'
  echo '                           registration'
  echo '  --dir-save <value>       directory to save output, default varies by'
  echo '                           function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
MOVING=(${MOVING//,/ })
N=${#MOVING[@]}
FROM=$(${DIR_INC}/bids/get_space.sh -i ${MOVING[0]})

if [[ "${MOVING_MASK,,}" == "null" ]]; then
  FIXED_MASK=NULL
fi

HIST_MATCH=1
if [[ "${FIXED,,}" != "null" ]]; then
  FIXED=(${FIXED//,/ })
  N_FIXED=${#FIXED[@]}
  if [[ "${N_FIXED}" != "${N}" ]]; then exit 1; fi
  TO=(${DIR_INC}/bids/get_space.sh -i ${FIXED[0]})
else
  unset FIXED
  for (( i=0; i<${N_MOVING}; i++ )); do
    MOD=$(${DIR_INC}/bids/get_field.sh -i ${MOVING[${i}]} -f "modality")
    if [[ "${MOD}" == "T2w" ]]; then
      FIXED+=(${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T2w.nii.gz)
    else
      FIXED+=(${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz)
    fi
    #Use histogram matching
    MOD_FIXED=$(${DIR_INC}/bids/get_field.sh -i ${FIXED[${i}]} -f modality)
    if [[ "${MOD_FIXED}" != "${MOD}" ]]; then
      HIST_MATCH=0
    fi
  done
  if [[ "${MOVING_MASK}" != "NULL" ]]; then
    WHICH_MASK=$(${DIR_INC}/bids/get_field.sh -i ${MOVING_MASK} -f mask)
    WHICH_MASK=(${WHICH_MASK//+/ })
    WHICH_MASK=${WHICH_MASK[0]}
    if [[ -z ${WHICH_MASK} ]]; then
      FIXED_MASK=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_mask-brain.nii.gz
    else
      FIXED_MASK=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_mask-${WHICH_MASK}.nii.gz
    fi
  fi
  TO=${TEMPLATE}+${SPACE}
fi

# Check if presized template exists
if [[ ! -d "${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}" ]]; then
  UNIT=${SPACE:(-2)}
  SIZE=${SPACE//mm/}
  SIZE=${SIZE//um/}
  if [[  "${UNIT}" == "um" ]]; then
    SIZE=$(echo "${SIZE}/1000" | bc -l | awk '{printf "%0.3f", $0}')
  fi
  AVAIL_SIZE=($(ls ${DIR_TEMPLATE}/${TEMPLATE} | xargs -n 1 basename))
  MIN_AVAIL=999
  MIN_UNIT=um
  for (( i=0; i<${#AVAIL_SIZE[@]}; i++ )); do
    TSIZE=${AVAIL_SIZE[${i}]}
    TUNIT=${TSIZE:(-2)}
    TSIZE=${TSIZE//mm/}
    TSIZE=${TSIZE//um/}
    if [[  "${TUNIT}" == "um" ]]; then
      TSIZE=$(echo "${TSIZE}/1000" | bc -l | awk '{printf "%0.3f", $0}')
    fi
    if [[ "${TSIZE}" < "${MIN_AVAIL}" ]]; then
      MIN_AVAIL=TSIZE
      MIN_UNIT=TUNIT
    fi
  done
  for (( i=0; i<${N_FIXED}; i++ )); do
    TMOD=$(${DIR_INC}/bids/get_field.sh -i ${FIXED[${i}]} -f modality)
    ResampleImage 3 \
      ${DIR_TEMPLATE}/${TEMPLATE}/${MIN_UNIT}/${TEMPLATE}_${MIN_UNIT}_${TMOD}.nii.gz \
      ${DIR_SCRATCH}/${TEMPLATE}_${SPACE}_${TMOD}.nii.gz \
      ${SIZE}x${SIZE}x${SIZE} 0 0 6
    FIXED_NEW+=(${DIR_SCRATCH}/${TEMPLATE}_${SPACE_${TMOD}.nii.gz)
  done
  unset FIXED
  FIXED=${FIXED_NEW}

  WHICH_MASK=$(${DIR_INC}/bids/get_field.sh -i ${FIXED_MASK} -f mask)
  ResampleImage 3 \
    ${DIR_TEMPLATE}/${TEMPLATE}/${MIN_UNIT}/${TEMPLATE}_${MIN_UNIT}_mask-${WHICH_MASK}.nii.gz \
    ${DIR_SCRATCH}/${TEMPLATE}_${SPACE}_${WHICH_MASK}.nii.gz \
    ${SIZE}x${SIZE}x${SIZE} 0 1 6
  FIXED_MASK=${DIR_SCRATCH}/${TEMPLATE}_${SPACE}_${WHICH_MASK}.nii.gz
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${MOVING[0]})
SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${MOVING[0]} -f "sub")
SESSION=$(${DIR_INC}/bids/get_field.sh -i ${MOVING[0]} -f "ses")
if [ -z "${PREFIX}" ]; then
  PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${MOVING[0]})
fi

# setup directories
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/reg_${TO}
fi

DIR_XFM=${DIR_PROJECT}/derivatives/inc/anat/sub-${SUBJECT}
if [ -n "${SESSION}" ]; then
  DIR_XFM=${DIR_XFM}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

# Dilate Masks
if [[ "${MOVING_MASK}" != "NULL" ]]; then
  if [[ "${NONBRAIN}" == "true" ]]; then
    MOVING_NONBRAIN=${DIR_SCRATCH}/MOVING_mask-nonbrain.nii.gz
    FIXED_NONBRAIN=${DIR_SCRATCH}/FIXED_mask-nonbrain.nii.gz
    fslmaths ${MOVING_MASK} -binv ${MOVING_NONBRAIN}
    fslmaths ${FIXED_MASK} -binv ${FIXED_NONBRAIN}
  fi
  if [[ "${MASK_DIL}" > 0 ]]; then
    ImageMath 3 ${DIR_SCRATCH}/MOVING_mask-dil${MASK_DIL}.nii.gz MD ${MOVING_MASK} ${MASK_DIL}
    ImageMath 3 ${DIR_SCRATCH}/FIXED_mask-dil${MASK_DIL}.nii.gz MD ${FIXED_MASK} ${MASK_DIL}
    if [[ "${NONBRAIN}" == "true" ]]; then
      ImageMath 3 ${MOVING_NONBRAIN} MD ${MOVING_NONBRAIN} ${MASK_DIL}
      ImageMath 3 ${FIXED_NONBRAIN} MD ${FIXED_NONBRAIN} ${MASK_DIL}
    fi

    MOVING_MASK=${DIR_SCRATCH}/MOVING_mask-dil${MASK_DIL}.nii.gz
    FIXED_MASK=${DIR_SCRATCH}/FIXED_mask-dil${MASK_DIL}.nii.gz
  fi
else
  NONBRAIN="false"
fi

# register to template
reg_fcn="antsRegistration"
reg_fcn="${reg_fcn} -d 3 --float 1 --verbose ${VERBOSE} -u ${HIST_MATCH} -z 1"
reg_fcn="${reg_fcn} -o ${DIR_SCRATCH}/xfm_"
reg_fcn="${reg_fcn} -r [${FIXED[0]},${MOVING[0]},1]"
reg_fcn="${reg_fcn} -t Rigid[0.2]"
for (( i=0; i<${N}; i++ )); do
  reg_fcn="${reg_fcn} -m Mattes[${FIXED[${i}]},${MOVING[${i}]},1,32,Regular,0.25]"
done
if [[ "${MOVING_MASK}" != "NULL" ]]; then
  reg_fcn="${reg_fcn} -x [NULL,NULL]"
fi
reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
reg_fcn="${reg_fcn} -f 8x8x4x2x1"
reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
if [[ "${RIGID_ONLY,,}" == "false" ]]; then
  reg_fcn="${reg_fcn} -t Affine[0.5]"
  for (( i=0; i<${N}; i++ )); do
    reg_fcn="${reg_fcn} -m Mattes[${FIXED[${i}]},${MOVING[${i}]},1,32,Regular,0.25]"
  done
  if [[ "${MOVING_MASK}" != "NULL" ]]; then
    reg_fcn="${reg_fcn} -x [NULL,NULL]"
  fi
  reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
  reg_fcn="${reg_fcn} -f 8x8x4x2x1"
  reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
  
  if [[ "${NONBRAIN}" == "true" ]]; then
    reg_fcn="${reg_fcn} -t Affine[0.1]"
    for (( i=0; i<${N}; i++ )); do
      reg_fcn="${reg_fcn} -m Mattes[${FIXED[${i}]},${MOVING[${i}]},1,64,Regular,0.30]"
    done
    if [[ "${MOVING_MASK}" != "NULL" ]]; then
    reg_fcn="${reg_fcn} -x [${FIXED_NONBRAIN},${MOVING_NONBRAIN}]"
    fi
    reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
    reg_fcn="${reg_fcn} -f 8x8x4x2x1"
    reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
  fi

  reg_fcn="${reg_fcn} -t Affine[0.1]"
  for (( i=0; i<${N}; i++ )); do
    reg_fcn="${reg_fcn} -m Mattes[${FIXED[${i}]},${MOVING[${i}]},1,64,Regular,0.30]"
  done
  if [[ "${MOVING_MASK}" != "NULL" ]]; then
    reg_fcn="${reg_fcn} -x [${FIXED_MASK},${MOVING_MASK}]"
  fi
  reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
  reg_fcn="${reg_fcn} -f 8x8x4x2x1"
  reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"

  if [[ "${AFFINE_ONLY,,}" == "false" ]]; then
    if [[ "${HARDCORE,,}" == "false" ]]; then
      reg_fcn="${reg_fcn} -t SyN[0.1,3,0]"
      for (( i=0; i<${N}; i++ )); do
        reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,4]"
      done
      if [[ "${MOVING_MASK}" != "NULL" ]]; then
        reg_fcn="${reg_fcn} -x [NULL,NULL]"
      fi
      reg_fcn="${reg_fcn} -c [100x70x50x20,1e-6,10]"
      reg_fcn="${reg_fcn} -f 8x4x2x1"
      reg_fcn="${reg_fcn} -s 3x2x1x0vox"

      if [[ "${NONBRAIN}" == "true" ]]; then
        reg_fcn="${reg_fcn} -t SyN[0.1,3,0]"
        for (( i=0; i<${N}; i++ )); do
          reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,4]"
        done
        if [[ "${MOVING_MASK}" != "NULL" ]]; then
          reg_fcn="${reg_fcn} -x [${FIXED_NONBRAIN},${MOVING_NONBRAIN}]"
        fi
        reg_fcn="${reg_fcn} -c [100x70x50x20,1e-6,10]"
        reg_fcn="${reg_fcn} -f 8x4x2x1"
        reg_fcn="${reg_fcn} -s 3x2x1x0vox"
      fi

      reg_fcn="${reg_fcn} -t SyN[0.1,3,0]"
      for (( i=0; i<${N}; i++ )); do
        reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,4]"
      done
      if [[ "${MOVING_MASK}" != "NULL" ]]; then
        reg_fcn="${reg_fcn} -x [${FIXED_MASK},${MOVING_MASK}]"
      fi
      reg_fcn="${reg_fcn} -c [100x70x50x20,1e-6,10]"
      reg_fcn="${reg_fcn} -f 8x4x2x1"
      reg_fcn="${reg_fcn} -s 3x2x1x0vox"
    else
    
      if [[ "${NONBRAIN}" == "true" ]]; then
        reg_fcn="${reg_fcn} -t BsplineSyN[0.5,48,0]"
        for (( i=0; i<${N}; i++ )); do
          reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,4]"
        done
        if [[ "${MOVING_MASK}" != "NULL" ]]; then
          reg_fcn="${reg_fcn} -x [${FIXED_NONBRAIN},${MOVING_NONBRAIN}]"
        fi
        reg_fcn="${reg_fcn} -c [2000x1000x1000x100x40,1e-6,10]"
        reg_fcn="${reg_fcn} -f 8x6x4x2x1"
        reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
        reg_fcn="${reg_fcn} -t BsplineSyN[0.1,48,0]"
        for (( i=0; i<${N}; i++ )); do
          reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,6]"
        done
        if [[ "${MOVING_MASK}" != "NULL" ]]; then
          reg_fcn="${reg_fcn} -x [${FIXED_NONBRAIN},${MOVING_NONBRAIN}]"
        fi
        reg_fcn="${reg_fcn} -c [20,1e-6,10]"
        reg_fcn="${reg_fcn} -f 1"
        reg_fcn="${reg_fcn} -s 0vox"
      fi

      reg_fcn="${reg_fcn} -t BsplineSyN[0.5,48,0]"
      for (( i=0; i<${N}; i++ )); do
        reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,4]"
      done
      if [[ "${MOVING_MASK}" != "NULL" ]]; then
        reg_fcn="${reg_fcn} -x [${FIXED_MASK},${MOVING_MASK}]"
      fi
      reg_fcn="${reg_fcn} -c [2000x1000x1000x100x40,1e-6,10]"
      reg_fcn="${reg_fcn} -f 8x6x4x2x1"
      reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
      reg_fcn="${reg_fcn} -t BsplineSyN[0.1,48,0]"
      for (( i=0; i<${N}; i++ )); do
        reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,6]"
      done
      if [[ "${MOVING_MASK}" != "NULL" ]]; then
        reg_fcn="${reg_fcn} -x [${FIXED_MASK},${MOVING_MASK}]"
      fi
      reg_fcn="${reg_fcn} -c [20,1e-6,10]"
      reg_fcn="${reg_fcn} -f 1"
      reg_fcn="${reg_fcn} -s 0vox"
    fi
  fi
fi
eval ${reg_fcn}

# Apply registration to all modalities
for (( i=0; i<${N}; i++ )); do
  unset MOD xfm_fcn OUT_NAME
  MOD=($(${DIR_INC}/bids/get_field.sh -i ${MOVING[${i}]} -f "modality"))
  OUT_NAME=${DIR_SAVE}/${PREFIX}_reg-${TO}_${MOD}.nii.gz
  xfm_fcn="antsApplyTransforms -d 3 -n BSpline[3]"
  xfm_fcn="${xfm_fcn} -i ${MOVING[${i}]}"
  xfm_fcn="${xfm_fcn} -o ${OUT_NAME}"
  if [[ "${AFFINE_ONLY}" == "false" ]]; then
    if [[ "${RIGID_ONLY}" == "false" ]]; then
      xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz"
    fi
  fi
  xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat"
  xfm_fcn="${xfm_fcn} -r ${FIXED[0]}"
  eval ${xfm_fcn}
done

# apply transform to other images
if [[ -n ${APPLY_TO} ]]; then
  IMAGE_APPLY=(${APPLY_TO//,/ })
  N_APPLY=${#IMAGE_APPLY[@]}
  for (( i=0; i<${N_APPLY}; i++ )); do
    unset MOD OUT_NAME
    MOD=($(${DIR_INC}/bids/get_field.sh -i ${IMAGE_APPLY[${i}]} -f "modality"))
    OUT_BASE=$(${DIR_INC}/bids/get_bidsbase.sh -i ${IMAGE_APPLY[${i}]} -s)
    OUT_NAME="${DIR_SAVE}/${OUT_BASE}_reg-${TO}_${MOD}.nii.gz"
    if [[ -f ${OUT_NAME} ]]; then
      N_TEMP=($(ls ${DIR_SAVE}/${OUT_BASE}_reg-${TO}_${MOD}*))
      N_TEMP=${#N_TEMP[@]}
      OUT_NAME="${DIR_SAVE}/${OUT_BASE}_reg-${TO}_${MOD}+${N_TEMP}.nii.gz"
    fi
    xfm_fcn="antsApplyTransforms -d 3 -n BSpline[3]"
    xfm_fcn="${xfm_fcn} -i ${IMAGE_APPLY[${i}]}"
    xfm_fcn="${xfm_fcn} -o ${OUT_NAME}"
    if [[ "${AFFINE_ONLY}" == "false" ]]; then
      if [[ "${RIGID_ONLY}" == "false" ]]; then
        xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz"
      fi
    fi
    xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat"
    xfm_fcn="${xfm_fcn} -r ${FIXED[0]}"
    eval ${xfm_fcn}
  done
fi

# create and save stacked transforms
if [[ "${RIGID_ONLY,,}" == "false" ]]; then
  if [[ "${AFFINE_ONLY,,}" == "false" ]]; then
    if [[ "${STACK_XFM,,}" == "true" ]]; then
      antsApplyTransforms -d 3 \
        -o [${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-stack.nii.gz,1] \
        -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz \
        -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
        -r ${FIXED[0]}
      antsApplyTransforms -d 3 \
        -o [${DIR_XFM}/${PREFIX}_from-${TO}_to-${FROM}_xfm-stack.nii.gz,1] \
        -t ${DIR_SCRATCH}/xfm_1InverseWarp.nii.gz \
        -t [${DIR_SCRATCH}/xfm_0GenericAffine.mat,1] \
        -r ${FIXED[0]}
     fi
  fi
fi

# move transforms to appropriate location
if [[ "${RIGID_ONLY,,}" == "false" ]]; then
  if [[ "${AFFINE_ONLY,,}" == "false" ]]; then
    if [[ "${HARDCORE,,}" == "false" ]]; then
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
    mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
      ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-affine.mat
else
  mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
    ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-rigid.mat
fi

#===============================================================================
# End of Function
#===============================================================================

exit 0


