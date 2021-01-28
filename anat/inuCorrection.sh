#!/bin/bash -e
#===============================================================================
# Intensity Non-Uniformity Correction
# - Myelin mapping method, sqrt(T1w*T2w)
# - N4 bias correction
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-26
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
OPTS=$(getopt -o hvkl --long prefix:,\
dimension:,image:,method:,mask:,\
smooth-kernel:,\
weight:,shrink:,convergence,bspline:,hist-sharpen:,\
no-gm,urad:,do-t2,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DIM=3
IMAGE=
METHOD=
MASK=
SMOOTH_KERNEL=5
WEIGHT=
SHRINK=4
CONVERGENCE=[50x50x50x50,0.0]
BSPLINE=[200,3]
HIST_SHARPEN=[0.15,0.01,200]
NO_GM=false
URAD=30
DO_T2=false
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
    --dimension) DIM="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --method) METHOD="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --smooth-kernel) SMOOTH_KERNEL="$2" ; shift 2 ;;
    --weight) WEIGHT="$2" ; shift 2 ;;
    --shrink) SHRINK="$2" ; shift 2 ;;
    --convergence) CONVERGENCE="$2" ; shift 2 ;;
    --bspline) BSPLINE="$2" ; shift 2 ;;
    --hist-sharpen) HIST_SHARPEN="$2" ; shift 2 ;;
    --no-gm) NO_GM=true; shift ;;
    --urad) URAD="$2" ; shift 2 ;;
    --do-t2) DO_T2=true ; shift ;;
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
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         prefix for output,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dimension <value>      image dimension, 3=3D (default) or 4=4D'
  echo '                           T1T2 method only works on 3D images.'
  echo '  --image <value>          full path to image, if using T1T2, input must'
  echo '                           be a comma separted string for T1w and T2w'
  echo '                           images, image 1 must be T1w, image 2 must be T2w'
  echo '  --method <value>         one of N4 or T1T2 (case insensitive)'
  echo '  --mask <value>           full path to region mask'
  echo '  --smooth-kernel <value>  smoothing kernel size in mm, default: 5'
  echo '  --weight <value>         full path to weight image'
  echo '  --shrink <value>         shrink factor, default=4'
  echo '  --convergence <value>    convergence, [iterations,threshold]'
  echo '                           default=[50x50x50x50,0.0]'
  echo '  --bspline <value>        bspline fitting parameters,'
  echo '                           default=[200,3], seems to work well for 3T'
  echo '                           try changing to [85,3] for 7T'
  echo '  --hist-sharpen <value>   histogram sharpening,'
  echo '                           [FWHM,wienerNoise,binNumber]'
  echo '                           default=[0.15,0.01,200]'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/inc/anat/prep/sub-${SUBJECT}/ses-${SESSION}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
IMAGE=(${IMAGE//,/ })
if [[ "${#IMAGE[@]}" == 1 ]] && [[ "${METHOD,,}" == "t1t2" ]]; then
  echo "You must give a T1w AND T2w for the t1t2 method, switching to N4"
  METHOD="n4"
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${IMAGE[0]})
SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE[0]} -f "sub")
SESSION=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE[0]} -f "ses")
if [ -z "${PREFIX}" ]; then
  PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${IMAGE[0]})
fi

