#!/bin/bash -e
#===============================================================================
# Autoconvert DICOM files within a specified folder
# Authors: Timothy R. Koscik
# Date: 2021-01-27
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(unname -s)"
HARDWARE="$(uname -m)"
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  PROC_STOP=$(date +%Y-%m-%dT%H:%M:%S%z)
  ${DIR_INC}/log/logBenchmark.sh \
    -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
    -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
}
trap egress EXIT


# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o h --long dir-input:,dir-output:,help -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DIR_INPUT=${DIR_IMPORT}
DIR_OUTPUT=${DIR_QC}/dicomConversion

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    --dir-input) DIR_INPUT="$2" ; shift 2 ;;
    --dcm-output) DIR_OUTPUT="$2" ; shift 2 ;;
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
  echo '  --dir-input <value>      directory listing containing zipped '
  echo '                           DICOM-containing folders'
  echo '                           default=${DIR_IMPORT}'
  echo '  --dir-output <value>     directory in which to create output folder'
  echo '                           default=${DIR_QC}/dicomConversion'
  echo ''
  NO_LOG=true
  exit 0
fi
#===============================================================================
# Start of Function
#===============================================================================

# get list of zip files --------------------------------------------------------
ZIP_LS=($(ls ${DIR_INPUT}/*.zip))
N_ZIP=${#N_ZIP[@]}

# loop over folders ------------------------------------------------------------
## setup new folder in DIR_QC/dicom/pi-PI_project-PROJECT_sub-PID_YYmmdd
## cp zip to new location
## convert to dicom
## autorename and generate qc tsv
## last step make a file called .QC_READY, QC won't start until this file exists

for (( i=0, i<${N_ZIP}; i++ )); do
  FNAME="${ZIP_LS[${i}]##*/}"
  BNAME="${FNAME%%.*}"

  mkdir -p ${DIR_OUTPUT}/${BNAME}
  mv ${ZIP_LS[${i}]} ${DIR_OUTPUT}/${BNAME}

  ${DIR_INC}/dicom/dicomConvert.sh \
  --input ${DIR_OUTPUT}/${BNAME}/${FNAME%%.*}.zip \
  --dir-save ${DIR_OUTPUT}/${BNAME}

  ${DIR_INC}/dicom/dicomAutoname.sh \
  --dir-input ${DIR_OUTPUT}/${BNAME}

  touch ${DIR_OUTPUT}/${BNAME}/.QC_READY
done

#===============================================================================
# End of Function
#===============================================================================
exit 0

