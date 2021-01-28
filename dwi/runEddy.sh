#!/bin/bash -e

#===============================================================================
# Run Eddy correction
# Authors: Josh Cochran & Timothy R. Koscik, PhD
# Date: 3/30/2020, 2020-06-15
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
OPTS=$(getopt -o hl --long prefix:,\
dir-dwi:,brain-mask:,\
help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DIR_DWI=
BRAIN_MASK=
HELP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --brain-mask) BRAIN_MASK="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --dir-dwi <value>        working dwi directory'
  echo '  --brain-mask <value>     dwi brain mask'
  echo ''
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
anyfile=($(ls ${DIR_DWI}/sub*.nii.gz))
if [ -z "${PREFIX}" ]; then
  SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f "sub")
  PREFIX="sub-${SUBJECT}"
  SESSION=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f "ses")
  if [[ -n ${SESSION} ]]; then
    PREFIX="${PREFIX}_ses-${SESSION}"
  fi
fi

#==============================================================================
# Eddy Correction
#==============================================================================
if [ -z ${B0_MASK} ]; then
  MASK_LS=$(ls ${DIR_DWI}/${PREFIX}_mod-B0_mask-brain+dil*.nii.gz)
  BRAIN_MASK=${MASK_LS[0]}
fi

# Run Eddy
eddy_openmp \
  --data_is_shelled \
  --imain=${DIR_DWI}/${PREFIX}_dwis.nii.gz \
  --mask=${BRAIN_MASK} \
  --acqp=${DIR_DWI}/${PREFIX}_dwisAcqParams.txt \
  --index=${DIR_DWI}/${PREFIX}_index.txt \
  --bvecs=${DIR_DWI}/${PREFIX}.bvec \
  --bvals=${DIR_DWI}/${PREFIX}.bval \
  --topup=${DIR_DWI}/topup_results \
  --out=${DIR_DWI}/${PREFIX}_dwi+corrected.nii.gz

#==============================================================================
# End of Function
#==============================================================================
exit 0

