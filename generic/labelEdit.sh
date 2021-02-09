#!/bin/bash -e
#===============================================================================
# Merge label Files, with unique, sequential new numbers
# Authors: Timothy R. Koscik, Phd
# Date: 2021-02-08
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
    logBenchmark --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    if [[ -n "${DIR_PROJECT}" ]]; then
      logProject --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
      --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      if [[ -n "${SID}" ]]; then
        logSession --operator ${OPERATOR} \
        --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
        --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
        --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      fi
    fi
    if [[ "${FCN_NAME}" == *"QC"* ]]; then
      logQC --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} --scan-date ${SCAN_DATE} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE} \
      --notes ${NOTES}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvkl --long label:,level:,\
prefix:,dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
LABEL=
LEVEL=
PREFIX=
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --label) LABEL="$2" ; shift 2 ;;
    --level) LEVEL="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
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
  echo '  --other-inputs <value>   other inputs necessary for function'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
LABEL=(${LABEL//,/ })
N_LABEL=${#LABEL[@]}
LEVEL=(${LEVEL//;/ })

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(getDir -i ${LABEL[0]})
PID=$(getField -i ${LABEL[0]} -f sub)
SID=$(getField -i ${LABEL[0]} -f ses)

if [[ -z "${DIR_SAVE}" ]]; then
  DIR_SAVE=$(dirname ${LABEL[0]})
fi
mkdir -p ${DIR_SAVE}
if [[ -z "${PREFIX}" ]]; then
  TLS=($(ls ${DIR_SAVE}/label_edit*))
  PREFIX=label_edit_${#TLS[@]}
fi
mkdir -p ${DIR_SCRATCH}

# intialize output
MERGED=${DIR_SCRATCH}/${PREFIX}.nii.gz
fslmaths ${LABEL[0]} -mul 0 ${MERGED}
LABEL_TEMP=${DIR_SCRATCH}/label_temp.nii.gz
MASK_TEMP=${DIR_SCRATCH}/mask_temp.nii.gz

# loop over label Files
for (( i=0; i<${N_LABEL}; i++ )); do
  TLEVEL=(${LEVEL[${i}]//, })
  TN=${#TLEVEL[@]}
  for (( j=0; j<${TN}; j++ )); do
    MAX_LABEL=$(fslstats ${MERGED} -p 100)
    if [[ "${TLEVEL[${j}],,}" == "all" ]]; then
      LabelClustersUniquely 3 ${LABEL[${i}]} ${LABEL_TEMP} 0
      fslmaths ${LABEL_TEMP} -bin ${MASK_TEMP}
      fslmaths ${LABEL_TEMP} -add ${MAX_LABEL} -mas ${MASK_TEMP} -add ${MERGED} ${MERGED}
    elif [[ "${TLEVEL[${j}]}" == *":"* ]]; then
      TRANGE=(${TLEVEL[${j}]//\:/ })
      fslmaths ${LABEL[${i}]} -thr ${TRANGE[0]} -uthr ${TRANGE[0]} ${LABEL_TEMP}
      LabelClustersUniquely 3 ${LABEL_TEMP} ${LABEL_TEMP} 0
      fslmaths ${LABEL_TEMP} -bin ${MASK_TEMP}
      fslmaths ${LABEL_TEMP} -add ${MAX_LABEL} -mas ${MASK_TEMP} -add ${MERGED} ${MERGED}
    else
      fslmaths ${LABEL[${i}]} -thr ${TLEVEL[${j}]} -uthr ${TLEVEL[${j}]} -bin ${LABEL_TEMP}
      fslmaths ${LABEL_TEMP} -add ${MAX_LABEL} -mas ${LABEL_TEMP} -add ${MAX_LABEL} -add ${MERGED} ${MERGED}
    fi
  done
done

mv ${MERGED} ${DIR_SAVE}/${FILE_NAME}.nii.gz

#===============================================================================
# End of Function
#===============================================================================
exit 0

