#!/bin/bash -e

#===============================================================================
# Coregistration of neuroimages
# Authors: Timothy R. Koscik
# Date: 2020-09-03
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
  if [[ "${DEBUG}" == "false" ]]; then
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
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
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
OPTS=`getopt -o hdvkl --long prefix:,\
fixed:,fixed-mask:,moving:,moving-mask:,\
rigid-only,affine-only,hardcore,stack-xfm,\
mask-dil:,interpolation:,\
template:,space:,\
dir-save:,dir-scratch:,dir-code:,dir-template:,dir-pincsource:,\
help,debug,verbose,keep,no-log -n 'parse-options' -- "$@"`
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
INTERPOLATION=BSpline[3]
RIGID_ONLY=false
AFFINE_ONLY=false
HARDCORE=false
STACK_XFM=false
TEMPLATE=HCPICBM
SPACE=1mm
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -d | --debug) DEBUG=true ; shift ;;
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
    --rigid-only) RIGID_ONLY=true ; shift ;;
    --affine-only) AFFINE_ONLY=true ; shift ;;
    --hardcore) HARDCORE=true ; shift ;;
    --stack-xfm) STACK_XFM=true ; shift ;;
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
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -d | --debug             keep scratch folder for debugging'
  echo '  -c | --dry-run           test run of function'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --other-inputs <value>   other inputs necessary for function'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-template <value>   directory where INC templates are stored,'
  echo '                           default: ${DIR_TEMPLATE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
