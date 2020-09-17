#!/bin/bash -e

#===============================================================================
# Label images based on image intensity percentile, optionally within masked region,
# and of a minimal size
# Authors: Timothy R. Koscik, PhD
# Date: 2020-09-17
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
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
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
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
OPTS=`getopt -o hvkl --long prefix:,\
image:,mask:,thresh-dir:,percentile:,min-size:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
MASK=
THRESH_DIR=g
PERCENTILE=99
MIN_SIZE=5
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --thresh-dir) THRESH_DIR="$2" ; shift 2 ;;
    --percentile) PERCENTILE="$2" ; shift 2 ;;
    --min-size) MIN_SIZE="$2" ; shift 2 ;;
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
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --image <value>          image containing intensity values, e.g., FLAIR for WM hyperintensity maps.'
  echo '  --mask <value>           mask containing values which should be included'
  echo '  --thresh-dir <value>     which direction to apply threshold, g (>=) or l (<=), default=g'
  echo '  --percentile <value>     percentile for intensity threshold'
  echo '  --min-size <value>       minimum cluster size to include in final map'
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
DIR_PROJECT=$(${DIR_CODE}/bids/get_dir.sh -i ${IMAGE})
SUBJECT=$(${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "sub")
SESSION=$(${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "ses")
if [ -z "${PREFIX}" ]; then
  PREFIX=$(${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE})
fi

LABEL_NAME=$(${DIR_CODE}/bids/get_field.sh -i ${mask} -f "label")
if [[ -z "${LABEL_NAME}" ]]; then
  LABEL_NAME=$(${DIR_CODE}/bids/get_field.sh -i ${mask} -f "mask")
  if [[ -z "${LABEL_NAME}" ]]; then
    LABEL_NAME=ROI
  fi
fi

TEST_DIR=(g l)
if [[ ! "${TEST_DIR[@]}" =~ "${THRESH_DIR}" ]]; then
  echo "unrecognized threshold direction, must be g or l"
fi

LABEL="${LABEL_NAME}+${THRESH_DIR}${PERCENTILE}+sz${MIN_SIZE}"

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/label/${LABEL}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# intensity threshold image
THRESH=$(fslstats ${IMAGE} -k ${MASK} -P ${PERCENTILE})
if [[ "${THRESH_DIR}" == "g" ]]; then
  fslmaths ${IMAGE} -thr ${THRESH} -mas ${MASK} -bin ${DIR_SCRATCH}/${PREFIX}_thresh.nii.gz
else
  fslmaths ${IMAGE} -uthr ${THRESH} -mas ${MASK} -bin ${DIR_SCRATCH}/${PREFIX}_thresh.nii.gz
fi

if [[ "${MIN_SIZE}" != "0" ]]; then
  ${FSLDIR}/bin/cluster --in=${DIR_SCRATCH}/${PREFIX}_thresh.nii.gz --thresh=0.5 --osize=${DIR_SCRATCH}/${PREFIX}_clust.nii.gz > /dev/null
  fslmaths ${DIR_SCRATCH}/${PREFIX}_clust.nii.gz -thr ${MIN_SIZE} -bin ${DIR_SCRATCH}/${PREFIX}_clust.nii.gz
  mv ${DIR_SCRATCH}/${PREFIX}_clust.nii.gz ${DIR_SAVE}/${PREFIX}_label-${LABEL}.nii.gz
else
  mv ${DIR_SCRATCH}/${PREFIX}_thresh.nii.gz ${DIR_SAVE}/${PREFIX}_label-${LABEL}.nii.gz
fi

#===============================================================================
# End of Function
#===============================================================================

exit 0


