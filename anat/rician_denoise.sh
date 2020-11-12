#!/bin/bash -e
#===============================================================================
# Rician Denoising
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-23
# Software: ANTs
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false
umask 007

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
OPTS=`getopt -o hvkl --long prefix:,\
dimension:,image:,mask:,model:,shrink:,patch:,search:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DIM=3
IMAGE=
MASK=
MODEL=Rician
SHRINK=1
PATCH=1
SEARCH=2
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix)  PREFIX="$2" ; shift 2 ;;
    --dimension) DIM="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --model) MODEL="$2" ; shift 2 ;;
    --shrink) SHRINK="$2" ; shift 2 ;;
    --patch) PATCH="$2" ; shift 2 ;;
    --search) SEARCH="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

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
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         prefix for output,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  -d | --dimension <value> image dimension, 3=3D (default) or 4=4D'
  echo '  --image <value>          full path to image to denoise'
  echo '  --mask <value>           full path to binary mask'
  echo '  --model <value>          Rician (default) or Gaussian noise model'
  echo '  --shrink <value>         shrink factor, large images are time-'
  echo '                           consuming. default: 1'
  echo '  --patch <value>          patch radius, default:1 (1x1x1)'
  echo '  --search <value>         search radius, default:2 (2x2x2)'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${IMAGE})
if [ -z "${PREFIX}" ]; then
  PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${IMAGE})
fi

if [ -z "${DIR_SAVE}" ]; then
  SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE} -f "sub")
  SESSION=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE} -f "ses")
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}
  if [ -n "${SESSION}" ]; then
    DIR_SAVE=${DIR_SAVE}/ses-${SESSION}
  fi
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#===============================================================================
# Rician Denoising
#===============================================================================
# gather modailty for output
MOD=($(${DIR_INC}/bids/get_field.sh -i ${IMAGE} -f "modality"))

# Denoise image
dn_fcn="DenoiseImage -d ${DIM}"
dn_fcn="${dn_fcn} -n ${MODEL}"
dn_fcn="${dn_fcn} -s ${SHRINK}"
dn_fcn="${dn_fcn} -p ${PATCH}"
dn_fcn="${dn_fcn} -r ${SEARCH}"
dn_fcn="${dn_fcn} -v ${VERBOSE}"
dn_fcn="${dn_fcn} -i ${IMAGE}"
if [ -n "${MASK}" ]; then
  dn_fcn="${dn_fcn} -x ${MASK}"
fi
dn_fcn="${dn_fcn} -o [${DIR_SCRATCH}/${PREFIX}_prep-denoise_${MOD}.nii.gz,${DIR_SCRATCH}/${PREFIX}_prep-noise_${MOD}.nii.gz]"
eval ${dn_fcn}

mv ${DIR_SCRATCH}/${PREFIX}_prep-denoise* ${DIR_SAVE}/

if [[ "${KEEP}" == "true" ]]; then
  mv ${DIR_SCRATCH}/${PREFIX}_prep-noise* ${DIR_SAVE}/
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0