MOVING=(${MOVING\\,\ })
N=${#MOVING[@]}
FROM=`${DIR_CODE}/bids/get_space_label.sh -i ${MOVING[0]}`

if [[ "${MOVING_MASK,,}" == "null" ]]; then
  FIXED_MASK=NULL
fi

if [[ "${FIXED,,}" != "null" ]]; then
  FIXED=(${FIXED\\,\ })
  N_FIXED=${#FIXED[@]}
  if [[ "${N_FIXED}" != "${N}" ]]; then exit 1; fi
  TO=`${DIR_CODE}/bids/get_space_label.sh -i ${FIXED[0]}`
else
  for (( i=0; i<${N_MOVING}; i++ )); do
    MOD=`${DIR_CODE}/bids/get_field.sh -i ${MOVING[${i}]} -f "modality"`
    if [[ "${MOD}" == "T2w" ]]; then
      FIXED+=(${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T2w.nii.gz)
    else
      FIXED+=(${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz)
    fi
  done
  if [[ "${MOVING_MASK}" != "NULL" ]]; then
    FIXED_MASK=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_mask-brain.nii.gz
  fi
  TO=${TEMPLATE}+${SPACE}
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${MOVING[0]}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${MOVING[0]} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${MOVING[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${MOVING[0]}`
fi

# setup directories
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/reg_from-${FROM}_to-${TO}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# Dilate Masks
if [[ "${MOVING_MASK}" != "NULL" ]]; then
  if [[ "${MASK_DIL}" > 0 ]]; then
    ImageMath 3 ${DIR_SCRATCH}/MOVING_mask-dil${MASK_DIL}.nii.gz MD ${MOVING_MASK} ${MASK_DIL}
    ImageMath 3 ${DIR_SCRATCH}/FIXED_mask-dil${MASK_DIL}.nii.gz MD ${FIXED_MASK} ${MASK_DIL}
    MOVING_MASK=${DIR_SCRATCH}/MOVING_mask-dil${MASK_DIL}.nii.gz    
    FIXED_MASK=${DIR_SCRATCH}/FIXED_mask-dil${MASK_DIL}.nii.gz
  fi
fi

# register to template
reg_fcn="antsRegistration"
reg_fcn="${reg_fcn} -d 3 --float 1 --verbose ${VERBOSE} -u 1 -z 1"
reg_fcn="${reg_fcn} -o ${DIR_SCRATCH}/xfm_"
reg_fcn="${reg_fcn} -r [${FIXED[0]},${MOVING[0]},1]"
reg_fcn="${reg_fcn} -t Rigid[0.2]"
for (( i=0; i<${N}; i++ )); do
  reg_fcn="${reg_fcn} -m Mattes[${FIXED[${i}]},${MOVING[${i}]},1,32,Regular,0.25]"
done
reg_fcn="${reg_fcn} -x [NULL,NULL]"
reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
reg_fcn="${reg_fcn} -f 8x8x4x2x1"
reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"

if [[ "${RIGID_ONLY,,}" == "false" ]]; then
  reg_fcn="${reg_fcn} -t Affine[0.5]"
  for (( i=0; i<${N}; i++ )); do
    reg_fcn="${reg_fcn} -m Mattes[${FIXED[${i}]},${MOVING[${i}]},1,32,Regular,0.25]"
  done
  reg_fcn="${reg_fcn} -x [NULL,NULL]"
  reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
  reg_fcn="${reg_fcn} -f 8x8x4x2x1"
  reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
  reg_fcn="${reg_fcn} -t Affine[0.1]"
  for (( i=0; i<${N}; i++ )); do
    reg_fcn="${reg_fcn} -m Mattes[${FIXED[${i}]},${MOVING[${i}]},1,64,Regular,0.30]"
  done
  reg_fcn="${reg_fcn} -x [${FIXED_MASK},${MOVING_MASK}]"
  reg_fcn="${reg_fcn} -c [2000x2000x2000x2000x2000,1e-6,10]"
  reg_fcn="${reg_fcn} -f 8x8x4x2x1"
  reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"

  if [[ "${AFFINE_ONLY,,}" == "false" ]]; then
    if [[ "${HARDCORE,,}" == "false" ]]; then
      reg_fcn="${reg_fcn} -t SyN[0.1,3,0]"
      for (( i=0; i<${N}; i++ )); do
        reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,4]"
      done
      reg_fcn="${reg_fcn} -x [NULL,NULL]"
      reg_fcn="${reg_fcn} -c [100x70x50x20,1e-6,10]"
      reg_fcn="${reg_fcn} -f 8x4x2x1"
      reg_fcn="${reg_fcn} -s 3x2x1x0vox"
      reg_fcn="${reg_fcn} -t SyN[0.1,3,0]"
      for (( i=0; i<${N}; i++ )); do
        reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,4]"
      done
      reg_fcn="${reg_fcn} -x [${FIXED_MASK},${MOVING_MASK}]"
      reg_fcn="${reg_fcn} -c [100x70x50x20,1e-6,10]"
      reg_fcn="${reg_fcn} -f 8x4x2x1"
      reg_fcn="${reg_fcn} -s 3x2x1x0vox"
    else
      reg_fcn="${reg_fcn} -t BsplineSyN[0.5,48,0]"
      for (( i=0; i<${N}; i++ )); do
        reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,4]"
      done
      reg_fcn="${reg_fcn} -x [${FIXED_MASK},${MOVING_MASK}]"
      reg_fcn="${reg_fcn} -c [2000x1000x1000x100x40,1e-6,10]"
      reg_fcn="${reg_fcn} -f 8x6x4x2x1"
      reg_fcn="${reg_fcn} -s 4x3x2x1x0vox"
      reg_fcn="${reg_fcn} -t BsplineSyN[0.1,48,0]"
      for (( i=0; i<${N}; i++ )); do
        reg_fcn="${reg_fcn} -m CC[${FIXED[${i}]},${MOVING[${i}]},1,6]"
      done
      reg_fcn="${reg_fcn} -x [${FIXED_MASK},${MOVING_MASK}]"
      reg_fcn="${reg_fcn} -c [20,1e-6,10]"
      reg_fcn="${reg_fcn} -f 1"
      reg_fcn="${reg_fcn} -s 0vox"
    fi
  fi
fi
eval ${reg_fcn}

# Apply registration to all modalities
for (( i=0; i<${N}; i++ )); do
  unset MOD xfm_fcn
  MOD=(`${DIR_CODE}/bids/get_field.sh -i ${MOVING[${i}]} -f "modality"`)
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
fi
if [[ "${RIGID_ONLY,,}" == "true" ]]; then
  mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
    ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-rigid.mat
else
  mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
    ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-affine.mat
fi

#===============================================================================
# End of Function
#===============================================================================

# Exit function ---------------------------------------------------------------
exit 0


