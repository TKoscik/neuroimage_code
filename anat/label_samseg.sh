#!/bin/bash

#===============================================================================
# Wrapper for SAMSEG labelling from FreeSurfer
# -useful for generating WM hyperintensities
# -labels useful for generating myelin maps
# Authors: Timothy R. Koscik, PhD
# Date: 2020-11-10
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
HOSTNAME="$(uname -n)"
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  if [[ "${HOSTNAME,,}" == *"argon"* ]]; then export OMP_NUM_THREADS=1; fi
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
OPTS=$(getopt -o hkl --long prefix:,\
image:,contrast:,thresh:,\
pallidum-wm,lesion,wm-hyper,\
dir-save:,dir-scratch:,\
help,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
CONTRAST=
THRESH=0.3
PALLIDUM_WM=false
LESION=false
WM_HYPER=false
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
HELP=false

# NOTE: DIR_INC will set up in the init.json file, starting with first version
DIR_INC=/Shared/inc_scratch/code

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --contrast) CONTRAST="$2" ; shift 2 ;;
    --thresh) THRESH="$2" ; shift 2 ;;
    --pallidum-wm) PALLIDUM_WM="true" ; shift ;;
    --lesion) LESION="true" ; shift ;;
    --wm-hyper) WM_HYPER="true" ; shift ;;
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
  echo '  --other-inputs <value>   other inputs necessary for function'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

# set OpenMP Threads -----------------------------------------------------------
if [[ "${HOSTNAME,,}" == *"argon"* ]]; then
  NTHREADS=$(echo "${NSLOTS} / 7" | bc)
  if [[ "${NTHREADS}" == "0" ]]; then NTHREADS=1; fi
  export OMP_NUM_THREADS=${NTHREADS}
fi

#===============================================================================
# Start of Function
#===============================================================================
IMAGE=(${IMAGE//,/ })
N_IMAGE=${#IMAGE[@]}

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${IMAGE[0]})
if [ -z "${PREFIX}" ]; then
  SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE[0]} -f "sub")
  PREFIX="sub-${SUBJECT}"
  SESSION=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE[0]} -f "ses")
  if [[ -n ${SESSION} ]];
    PREFIX="${PREFIX}_ses-${SESSION}"
  fi
fi


mkdir -p ${DIR_SCRATCH}

# Set up contrasts if not specified --------------------------------------------
if [[ "${LESION}" == "true" ]] || [[ "${WM_HYPER}" == "true" ]]; then
  if [[ -z ${CONTRAST} ]]; then
    for (( i=0; i<${N_IMAGE}; i++ )); do
      unset MOD
      MOD=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE[${i}]} -f modality)
      if [[ "${MOD,,}" == "flair" ]]; || [[ "${MOD,,}" == "t2w" ]]; then
        CONTRAST+=(1)
      else
        echo "Contrast for ${MOD} not specified using value 0"
        CONTRAST+=(0)
      fi
    done
  fi
fi

# Run SAMSEG -------------------------------------------------------------------
samseg_fcn="run_samseg --input ${IMAGE[@]}"
if [[ "${PALLIDUM_WM}" == "false" ]]; then
  samseg_fcn="${samseg_fcn} --pallidum-separate"
fi
if [[ "${LESION}" == "true" ]] || [[ "${WM_HYPER}" == "true" ]]; then
  samseg_fcn="${samseg_fcn} --lesion"
  samseg_fcn="${samseg_fcn} --lesion-mask-pattern ${CONTRAST[@]//x/ }"
  samseg_fcn="${samseg_fcn} --threshold ${THRESH}"
fi
samseg_fcn="${samseg_fcn} --output ${DIR_SCRATCH}"
if [[ "${HOSTNAME,,}" == *"argon"* ]]; then
  samseg_fcn="${samseg_fcn} --threads ${NTHREADS}"
fi
eval ${samseg_fcn}

# Convert and save segmentation output -----------------------------------------
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAMSEG=${DIR_PROJECT}/derivatives/anat/label/samseg
else
  DIR_SAMSEG=${DIR_SAVE}
fi
mkdir -p ${DIR_SAMSEG}
mri_convert ${DIR_SCRATCH}/seg.mgz ${DIR_SAMSEG}/${PREFIX}_label-samseg.nii.gz

# Output WM Hyperintensity map if requested ------------------------------------
if [[ "${WM_HYPER}" == "true" ]]; then
  if [ -z "${DIR_SAVE}" ]; then
    DIR_HYPERWM=${DIR_PROJECT}/derivatives/anat/label/hyperWM
  else
    DIR_HYPERWM=${DIR_SAVE}
  fi
  mkdir -p ${DIR_HYPERWM}
  fslmaths ${DIR_SAMSEG}/${PREFIX}_label-samseg.nii.gz \
    -thr 99 -uthr 99 -bin \
    ${DIR_HYPERWM}/${PREFIX}_label-hyperWM.nii.gz
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0

