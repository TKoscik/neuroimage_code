#!/bin/bash -e
#===============================================================================
# Functional Timeseries - Anatomical CompCorr
# Authors: Timothy R. Koscik
# Date: 2020-03-27
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
OPTS=$(getopt -o hl --long prefix:,\
ts-bold:,label-tissue:,value-csf:,value-wm:,\
dir-save:,dir-scratch:,\
help,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
TS_BOLD=
LABEL_TISSUE=
VALUE_CSF=1
VALUE_WM=3
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --label-tissue) LABEL_TISSUE="$2" ; shift 2 ;;
    --value-csf) VALUE_CSF="$2" ; shift 2 ;;
    --value-wm) VALUE_WM="$2" ; shift 2 ;;
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
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --label-tissue <value>   Full path to file containing tissue type labels'
  echo '  --value-csf <value>      numeric value indicating CSF in label file, default=1'
  echo '  --value-wm <value>       numeric value indicating WM in label file, default=3'
  echo '  --dir-save <value>       directory to save output, default:'
  echo '                             DIR_PROJECT/derivatives/inc/func/regressor/sub-###/ses-###'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi
#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${TS_BOLD})
PID=$(${DIR_INC}/bids/get_field.sh -i ${TS_BOLD} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${TS_BOLD} -f ses)
if [[ ! -f "${TS_BOLD}" ]]; then
  echo "The BOLD file does not exist. Exiting."
  exit 1
fi
DIR_SUBSES="sub-${PID}"
if [[ -n ${SID} ]]; then
  DIR_SUBSES="${DIR_SUBSES}_ses-${SID}"
fi
if [[ -z "${PREFIX}" ]]; then
  PREFIX=$(${DIR_INC}/bids/get_bidsbase -s -i ${TS_BOLD})
fi
if [[ -z "${DIR_SAVE}" ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/func
fi
DIR_REGRESSORS=${DIR_SAVE}/regressors/${DIR_SUBSES}
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_REGRESSORS}

# ANTs 3 Tissue Regressors (aCompCorr) ----------------------------------------
ImageMath 4 ${DIR_SCRATCH}/${PREFIX}_acompcorr.nii.gz \
  ThreeTissueConfounds ${TS_BOLD} ${LABEL_TISSUE} ${VALUE_CSF} ${VALUE_WM}

cat ${DIR_SCRATCH}/${PREFIX}_acompcorr_compcorr.csv | tail -n+2 > ${DIR_SCRATCH}/temp.1D
cut -d, -f1-1 ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_global-anatomy.1D
cut -d, -f1-1 --complement ${DIR_SCRATCH}/temp.1D > ${DIR_SCRATCH}/${PREFIX}_compcorr-anatomy.1D

mv ${DIR_SCRATCH}/${PREFIX}_global-anatomy.1D ${DIR_REGRESSORS}/
mv ${DIR_SCRATCH}/${PREFIX}_compcorr-anatomy.1D ${DIR_REGRESSORS}/

#===============================================================================
# End of Function
#===============================================================================
exit 0

