#!/bin/bash -e
#===============================================================================
# Fix orientation of mouse brain image
# Authors: Timothy R. Koscik, PhD
# Date: 2020-09-22
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(unname -s)"
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
    ${DIR_INC}/log/logBenchmark.sh \
      -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
      -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
    ${DIR_INC}/log/logProject.sh \
      -d ${DIR_PROJECT} -p ${PID} -n ${SID} \
      -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
      -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
    ${DIR_INC}/log/logSession.sh \
      -d ${DIR_PROJECT} -p ${PID} -n ${SID} \
      -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
      -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvl --long prefix:,\
image:,\
dir-save:,dir-scratch:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --image <value>          directory listing of image to process'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${IMAGE})
PID=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE} -f ses)
if [[ -z "${PREFIX}" ]]; then
  PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${IMAGE})
  PREFIX="${PREFIX}_prep-reorient"
fi

if [[ -z "${DIR_SAVE}" ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/sub-${PID}
  if [[ -n "${SID}" ]]; then
    DIR_SAVE=${DIR_SAVE}/ses-${SID}
  fi
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# Reorient image
ORIENT_CODE=($(3dinfo -orient ${IMAGE}))
X=${ORIENT_CODE:0:1}
Y=${ORIENT_CODE:2:1}

if [[ "${ORIENT_CODE:1:1}" == "P" ]]; then
  Z=A
elif [[ "${ORIENT_CODE:1:1}" == "A" ]]; then
  Z=P
elif [[ "${ORIENT_CODE:1:1}" == "S" ]]; then
  Z=I
elif [[ "${ORIENT_CODE:1:1}" == "I" ]]; then
  Z=S
fi
NEW_CODE="${X}${Y}${Z}"

OUTNAME=${DIR_SCRATCH}/${PREFIX}_${MOD}.nii.gz

3dresample -orient ${NEW_CODE,,} -prefix ${OUTNAME} -input ${IMAGE}
CopyImageHeaderInformation ${IMAGE} ${OUTNAME} ${OUTNAME} 1 1 0

mv ${OUTNAME} ${DIR_SAVE}/${PREFIX}_${MOD}.nii.gz

#===============================================================================
# End of Function
#===============================================================================
exit 0

