#!/bin/bash -e
#===============================================================================
# Extract B0 images from file, makes assumption that anything less than 10 is a B0
# Authors: Josh Cochran
# Date: 3/30/2020
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
OPTS=$(getopt -o hkl --long prefix:,\
dir-dwi:,dir-save:,\
keep,help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DIR_DWI=
KEEP=false
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
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
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --dir-dwi <value>        location of the raw DWI data'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
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


# B0 extracter ----------------------------------------------------------------
DWI=($(ls ${DIR_DWI}/*_dwi.nii.gz))
N_DWI=${#DWI[@]}
for (( i=0; i<${N_DWI}; i++ )); do
  NAME_DTI=${DWI[${i}]::-11}
  B0s=($(cat ${NAME_DTI}_dwi.bval))
  mkdir ${DIR_DWI}/split
  fslsplit ${DWI[${i}]} ${DIR_DWI}/split/${PREFIX}-split-0000 -t
  for j in ${!B0s[@]}; do 
    k=$(echo "(${B0s[${j}]}/10)" | bc)
    if [ ${k} -ne 0 ]; then
      rm ${DIR_DWI}/split/${PREFIX}-split-*000${j}.nii.gz
    fi
  done
  fslmerge -t ${NAME_DTI}_dwi_B0+raw.nii.gz ${DIR_DWI}/split/${PREFIX}*
  rm -r ${DIR_DWI}/split
done

#===============================================================================
# End of function
#===============================================================================
exit 0

