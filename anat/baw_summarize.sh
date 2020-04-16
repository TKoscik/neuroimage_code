#!/bin/bash -e

#===============================================================================
# Generate summary values for ROI maps generated by BRAINSAutoworkup
# Authors: Timothy R. Koscik, PhD
# Date: 2020-04-15
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v DIR_PROJECT ]]; then
      PROJECT_LOG=${DIR_PROJECT}/log/${PREFIX}.log
      if [[ ! -f ${PROJECT_LOG} ]]; then
        echo -e 'operator\tfunction\tstart\tend\texit_status' > ${PROJECT_LOG}
      fi
      echo -e ${LOG_STRING} >> ${PROJECT_LOG}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvla --long group:,prefix:,\
label:,value:,stats:,lut:,no-append,\
dir-save:,dir-scratch:,dir-code:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
LABEL=
VALUE=
STATS=volume
LUT=
DIR_SAVE=
NO_APPEND=false
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
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
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo 'Author: <<author names>>'
  echo 'Date:   <<date of authorship>>'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  -b | --label         full file path to Brainstools/BRAINSAutoworkup'
  echo '                           labels (dust cleaned version, renamed to fit'
  echo '                           in BIDS IA format and to work with our'
  echo '                           summarize_3d function)'
  echo '  -v | --value <value>          file path to NIfTI file containing the values'
  echo '                           to summarize, omit if only volumes are desired.'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${LABEL}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${LABEL} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${LABEL} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}

if [ -z "${LUT}" ]; then
  LUT=${DIR_CODE}/lut/lut-baw+brain.tsv
fi
#===============================================================================
# Start of Function
#===============================================================================
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
if [[ -z ${VALUE} ]]; then
  afni_fcn="${afni_fcn} ${LABEL}"
else
  afni_fcn="${afni_fcn} ${VALUE}"
fi
afni_fcn="${afni_fcn} > ${DIR_SCRATCH}/sub-${SUBJECT}_ses-${SESSION}_tempSummary.txt"
eval ${afni_fcn}

# Get voxel dimensions
IFS=x read -r -a pixdimTemp <<< $(PrintHeader ${LABEL} 1)
PIXDIM="${pixdimTemp[0]}x${pixdimTemp[1]}x${pixdimTemp[2]}"

# Summarize stats according to look up table
WHICH_SYS=`uname --nodename`
if grep -q "argon" <<< "${WHICH_SYS,,}"; then
  module load R
fi
Rscript ${DIR_CODE}/anat/baw_summarize.R \
  ${DIR_SCRATCH}/sub-${SUBJECT}_ses-${SESSION}_tempSummary.txt \
  ${STATS_LS} \
  ${PIXDIM} \
  ${LUT}

# Setup save directories
if [ -z "${VALUE}" ]; then
  DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${LABEL}`
  PROJECT=`${DIR_CODE}/bids/get_project.sh -i ${LABEL}`
  MOD=volume
else
  DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${VALUE}`
  PROJECT=`${DIR_CODE}/bids/get_project.sh -i ${VALUE}`
  MOD=`${DIR_CODE}/bids/get_field.sh -i ${VALUE} -f "modality"`
fi
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/summary
fi
mkdir -p ${DIR_SAVE}
LABEL_NAME=(`${DIR_CODE}/bids/get_field.sh -i ${LABEL} -f "label"`)
SUMMARY_FILE=${DIR_SAVE}/${PROJECT}_${MOD}_label-${LABEL_NAME}.csv

# Check if summary file exists and create if not
HEADER=$(head -n 1 ${LUT})
HEADER=(${HEADER//\t/ })
HEADER=("${HEADER[@]:1}")
HEADER=${HEADER[@]// /\t}
if [[ ! -f ${SUMMARY_FILE} ]]; then
  echo -e ${HEADER} >> ${SUMMARY_FILE}
fi

# append to summary file or save output .txt if not
OUTPUT=${DIR_SCRATCH}/sub-${SUBJECT}_ses-${SESSION}_tempSummary_processed.txt
if [[ "${NO_APPEND}" == "false" ]]; then
  cat ${OUTPUT} >> ${SUMMARY_FILE}
else
  echo ${HEADER} > ${DIR_SAVE}/sub-${SUBJECT}_${SESSION}_${MOD}_label-${LABEL_NAME}_${DATE_SUFFIX}.tsv
  echo ${OUTPUT} >> ${DIR_SAVE}/sub-${SUBJECT}_${SESSION}_${MOD}_label-${LABEL_NAME}_${DATE_SUFFIX}.tsv
fi 

exit 0

