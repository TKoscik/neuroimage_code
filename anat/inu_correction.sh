#!/bin/bash -e

#===============================================================================
# Intensity Non-Uniformity Correction based on T1w and T2 images
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-26
# Software: FSL
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hv --long researcher:,project:,group:,subject:,session:,prefix:,\
image:,method:,mask:,smooth-kernel:,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose -n 'parse-options' -- "$@"`
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
METHOD=
MASK=
SMOOTH_KERNEL=5
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix_ PREFIX="$2" ; shift 2 ;;
    --image) IMAGE+="$2" ; shift 2 ;;
    --method) METHOD="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --smooth-kernel) SMOOTH_KERNEL="$2" ; shift 2 ;;
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
  echo 'Author: Timothy R. Koscik, PhD'
  echo 'Date: 2020-02-25'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  --researcher <value>     directory containing the project,'
  echo '                           e.g. /Shared/koscikt'
  echo '  --project <value>        name of the project folder, e.g., iowa_black'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --subject <value>        subject identifer, e.g., 123'
  echo '  --session <value>        session identifier, e.g., 1234abcd'
  echo '  --image <value>          full path to image, multiple images allowed'
  echo '                           if using T1T2, image 1 must be T1w, image 2'
  echo '                           must be T2w'
  echo '  --method <value>         one of N4 or T1T2 (case insensitive)'
  echo '  --mask <value>           full path to region mask'
  echo '  --smooth-kernel <value>  smoothing kernel size in mm, default: 5'
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
  DIR_SAVE=${RESEARCHER}/${PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -r ${DIR_SCRATCH}
mkdir -r ${DIR_SAVE}

# set output prefix if not provided --------------------------------------------
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

# =============================================================================
# Start of Function
# =============================================================================
if [[ "${METHOD,,}" == "t1t2" ]]; then
  # Form sqrt(T1w*T2w), mask this and normalise by the mean
  fslmaths ${IMAGE[0]} -mul ${IMAGE[1]} -abs -sqrt \
    ${DIR_SCRATCH}/temp_t1mult2.nii.gz -odt float
  fslmaths ${DIR_SCRATCH}/temp_t1mult2.nii.gz -mas ${MASK} \
    ${DIR_SCRATCH}/temp_t1mult2_brain.nii.gz
  mean_brain_val=`fslstats ${DIR_SCRATCH}/temp_t1mult2_brain.nii.gz -M`
  fslmaths ${DIR_SCRATCH}/temp_t1mult2_brain.nii.gz -div ${mean_brain_val} \
    ${DIR_SCRATCH}/temp_t1mult2_brain_norm.nii.gz

  # Smooth the normalised sqrt image, within-mask smoothing: s(Mask*X)/s(Mask)
  fslmaths ${DIR_SCRATCH}/temp_t1mult2_brain_norm.nii.gz -bin -s ${SMOOTH_KERNEL} \
    ${DIR_SCRATCH}/temp_smooth_norm.nii.gz
  fslmaths ${DIR_SCRATCH}/temp_t1mult2_brain_norm.nii.gz -s ${SMOOTH_KERNEL} \
    -div ${DIR_SCRATCH}/temp_smooth_norm.nii.gz \
    ${DIR_SCRATCH}/temp_t1mult2_brain_norm_s${SMOOTH_KERNEL}.nii.gz

  # Divide normalised sqrt image by smoothed version
  # (to do simple bias correction)
  fslmaths ${DIR_SCRATCH}/temp_t1mult2_brain_norm.nii.gz \
    -div ${DIR_SCRATCH}/temp_t1mult2_brain_norm_s${SMOOTH_KERNEL}.nii.gz \
    ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod.nii.gz

  # Create a mask using a threshold at Mean - 0.5*Stddev, with filling of holes
  # to remove any non-grey/white tissue.
  STD=`fslstats ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod.nii.gz -S`
  MEAN=`fslstats ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod.nii.gz -M`
  lower=`echo "${MEAN} - (${STD} * 0.5)" | bc -l`
  fslmaths ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod.nii.gz -thr ${lower} \
    -bin -ero -mul 255 ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod_mask.nii.gz
  ${FSLDIR}/bin/cluster -i ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod_mask.nii.gz \
    -t 0.5 -o ${DIR_SCRATCH}/temp_cl_idx
  MINMAX=`fslstats ${DIR_SCRATCH}/temp_cl_idx.nii.gz -R`
  MAX=`echo "${MINMAX}" | cut -d ' ' -f 2`
  fslmaths -dt int ${DIR_SCRATCH}/temp_cl_idx -thr ${MAX} -bin -mul 255 \
    ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod_mask.nii.gz

  # Extrapolate normalised sqrt image from mask region out to whole FOV
  fslmaths ${DIR_SCRATCH}/temp_t1mult2_brain_norm.nii.gz \
    -mas ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod_mask.nii.gz -dilall \
    ${DIR_SCRATCH}/temp_bias_raw.nii.gz -odt float
  fslmaths ${DIR_SCRATCH}/temp_bias_raw.nii.gz -s ${smoothKernel} \
    ${DIR_SCRATCH}/biasT1T2_Field.nii.gz

  # Use bias field output to create corrected images
  fslmaths ${T1_IMAGE} -div ${DIR_SCRATCH}/biasT1T2_Field.nii.gz \
    ${DIR_SCRATCH}/biasT1T2_T1w.nii.gz
  fslmaths ${T2_IMAGE} -div ${DIR_SCRATCH}/biasT1T2_Field.nii.gz \
    ${DIR_SCRATCH}/biasT1T2_T2w.nii.gz

  # Move files to appropriate location
  mv ${DIR_SCRATCH}/biasT1T2_T1w.nii.gz ${DIR_SAVE}/${PREFIX}_prep-bias+T1T2_T1w.nii.gz
  mv ${DIR_SCRATCH}/biasT1T2_T2w.nii.gz ${DIR_SAVE}/${PREFIX}_prep-bias+T1T2_T2w.nii.gz
  if [[ "${KEEP}" == "true" ]]; then
    mv ${DIR_SCRATCH}/biasT1T2_Field.nii.gz ${DIR_SAVE}/${PREFIX}_prep-bias+T1T2+field.nii.gz
  fi
fi
fi

if [[ "${METHOD,,}" == "n4" ]]; then
  NUM_IMAGE=${#IMAGE[@]}
  for (( i=0; i<${NUM_IMAGE}; i++ )); then
    # gather modality for output
    MOD=(${IMAGE[${i}]})
    MOD=(`basename "${MOD%.nii.gz}"`)
    MOD=(${MOD##*_})

    N4BiasFieldCorrection -d 3 -r 1 -i ${IMAGE[${i}]} \
      -o [${DIR_SCRATCH}/${PREFIX}_prep-bias+N4_${MOD}.nii.gz,${DIR_SCRATCH}/${PREFIX}_prep-bias+N4+field_${MOD}.nii.gz]
    mv ${DIR_SCRATCH}/${PREFIX}_prep-bias+N4_${MOD}.nii.gz ${DIR_SAVE}/
    if [[ "${KEEP}" == "true" ]]; then
      mv ${DIR_SCRATCH}/${PREFIX}_prep-bias+N4+field_${MOD}.nii.gz ${DIR_SAVE}/
    fi
  done
fi

#===============================================================================
# End of Function
#===============================================================================
# Clean workspace --------------------------------------------------------------
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
LOG_FILE=${RESEARCHER}/${PROJECT}/log/sub-${SUBJECT}_ses-${SESSION}.log
date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}

