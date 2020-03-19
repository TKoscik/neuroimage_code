#!/bin/bash -e

#===============================================================================
# Registration of images to a participant's base image
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-25
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hcvksl \
--long group:,prefix:,\
fixed-image:,fixed-modality:,fixed-space:,\
moving-image:,moving-modality:,moving-space:,\
do-syn,\
dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,dry-run,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S)
GROUP=
PREFIX=
FIXED_IMAGE=
FIXED_MODALITY=T1w
FIXED_SPACE=native
MOVING_IMAGE=
DO_SYN=false
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
DRY_RUN=false
VERBOSE=0
KEEP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -c | --dry-run) DRY-RUN=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -s | --do-syn) DO_SYN=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --fixed-image) FIXED_IMAGE="$2" ; shift 2 ;;
    --fixed-modality) FIXED_MODALITY="$2" ; shift 2 ;;
    --fixed-space) FIXED_SPACE="$2" ; shift 2 ;;
    --moving-image) MOVING_IMAGE+="$2" ; shift 2 ;;
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
  echo '  -c | --dry-run           test run of function'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --fixed-space <value>    "native" to keep base image spacing [default],'
  echo '                           "raw" to keep moving image spacing, or'
  echo '                           "MxNxO" to set desired spacing'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_NIMGCORE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${MOVING_IMAGE[0]}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${MOVING_IMAGE[0]} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${MOVING_IMAGE[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
DIR_XFM==${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

#===============================================================================
# Start of Function
#===============================================================================
# get number of moving images
NUM_MOVING=${#MOVING_IMAGE[@]}

# iterate of moving images ----
for (( i=0; i<${NUM_MOVING}; i++ )); do
  # Set reference image to specified spacing
  REFERENCE_IMAGE=${DIR_SCRATCH}/reference_image_${i}.nii.gz
  if [[ "${FIXED_SPACE[0]}" == "native" ]]; then
    # use base image space
    cp ${FIXED_IMAGE} ${REFERENCE_IMAGE}
  elif [[ "${FIXED_SPACE[0]}" == "raw" ]]; then
    # set reference image to spacing of moving image
    IFS=x read -r -a pixdim <<< $(PrintHeader ${MOVING_IMAGE} 1)
    ResampleImage 3 ${FIXED_IMAGE} ${REFERENCE_IMAGE} \
      ${pixdim[0]}x${pixdim[1]}x${pixdim[2]} 0 0 6
  else
    # set reference image to spacing provided
    ResampleImage 3  ${FIXED_IMAGE} ${REFERENCE_IMAGE} ${FIXED_SPACE} 0 0 6
  fi

  # perform ANTs registration
  reg_fcn="antsRegistration"
  reg_fcn="${reg_fcn} -d 3 --float 1 --verbose ${VERBOSE} -u 0 -z 1"
  reg_fcn="${reg_fcn} -o ${DIR_SCRATCH}/xfm${i}_"
  reg_fcn="${reg_fcn} [${FIXED_IMAGE},${MOVING_IMAGE[${i}]},1]"
  reg_fcn="${reg_fcn} -t Rigid[0.1]"
  reg_fcn="${reg_fcn} -m MI[${FIXED_IMAGE},${MOVING_IMAGE[${i}]},1,32,Regular,0.25]"
  reg_fcn="${reg_fcn} -c [2000x2000x1000x1000,1e-6,10] -f 8x4x2x1 -s 3x2x1x0vox"
  reg_fcn="${reg_fcn} -t Affine"
  reg_fcn="${reg_fcn} -m MI[${FIXED_IMAGE},${MOVING_IMAGE[${i}]},1,32,Regular,0.25]"
  reg_fcn="${reg_fcn} -c [2000x2000x1000x1000,1e-6,10] -f 8x4x2x1 -s 3x2x1x0vox"
  if [[ "${DO_SYN}" == "true" ]]; then
    reg_fcn="${reg_fcn} -t SyN[0.1,3,0]"
    reg_fcn="${reg_fcn} -m MI[${FIXED_IMAGE},${MOVING_IMAGE[${i}]},1,32,Regular,0.25]"
    reg_fcn="${reg_fcn} -c [500x200x100x50,1e-6,10] -f 8x4x2x1 -s 3x2x1x0vox"
  fi
  eval ${reg_fcn}

  # Apply transforms to image
  xfm_fcn="antsApplyTransforms -d 3 -n BSpline[3]"
  xfm_fcn="${xfm_fcn} -i ${MOVING_IMAGE[${i}]}"
  xfm_fcn="${xfm_fcn} -o ${DIR_SCRATCH}/reg${i}.nii.gz"
  if [[ "${DO_SYN}" == "true" ]]; then
    xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm${i}_1Warp.nii.gz"
  fi
  xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/xfm${i}_0GenericAffine.mat"
  xfm_fcn="${xfm_fcn} -r ${REFERENCE_IMAGE}"
  eval ${xfm_fcn}
  
  # get image modality
  MOD=(${MOVING_IMAGE[${i}]})
  MOD=(`basename "${MOD%.nii.gz}"`)
  MOD=(${MOD##*_})

  # Move registered images and transforms 
  FIXED_NAME=${FIXED_MODALITY}+${FIXED_SPACE}
  mv ${DIR_SCRATCH}/reg${i}.nii.gz \
    ${DIR_SAVE}/${PREFIX}_reg-${FIXED_NAME}_${MOD}.nii.gz
  mv ${DIR_SCRATCH}/xfm${i}_0GenericAffine.mat \
    ${DIR_XFM}/${PREFIX}_from-${MOD}+raw_to-${FIXED_NAME}_xfm-affine.mat
  if [[ "${DO_SYN}" == "true" ]]; then
    mv ${DIR_SCRATCH}/xfm${i}_1Warp.nii.gz \
      ${DIR_XFM}/${PREFIX}_from-${MOD}+raw_to-${FIXED_NAME}_xfm-syn.nii.gz
    mv ${DIR_SCRATCH}/xfm${i}_1InverseWarp.nii.gz \
      ${DIR_XFM}/${PREFIX}_from-${FIXED_NAME}_to-${MOD}+raw_xfm-syn.nii.gz
  fi
done

#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}/
  rmdir ${DIR_SCRATCH}
else
  rm ${DIR_SCRATCH}/*
  rmdir ${DIR_SCRATCH}
fi

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi
