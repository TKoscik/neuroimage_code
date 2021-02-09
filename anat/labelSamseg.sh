#!/bin/bash -e
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
KERNEL="$(uname -s)"
HARDWARE="$(uname -m)"
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  PROC_STOP=$(date +%Y-%m-%dT%H:%M:%S%z)
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
  if [[ "${NO_LOG}" == "false" ]]; then
    ${DIR_INC}/log/logBenchmark.sh --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    if [[ -n "${DIR_PROJECT}" ]]; then
      ${DIR_INC}/log/logProject.sh --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
      --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      if [[ -n "${SID}" ]]; then
        ${DIR_INC}/log/logSession.sh --operator ${OPERATOR} \
        --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
        --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
        --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      fi
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
if [[ $? != 0 ]]; then
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
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false

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
  echo '  --image <value>          comma-separated list of images'
  echo '  --contrast <value>       x-separated list of contrasts for each image,'
  echo '                           indicating direction of abnormality.'
  echo '                           e.g., for T1w and FLAIR, contrast would be 0,1'
  echo '                           where 1 indicates WM hyperintensities on FLAIR'
  echo '                           but no specific direction on T1w'
  echo '  --thresh <value>         probability do assign voxel as a lesion,'
  echo '                           default=0.3'
  echo '  --pallidum-wm            whether or not to try and process pallidum'
  echo '                           separately or treat as a WM structure. Useful'
  echo '                           when input images have sufficient contrast in'
  echo '                           pallidal regions'
  echo '  --lesion                 whether or not to segment WM lesions'
  echo '  --wm-hyper               whether or not to include a mask of WM'
  echo '                           hyperintensities in output'
  echo '  --dir-save <value>       directory to save output'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
IMAGE=(${IMAGE//,/ })
N_IMAGE=${#IMAGE[@]}

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${IMAGE[0]})
PID=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE} -f ses)
if [[ -z "${PREFIX}" ]]; then
  PREFIX="sub-${PID}"
  if [[ -n ${SESSION} ]]; then
    PREFIX="${PREFIX}_ses-${SID}"
  fi
fi
mkdir -p ${DIR_SCRATCH}

# Set up contrasts if not specified --------------------------------------------
if [[ "${LESION}" == "true" ]] || [[ "${WM_HYPER}" == "true" ]]; then
  if [[ -z ${CONTRAST} ]]; then
    for (( i=0; i<${N_IMAGE}; i++ )); do
      unset MOD
      MOD=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE[${i}]} -f modality)
      if [[ "${MOD,,}" == "flair" ]] || [[ "${MOD,,}" == "t2w" ]]; then
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
echo ${samseg_fcn}
eval ${samseg_fcn}

# Convert and save segmentation output -----------------------------------------
if [[ -z "${DIR_SAVE}" ]]; then
  DIR_SAMSEG=${DIR_PROJECT}/derivatives/inc/anat/label/samseg
else
  DIR_SAMSEG=${DIR_SAVE}
fi
mkdir -p ${DIR_SAMSEG}
mri_convert ${DIR_SCRATCH}/seg.mgz ${DIR_SAMSEG}/${PREFIX}_label-samseg.nii.gz

# Output WM Hyperintensity map if requested ------------------------------------
if [[ "${WM_HYPER}" == "true" ]]; then
  if [[ -z "${DIR_SAVE}" ]]; then
    DIR_HYPERWM=${DIR_PROJECT}/derivatives/inc/anat/label/hyperWM
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

