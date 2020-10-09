#!/bin/bash -e

#===============================================================================
# Fix orientation of mouse brain image
# Authors: Timothy R. Koscik, PhD
# Date: 2020-09-22
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
OPTS=`getopt -o hvl --long prefix:,\
image:,\
dir-save:,dir-scratch:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done
### NOTE: DIR_CODE, DIR_PINCSOURCE may be deprecated and possibly replaced
#         by DIR_INC for version 0.0.0.0. Specifying the directory may
#         not be necessary, once things are sourced

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FCN_NAME=($(basename "$0"))
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --image <value>          directory listing of image to process'
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
if [ -z "${PREFIX}" ]; then
  PREFIX=$(${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE})
  PREFIX="${PREFIX}_prep-reorient"
fi

if [ -z "${DIR_SAVE}" ]; then
  SUBJECT=$(${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "sub")
  SESSION=$(${DIR_CODE}/bids/get_field.sh -i ${IMAGE} -f "ses")
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}
  if [ -n "${SESSION}" ]; then
    DIR_SAVE=${DIR_SAVE}/ses-${SESSION}
  fi
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# Reorient image
ORIENT_CODE=($(3dinfo -orient ${IMAGE}))
X=${ORIENT_CODE:0:1}
Y=${ORIENT_CODE:2:1}

if [[ "${ORIENT_CODE:1:1}" == "P" ]]; then
  Z=A
elif [[ "${ORIENT_CODE:1:1}" == "A" ]]; then
  Z=P
elif [[ "${ORIENT_CODE:1:1}" == "S" ]]; then
  Z=I
elif [[ "${ORIENT_CODE:1:1}" == "I" ]]; then
  Z=S
fi
NEW_CODE="${X}${Y}${Z}"

OUTNAME=${DIR_SCRATCH}/${PREFIX}_${MOD}.nii.gz

3dresample -orient ${NEW_CODE,,} -prefix ${OUTNAME} -input ${IMAGE}
CopyImageHeaderInformation ${IMAGE} ${OUTNAME} ${OUTNAME} 1 1 0

mv ${OUTNAME} ${DIR_SAVE}/${PREFIX}_${MOD}.nii.gz
#===============================================================================
# End of Function
#===============================================================================

exit 0


