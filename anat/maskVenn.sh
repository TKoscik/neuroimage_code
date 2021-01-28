#!/bin/bash -e
#===============================================================================
# Convert a set of masks to a set of labels, where each possible overlap is a
# unique value, sort of like a Venn diagram
# Authors: Timothy R. Koscik
# Date: 2020-10-09
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
OPTS=$(getopt -o hkl --long prefix:,\
mask-ls:,label:,\
dir-save:,dir-scratch:,\
help,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
MASK_LS=
LABEL=venn
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
    --mask-ls) MASK_LS="$2" ; shift 2 ;;
    --label) LABEL="$2" ; shift 2 ;;
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
  echo '  --mask-ls <value>        comma-separated list of masks'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
MASK_LS=(${MASK_LS//,/ })
N_MASK=${#MASK_LS[@]}

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${MASK_LS[0]})
PID=$(${DIR_INC}/bids/get_field.sh -i ${MASK_LS[0]} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${MASK_LS[0]} -f ses)
if [ -z "${PREFIX}" ]; then
  PREFIX="sub-${PID}"
  if [[ -n ${SID} ]]; then
    PREFIX="${PREFIX}_ses-${SID}"
  fi
fi
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/mask
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#  Make label set
fslmaths ${MASK_LS[0]} -bin ${DIR_SCRATCH}/${PREFIX}_mask-${LABEL}.nii.gz
for (( i=1; i<${N_MASK}; i++ )); do
  MULTIPLIER=$(echo "2^${i}" | bc -l)
  fslmaths ${MASK_LS[${i}]} -bin -mul ${MULTIPLIER} -add ${DIR_SCRATCH}/${PREFIX}_mask-${LABEL}.nii.gz ${DIR_SCRATCH}/${PREFIX}_mask-${LABEL}.nii.gz
done
mv ${DIR_SCRATCH}/${PREFIX}_mask-${LABEL}.nii.gz ${DIR_SAVE}/

#===============================================================================
# End of Function
#===============================================================================

exit 0


