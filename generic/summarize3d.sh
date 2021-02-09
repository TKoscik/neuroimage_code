#!/bin/bash -e
#===============================================================================
# Generate summary values for ROI maps generated by BRAINSAutoworkup
# Authors: Timothy R. Koscik, PhD
# Date: 2020-04-15
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
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvla --long prefix:,\
label:,value:,stats:,lut:,no-append,\
dir-save:,dir-scratch:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
LABEL=
VALUE=
STATS=volume
LUT=
DIR_SAVE=
NO_APPEND=false
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -a | --no-append) NO_APPEND=true ; shift ;;
    --label) LABEL="$2" ; shift 2 ;;
    --value) VALUE="$2" ; shift 2 ;;
    --stats) STATS="$2" ; shift 2 ;;
    --lut) LUT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --label <value>          full file path to  label file'
  echo '  --value <value>          file path to NIfTI file containing the values'
  echo '                           to summarize, omit if only volumes are desired.'
  echo '  --stats <value>          which stats to report, options are:'
  echo '                           mean, nzmean, sigma, nzsigma, median, nzmedian'
  echo '                           mode, nzmode, min, nzmin, max, nzmax, volume'
  echo '  --lut <value>            full path to look up table for labels'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi
#===============================================================================
# Start of Function
#===============================================================================
if [[ -z "${VALUE}" ]]; then
  TRG_FILE=${LABEL}
else
  TRG_FILE=${VALUE}
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(getDir -i ${TRG_FILE})
PROJECT=$(getProject -i ${TRG_FILE})
PID=$(getField -i ${TRG_FILE} -f "sub")
SID=$(getField -i ${TRG_FILE} -f "ses")
if [ -z "${PREFIX}" ]; then
  PREFIX="sub-${PID}"
  if [[ -n ${SID} ]]; then
    PREFIX="${PREFIX}_ses-${SID}"
  fi
fi
mkdir -p ${DIR_SCRATCH}

if [[ -z "${LUT}" ]]; then
  LUT=${DIR_INC}/lut/lut-baw+brain.tsv
fi

STATS_LS=${STATS}
STATS=(${STATS//,/ })

# Generate stats using 3dROIstats in AFNI... it can't be beat for speed.
afni_fcn="3dROIstats -mask ${LABEL}"
for (( i=0; i<${#STATS[@]}; i++ )); do
  if [[ "${STATS[${i}],,}" == "nzmean" ]]; then afni_fcn="${afni_fcn} -nzmean"; fi
  if [[ "${STATS[${i}],,}" == "sigma" ]]; then afni_fcn="${afni_fcn} -sigma"; fi
  if [[ "${STATS[${i}],,}" == "nzsigma" ]]; then afni_fcn="${afni_fcn} -nzsigma"; fi
  if [[ "${STATS[${i}],,}" == "median" ]]; then afni_fcn="${afni_fcn} -median"; fi
  if [[ "${STATS[${i}],,}" == "nzmedian" ]]; then afni_fcn="${afni_fcn} -nzmedian"; fi
  if [[ "${STATS[${i}],,}" == "mode" ]]; then afni_fcn="${afni_fcn} -mode"; fi
  if [[ "${STATS[${i}],,}" == "nzmode" ]]; then afni_fcn="${afni_fcn} -nzmode"; fi
  if [[ "${STATS[${i}],,}" == "min" ]] | [[ "${STATS[${i}],,}" == "max" ]]; then afni_fcn="${afni_fcn} -minmax"; fi
  if [[ "${STATS[${i}],,}" == "nzmin" ]] | [[ "${STATS[${i}],,}" == "nzmax" ]]; then afni_fcn="${afni_fcn} -nzminmax"; fi
done
afni_fcn="${afni_fcn} -nzvoxels"
afni_fcn="${afni_fcn} ${TRG_FILE}"
afni_fcn="${afni_fcn} > ${DIR_SCRATCH}/${PREFIX}_tempSummary.tsv"
eval ${afni_fcn}

# Get voxel dimensions ---------------------------------------------------------
IFS=x read -r -a pixdimTemp <<< $(PrintHeader ${LABEL} 1)
PIXDIM="${pixdimTemp[0]}x${pixdimTemp[1]}x${pixdimTemp[2]}"

# Summarize stats according to look up table -----------------------------------
WHICH_SYS=$(uname --nodename)
if grep -q "argon" <<< "${WHICH_SYS,,}"; then
  module load R
fi
Rscript summarize3d.R \
  ${DIR_SCRATCH}/${PREFIX}_tempSummary.tsv \
  ${STATS_LS} \
  ${PIXDIM} \
  ${LUT}

# Setup save directories -------------------------------------------------------
if [[ -z "${VALUE}" ]]; then
  MOD=volume
else
  MOD=$(getField -i ${VALUE} -f "modality")
fi
if [[ -z "${DIR_SAVE}" ]]; then
  DIR_SAVE=${DIR_PROJECT}/summary
fi
mkdir -p ${DIR_SAVE}
LABEL_NAME=($(getField -i ${LABEL} -f "label"))
SUMMARY_FILE=${DIR_SAVE}/${PROJECT}_${MOD}_label-${LABEL_NAME}.tsv

# Check if summary file exists and create if not
HEADER=$(head -n 1 ${LUT})
HEADER=(${HEADER///})
HEADER=("${HEADER[@]:1}")
HEADER=(${HEADER[@]// /\t})
if [[ ! -f ${SUMMARY_FILE} ]]; then
  echo -e "participant_id\tsession_id\tsummary_date\tmeasure\t${HEADER[@]}" >> ${SUMMARY_FILE}
fi

# append to summary file or save output .txt if not
OUTPUT=${DIR_SCRATCH}/${PREFIX}_tempSummary_processed.tsv
if [[ "${NO_APPEND}" == "false" ]]; then
  cat ${OUTPUT} >> ${SUMMARY_FILE}
else
  echo ${HEADER} > ${DIR_SAVE}/${PREFIX}_${MOD}_label-${LABEL_NAME}_${DATE_SUFFIX}.tsv
  echo ${OUTPUT} >> ${DIR_SAVE}/${PREFIX}_${MOD}_label-${LABEL_NAME}_${DATE_SUFFIX}.tsv
fi 

#===============================================================================
# End of Function
#===============================================================================
exit 0

