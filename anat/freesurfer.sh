#!/bin/bash -e

#===============================================================================
# Run Freesurfer
# Authors: Josh Cochran
# Date: 11/30/20
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
OPTS=$(getopt -o h --long \
t1:,t2:,version:,\
help -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
T1=
T2=
VERSION=7.1.0
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    --t1) T1="$2" ; shift 2 ;;
    --t2) T2="$2" ; shift 2 ;;
    --version) VERSION="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done


# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FCN_NAME=($(basename "$0"))
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  --t1 <value>             T1w images, can take multiple comma seperated images'
  echo '  --t2 <value>             T2w images, can take multiple comma seperated images'
  echo '  --version <value>        version of freesurfer to use; default: 7.1.0' 
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${T1})
PID=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f ses)
if [[ -z "${PREFIX}" ]]; then
  PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${T1})
fi
mkdir -p ${DIR_PROJECT}/derivatives/freesurfer/subject_dir

T1=(${T1//,/ })
T2=(${T2//,/ })
N_T1=${#T1[@]}
N_T2=${#T2[@]}

unset IMAGES
for (( i=0; i<${N_T1}; i++ )); do
  IMAGES+=(-i ${T1[${i}]}) 
done

for (( i=0; i<${N_T2}; i++ )); do
  IMAGES+=(-T2 ${T2[${i}]})
done
if [[ ${N_T2} -gt 0 ]];then
  IMAGES+=(-T2pial)
fi

export FREESURFER_HOME=/Shared/pinc/sharedopt/apps/freesurfer/Linux/x86_64/${VERSION}
export SUBJECTS_DIR=${DIR_PROJECT}/derivatives/freesurfer/subject_dir
export FS_LICENSE=/Shared/inc_scratch/license/freesurfer/${VERSION}/license.txt
source ${FREESURFER_HOME}/FreeSurferEnv.sh
recon-all -subject ${PREFIX} ${IMAGES[*]} -all

#===============================================================================
# End of Function
#===============================================================================
exit 0

