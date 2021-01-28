#!/bin/bash -e
#===============================================================================
# Functional Timeseries -  Nuisance Regression
# Authors: Timothy R. Koscik
# Date: 2020-03-27
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
OPTS=$(getopt -o hvkl --long prefix:,template:,space:,\
ts-bold:,mask-brain:,pass-lo:,pass-hi:,regressor:,\
dir-save:,dir-scratch:,\
keep,help,verbose,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
TS_BOLD=
MASK_BRAIN=
PASS_LO=99999
PASS_HI=0
REGRESSOR=
TEMPLATE=HCPICBM
SPACE=2mm
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
KEEP=false
VERBOSE=0
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --mask-brain) MASK_BRAIN="$2" ; shift 2 ;;
    --pass-lo) PASS_LO="$2" ; shift 2 ;;
    --pass-hi) PASS_HI="$2" ; shift 2 ;;
    --regressor) REGRESSOR="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
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
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -c | --dry-run           test run of function'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        full path to single, run timeseries'
  echo '  --mask-brain <value>     full path to brain mask'
  echo '  --pass-lo <value>        upper passband limit, default=99999'
  echo '  --pass-hi <value>        lower passband limit, default=0'
  echo '  --regressor <value>      comma separated list of regressors to use'
  echo '  --template <value>       name of template to use, default=HCPICBM'
  echo '  --space <value>          spacing of template to use, default=2mm'
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
if [[ -f "${TS_BOLD}" ]]; then
  DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${TS_BOLD})
  PID=$(${DIR_INC}/bids/get_field.sh -i ${TS_BOLD} -f "sub")
  SID=$(${DIR_INC}/bids/get_field.sh -i ${TS_BOLD} -f "ses")
  if [[ -z "${PREFIX}" ]]; then
    PREFIX="sub-${PID}"
    if [[ -n ${SID} ]]; then
      PREFIX="${PREFIX}_ses-${SID}"
    fi
  fi
else
  echo "The BOLD file does not exist. aborting."
  exit 1
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/func/resid_${TEMPLATE}+${SPACE}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# partial out nuisance variance -----------------------------------------------
TR=$(PrintHeader ${TS_BOLD} | grep "Voxel Spac" | cut -d ',' -f 4 | cut -d ']' -f 1)
REGRESSOR=(${REGRESSOR//,/ })
N_REG=${#REGRESSOR[@]}

AFNI_CALL="3dTproject -input ${TS_BOLD}"
AFNI_CALL="${AFNI_CALL} -prefix ${DIR_SCRATCH}/resid.nii.gz"
AFNI_CALL="${AFNI_CALL} -mask ${MASK_BRAIN}"
AFNI_CALL="${AFNI_CALL} -bandpass ${PASS_HI} ${PASS_LO}"
for (( i=0; i<${N_REG}; i++ )); do
  AFNI_CALL="${AFNI_CALL} -ort ${REGRESSOR[${i}]}"
done
AFNI_CALL="${AFNI_CALL} -TR ${TR}"

eval ${AFNI_CALL}

mv ${DIR_SCRATCH}/resid.nii.gz ${DIR_SAVE}/${PREFIX}_bold.nii.gz

#===============================================================================
# End of Function
#===============================================================================
exit 0

