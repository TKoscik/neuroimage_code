#!/bin/bash -e
#===============================================================================
# Fix odd dimensions in file
# Authors: Josh Cochran & Timothy R. Koscik, PhD
# Date: 3/30/2020 - 2020-06-15
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
OPTS=$(getopt -o hl --long prefix:,\
dir-dwi:,dir-save:,dir-scratch:,\
keep,help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DIR_DWI=
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
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
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#==============================================================================
# START OF FUNCTION
#==============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
DWI_LS=($(ls ${DIR_DWI}/*_dwi.nii.gz))
N_DWI=${#DWI_LS[@]}
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${DWI_LS[0]})
PID=$(${DIR_INC}/bids/get_field.sh -i ${DWI_LS[0]} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${DWI_LS[0]} -f ses)

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_DWI}
fi
mkdir -p ${DIR_SAVE}

# Check and Fix Odd Dimensions -------------------------------------------------
for (( i=0; i<${N_DWI}; i++ )); do
  DWI=${DWI_LS[${i}]}
  NAME_BASE=$(${DIR_INC}/bids/get_bidsbase.sh -i ${DWI})
  unset DIM_TEMP
  DIM_TEMP=$(PrintHeader ${DWI} 2)
  DIM_TEMP=(${DIM_TEMP//x/ })
  DIMCHK=0
  for j in {0..2}; do
    if [ $((${DIM_TEMP[${j}]}%2)) -eq 1 ]; then
      DIM_TEMP[${j}]=$((${DIM_TEMP[${j}]}-1))
      DIMCHK=1
    fi
  done
  if [ ${DIMCHK} -eq 1 ]; then
    fslroi ${DWI} ${DIR_SAVE}/${NAME_BASE}.nii.gz 0 ${DIM_TEMP[0]} 0 ${DIM_TEMP[1]} 0 ${DIM_TEMP[2]}
  fi
done

#==============================================================================
# End of function
#==============================================================================
exit 0

