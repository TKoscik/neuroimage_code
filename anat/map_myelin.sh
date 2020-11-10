#!/bin/bash
#===============================================================================
# Calculate Myelin Map
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-12
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
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
  LOG_STRING=$(date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}")
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v ${DIR_PROJECT} ]]; then
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
OPTS=$(getopt -o hvl --long prefix:,\
t1:,t2:,roi:,\
norm-t1:,norm-t2:,norm-roi:,\
template:,space:,\
dir-save:,dir-scratch:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
T1=
T2=
ROI=
NORMT1=
NORMT2=
NORMROI=
TEMPLATE=
SPACE=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --t1) T1="$2" ; shift 2 ;;
    --t2) T2="$2" ; shift 2 ;;
    --roi) ROI="$2" ; shift 2 ;;
    --norm-t1) NORMT1="$2" ; shift 2 ;;
    --norm-t2) NORMT2="$2" ; shift 2 ;;
    --norm-roi) NORMROI="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
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
  echo '  --t1 <value>             T1-weighted image'
  echo '  --t2 <value>             T2-weighted image'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${DIR_PROJECT}/derivatives/anat/myelin_${SPACE}'
  echo '                           Space will be drawn from folder name,'
  echo '                           e.g., native = native'
  echo '                                 reg_${TEMPLATE}_${SPACE}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_CODE}/bids/get_dir.sh -i ${T1})
if [ -z "${PREFIX}" ]; then
  SUBJECT=$(${DIR_CODE}/bids/get_field.sh -i ${T1} -f "sub")
  PREFIX=sub-${SUBJECT}
  SESSION=$(${DIR_CODE}/bids/get_field.sh -i ${T1} -f "ses")
  if [ -n "${SESSION}" ]; then
    PREFIX=${PREFIX}_ses-${SESSION}
  fi
fi

if [[ -n ${NORMT1} ]]; then
# Check if norms provided
  if [[ -z ${ROI} ]] & [[ ! -f ${ROI} ]]; then
    echo 'ROI file containing labels for normalization regions must be specified and exist'
    exit 1
  fi
elif [[ -n ${TEMPLATE}  ]]; then
# Check if template provided
  NORMT1=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz
  NORMT2=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T2w.nii.gz
  NORMROI=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_label-normMyelin.nii.gz
  if [[ -z ${ROI} ]]; then
    ROI=${NORMROI}
  fi
else
# attempt to infer template from file names
  # Check that images are coregistered, i.e., contain same "reg" flag
  T1_SPACE=$(${DIR_CODE}/bids/get_space.sh -i ${T1})
  T2_SPACE=$(${DIR_CODE}/bids/get_space.sh -i ${T2})
  if [[ "${T1_SPACE}" != "${T2_SPACE}" ]]; then
    echo "T1w and T2w not in same space, aborting"
    exit 1
  fi
  TEMP=(${T1_SPACE//+/ })
  TEMPLATE=${TEMP[0]}
  SPACE=${TEMP[1]}
  NORMT1=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz
  NORMT2=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T2w.nii.gz
  NORMROI=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_label-normMyelin.nii.gz
  if [[ -z ${ROI} ]]; then
    ROI=${NORMROI}
  fi
fi

# Copy images to scratch, for manipulation
cp ${NORMT1} ${DIR_SCRATCH}/norm_T1w.nii.gz
cp ${NORMT2} ${DIR_SCRATCH}/norm_T2w.nii.gz
cp ${NORMROI} ${DIR_SCRATCH}/norm_roi.nii.gz
cp ${T1} ${DIR_SCRATCH}/sub_T1w.nii.gz
cp ${T2} ${DIR_SCRATCH}/sub_T2w.nii.gz
cp ${ROI} ${DIR_SCRATCH}/sub_roi.nii.gz
gunzip ${DIR_SCRATCH}/*.gz

# create save directory
if [ -z "${DIR_SAVE}" ]; then
  if [[ -n ${TEMPLATE} ]]; then
    SUFFIX="${TEMPALTE}+${SPACE}"
  else
    SUFFIX="map"
  fi
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/myelin_${SUFFIX}
fi
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_SCRATCH}

# calculate myelin map
Rscript ${DIR_CODE}/anat/map_myelin.R \
  ${DIR_SCRATCH}/norm_T1w.nii \
  ${DIR_SCRATCH}/norm_T2w.nii \
  ${DIR_SCRATCH}/norm_roi.nii \
  ${DIR_SCRATCH}/sub_T1w.nii \
  ${DIR_SCRATCH}/sub_T2w.nii \
  ${DIR_SCRATCH}/sub_roi.nii

# zip and move output
gzip ${DIR_SCRATCH}/myelin.nii
CopyImageHeaderInformation ${T1} \
  ${DIR_SCRATCH}/myelin.nii.gz \
  ${DIR_SCRATCH}/${PREFIX}_myelin.nii.gz \
  1 1 1
mv ${DIR_SCRATCH}/${PREFIX}_myelin.nii.gz ${DIR_SAVE}

#==============================================================================
# End of function
#==============================================================================
exit 0