if [ -z "${DIR_SAVE}" ]; then
  if [ -n "${SESSION}" ]; then
    DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  else
    DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/sub-${SUBJECT}
  fi
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# INU correction --------------------------------------------------------------
if [[ "${METHOD,,}" == "t1t2" ]]; then
  # Form sqrt(T1w*T2w), mask this and normalise by the mean
  fslmaths ${IMAGE[0]} -mul ${IMAGE[1]} -abs -sqrt \
    ${DIR_SCRATCH}/temp_t1mult2.nii.gz -odt float
  fslmaths ${DIR_SCRATCH}/temp_t1mult2.nii.gz -mas ${MASK} \
    ${DIR_SCRATCH}/temp_t1mult2_brain.nii.gz
  mean_brain_val=$(fslstats ${DIR_SCRATCH}/temp_t1mult2_brain.nii.gz -M)
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
  STD=$(fslstats ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod.nii.gz -S)
  MEAN=$(fslstats ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod.nii.gz -M)
  lower=$(echo "${MEAN}-${STD}*0.5" | bc -l)
  fslmaths ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod.nii.gz -thr ${lower} \
    -bin -ero -mul 255 ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod_mask.nii.gz
  ${FSLDIR}/bin/cluster -i ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod_mask.nii.gz \
    -t 0.5 -o ${DIR_SCRATCH}/temp_cl_idx
  MINMAX=$(fslstats ${DIR_SCRATCH}/temp_cl_idx.nii.gz -R)
  MAX=$(echo "${MINMAX}" | cut -d ' ' -f 2)
  fslmaths -dt int ${DIR_SCRATCH}/temp_cl_idx -thr ${MAX} -bin -mul 255 \
    ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod_mask.nii.gz

  # Extrapolate normalised sqrt image from mask region out to whole FOV
  fslmaths ${DIR_SCRATCH}/temp_t1mult2_brain_norm.nii.gz \
    -mas ${DIR_SCRATCH}/temp_t1mult2_brain_norm_mod_mask.nii.gz -dilall \
    ${DIR_SCRATCH}/temp_bias_raw.nii.gz -odt float
  fslmaths ${DIR_SCRATCH}/temp_bias_raw.nii.gz -s ${SMOOTH_KERNEL} \
    ${DIR_SCRATCH}/biasT1T2_Field.nii.gz

  # Use bias field output to create corrected images
  fslmaths ${IMAGE[0]} -div ${DIR_SCRATCH}/biasT1T2_Field.nii.gz \
    ${DIR_SCRATCH}/biasT1T2_T1w.nii.gz
  fslmaths ${IMAGE[1]} -div ${DIR_SCRATCH}/biasT1T2_Field.nii.gz \
    ${DIR_SCRATCH}/biasT1T2_T2w.nii.gz

  # Move files to appropriate location
  mv ${DIR_SCRATCH}/biasT1T2_T1w.nii.gz ${DIR_SAVE}/${PREFIX}_prep-bias+T1T2_T1w.nii.gz
  mv ${DIR_SCRATCH}/biasT1T2_T2w.nii.gz ${DIR_SAVE}/${PREFIX}_prep-bias+T1T2_T2w.nii.gz
  if [[ "${KEEP}" == "true" ]]; then
    mv ${DIR_SCRATCH}/biasT1T2_Field.nii.gz ${DIR_SAVE}/${PREFIX}_prep-bias+T1T2+field.nii.gz
  fi
fi

# gather modality for output
MOD=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE[0]} -f "modality")

if [[ "${METHOD,,}" == "n4" ]]; then
  n4_fcn="N4BiasFieldCorrection"
  n4_fcn="${n4_fcn} -d ${DIM}"
  n4_fcn="${n4_fcn} -i ${IMAGE[0]}"
  if [ -n "${MASK}" ]; then
    n4_fcn="${n4_fcn} -x ${MASK}"
  fi
  if [ -n "${WEIGHT}" ]; then
    n4_fcn="${n4_fcn} -w ${WEIGHT}"
  fi
  n4_fcn="${n4_fcn} -r ${RESCALE}"
  n4_fcn="${n4_fcn} -s ${SHRINK}"
  n4_fcn="${n4_fcn} -c ${CONVERGENCE}"
  n4_fcn="${n4_fcn} -b ${BSPLINE}"
  n4_fcn="${n4_fcn} -t ${HIST_SHARPEN}"
  n4_fcn="${n4_fcn} -o [${DIR_SCRATCH}/${PREFIX}_prep-bias+N4_${MOD}.nii.gz,${DIR_SCRATCH}/${PREFIX}_prep-bias+N4+field_${MOD}.nii.gz]"
  n4_fcn="${n4_fcn} -v ${VERBOSE}"
  eval ${n4_fcn}
  
  mv ${DIR_SCRATCH}/${PREFIX}_prep-bias+N4_${MOD}.nii.gz ${DIR_SAVE}/
  if [[ "${KEEP,,}" == "true" ]]; then
    mv ${DIR_SCRATCH}/${PREFIX}_prep-bias+N4+field_${MOD}.nii.gz ${DIR_SAVE}/
  fi
fi

if [[ "${METHOD,,}" == "t1wm" ]]; then
  t1wm_fcn="3dUnifize"
  t1wm_fcn="${t1wm_fcn} -prefix ${DIR_SAVE}/${PREFIX}_prep-bias+T1WM_${MOD}.nii.gz"
  t1wm_fcn="${t1wm_fcn} -input ${IMAGE[0]}"
  if [[ "${NO_GM,,}" == "false" ]]; then
    t1wm_fcn="${t1wm_fcn} -GM"
  fi
  t1wm_fcn="${t1wm_fcn} -Urad ${URAD}"
  if [[ "${DO_T2,,}" == "true" ]]; then
    t1wm_fcn="${t1wm_fcn} -T2"
  fi
  eval ${t1wm_fcn}
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0

