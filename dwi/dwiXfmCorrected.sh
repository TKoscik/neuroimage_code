#!/bin/bash -e
#===============================================================================
# Apply transforms to corrected image
# Authors: Josh Cochran
# Date: 7/1/2020
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
    ${DIR_INC}/log/logProject.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    ${DIR_INC}/log/logSession.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hl --long prefix:,\
dir-dwi:,xfms:,ref-image:,\
dir-code:,dir-pincsource:,\
help,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DIR_DWI=
XFMS=
REF_IMAGE=
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --xfms) XFMS="$2" ; shift 2 ;;
    --ref-image) REF_IMAGE="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dir-dwi <value>        directory to save output, default varies by function'
  echo '  --xfms <value>           transform stacks, comma seperated'
  echo '  --ref-image <value>      referance image for transform'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
anyfile=$(ls ${DIR_DWI}/sub-*.nii.gz)
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${anyfile[0]})
PID=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f ses)
if [[ -z "${PREFIX}" ]]; then
  PREFIX="sub-${PID}"
  if [[ -n ${SID} ]]; then
    PREFIX="${PREFIX}_ses-${SID}"
  fi
fi

#===============================================================================
# Start of Function
#===============================================================================
XFMS=(${XFMS//,/ })
N_XFM=${#XFM[@]}
SPACE=$(${DIR_INC}/bids/get_field.sh -i ${XFMS[0]} -f to)

xfm_fcn="antsApplyTransforms -d 3 -e 3"
xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/${PREFIX}_dwi+corrected.nii.gz"
xfm_fcn="${xfm_fcn} -o ${DIR_DWI}/${PREFIX}_reg-${SPACE}_dwi.nii.gz"
for (( i=0; i<${N_XFM}; i++ )); do
  xfm_fcn="${xfm_fcn} -t ${XFMS[${i}]}"
done
xfm_fcn="${xfm_fcn} -r ${REF_IMAGE}"
eval ${xfm_fcn}

#===============================================================================
# End of Function
#===============================================================================
exit 0

