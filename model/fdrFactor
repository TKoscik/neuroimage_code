#!/bin/bash -e
#===============================================================================
# Calculate False Discovery Rate Factor
## using FWHM approach, resample ROI mask to FWHM resolutionand count non zero
## voxels. This is the FWHM-corrected FDR Correction Factor
# Authors: Timothy Koscik, PhD 
# Date: 2021-11-09
# CHANGELOG: <description of major changes to functionality>
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
    unset LOGSTR
    LOGSTR="${OPERATOR},${DIR_PROJECT},${PID},${SID},${HARDWARE},${KERNEL},${HPC_Q},${HPC_SLOTS},${FCN_NAME},${PROC_START},${PROC_STOP},${EXIT_CODE}"
    writeLog --benchmark --string ${LOGSTR}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvlor --long inputs:,mask:,lo:,hi:,\
dir-scratch:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ----------------------------------------------
INPUTS=
MASK=
LO=
HI=
DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    --inputs) INPUTS="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --lo) LO="$2" ; shift 2 ;;
    --hi) HI="$2" ; shift 2 ;;
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
  echo '  -h | --help            display command help'
  echo '  -l | --no-log          disable writing to output log'
  echo '  -v | --verbose         verbose output'
  echo '  --inputs               comma separate list of files to include in'
  echo '                         FWHM calculation, should match data to be'
  echo '                         modelled'
  echo '  --mask                 binary mask of region of interest,'
  echo '                         e.g., mask-brain'
  echo '  --lo                   lower limit of valid values in data'
  echo '  --hi                   upper limit of valid values'
  echo '  --dir-save             location to save output'
  echo '  --dir-scratch          location for temporary files'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
INPUTS=(${INPUTS//,/ })
N=${#INPUTS[@]}

# get BIDS info ----------------------------------------------------------------
DIR_PROJECT=$(getDir -i ${INPUTS[0]})

for (( i=0; i<${N}; i++ )); do
  # check if time series or not ------------------------------------------------
  IS4D=false
  NVOL=$(niiInfo -i ${INPUTS[${i}]} -f vols)
  if [[ ${NVOL} -ne 1 ]]; then
    MOD=$(getField -i ${INPUTS[${i}]} -f modality)
    if [[ "${MOD}" == "bold" ]]; then
      IS4D=true
    fi
  fi

  # check scratch is empty -----------------------------------------------------
  rm ${DIR_SCRATCH}/*

  # copy input to scratch for ease of use -------------------------------------
  cp ${INPUTS[${i}]} ${DIR_SCRATCH}/input.nii.gz
  cp ${MASK} ${DIR_SCRATCH}/mask.nii.gz

  # apply mask if porovided, copy to scratch for combining --------------------
  fslmaths ${DIR_SCRATCH}/input.nii.gz -mas ${DIR_SCRATCH}/mask.nii.gz \
    ${DIR_SCRATCH}/input.nii.gz

  # threshold image --------------------------------------------------------------
  if [[ -n ${THRESH_LO} ]]; then
    fslmaths ${DIR_SCRATCH}/input.nii.gz -thr ${THRESH_LO} \
      ${DIR_SCRATCH}/input.nii.gz
    fslmaths ${DIR_SCRATCH}/input.nii.gz -bin \
      ${DIR_SCRATCH}/mask.nii.gz -odt char
  fi
  if [[ -n ${THRESH_HI} ]]; then
    fslmaths ${DIR_SCRATCH}/input.nii.gz -uthr ${THRESH_HI} \
      ${DIR_SCRATCH}/input.nii.gz
    fslmaths ${DIR_SCRATCH}/input.nii.gz -bin \
      ${DIR_SCRATCH}/mask.nii.gz -odt char
  fi

  # calculate FWHM ---------------------------------------------------------------
  fwhm_fcn="FWHM=($(3dFWHMx"
  fwhm_fcn="${fwhm_fcn} -mask  ${DIR_SCRATCH}/mask.nii.gz"
  fwhm_fcn="${fwhm_fcn} -out -"
  if [[ "${IS4D}" == "false" ]]; then fwhm_fcn="${fwhm_fcn} -2difMAD"; fi
  fwhm_fcn="${fwhm_fcn} -ShowMeClassicFWHM"
  fwhm_fcn="${fwhm_fcn} -dset ${DIR_SCRATCH}/input.nii.gz))"
  eval ${fwhm_fcn}

  for j in {0..2}; do
    FWHM_AVG[${j}]=$(ezMath -x "${FWHM[${j}]}/${N}" -d 4)
  done
done

ResampleImage 3 ${MASK} ${DIR_SCRATCH}/mask-FWHM.nii.gz \
  ${FWHM_AVG[0]}x${FWHM_AVG[1]}x${FWHM_AVG[2]} 0 1 0

FDR_FACTOR=($(fslstats ${DIR_SCRATCH}/mask-FWHM.nii.gz -V))
echo ${FDR_FACTOR[0]}


#===============================================================================
# End of Function
#===============================================================================
exit 0

