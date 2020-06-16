#!/bin/bash -e

#===============================================================================
# Coregistration of B0 to Base Image
# Authors: Timothy R. Koscik, PhD
# Date: 2020-06-15
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
DEBUG=false
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
OPTS=`getopt -o hdcvkl --long group:,prefix:,\
b0-image:,fixed:,fixed-mask:,init-xfm:,\
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
B0_IMAGE=
FIXED=
FIXED_MASK=
INIT_XFM=
DIR_SAVE=
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
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --b0-image) OTHER_INPUTS="$2" ; shift 2 ;;
    --fixed) TEMPLATE="$2" ; shift 2 ;;
    --fixed-mask) FIXED_MASK="$2" ; shift 2 ;;
    --init-xfm) INIT_XFM="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-template) DIR_TEMPLATE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
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
  echo '  -d | --debug             keep scratch folder for debugging'
  echo '  -c | --dry-run           test run of function'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --other-inputs <value>   other inputs necessary for function'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-template <value>   directory where INC templates are stored,'
  echo '                           default: ${DIR_TEMPLATE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${INPUT_FILE}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
DIR_XFM=${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

#===============================================================================
# Start of Function
#===============================================================================

# make temporary moving brain mask
bet ${B0_IMAGE} ${DIR_SCRATCH}/moving_mask-brain.nii.gz -m -n

antsRegistration \
  -d 3 -u 0 -z 1 -l 1 -n Linear -v ${VERBOSE} \
  -o ${DIR_SCRATCH}/${PREFIX}_xfm_ \
  -r ${INIT_XFM} \
  -t Rigid[0.25] \
  -m Mattes[${FIXED},${B0_IMAGE},1,32,Regular,0.2] \
  -c [1200x1200x100,1e-6,5] -f 4x2x1 -s 2x1x0vox \
  -x [${FIXED_MASK},${DIR_SCRATCH}/moving_mask-brain.nii.gz] \
  -t Affine[0.25] \
  -m Mattes[${FIXED},${B0_IMAGE},1,32,Regular,0.2] \
  -c [200x20,1e-6,5] -f 2x1 -s 1x0vox \
  -x [${FIXED_MASK},${DIR_SCRATCH}/moving_mask-brain.nii.gz] \
  -t SyN[0.2,3,0] \
  -m Mattes[${FIXED},${B0_IMAGE},1,32] \
  -c [40x20x0,1e-7,8] -f 4x2x1 -s 2x1x0vox \
  -x [${FIXED_MASK},${DIR_SCRATCH}/moving_mask-brain.nii.gz]  

TO=`${DIR_CODE}/bids/get_space_label.sh -i ${FIXED}`
mv ${DIR_SCRATCH}/${PREFIX}_xfm_0GenericAffine.mat ${DIR_XFM}/${PREFIX}_from-B0+raw_to-${TO}_xfm-affine.mat
mv ${DIR_SCRATCH}/${PREFIX}_xfm_1Warp.nii.gz ${DIR_XFM}/${PREFIX}_from-B0+raw_to-${TO}_xfm-syn.nii.gz
mv ${DIR_SCRATCH}/${PREFIX}_xfm_1InverseWarp.nii.gz ${DIR_XFM}/${PREFIX}_from-${TO}_from-B0+raw_xfm-syn.nii.gz

antsApplyTransforms -d 3 \
  -o [${DIR_XFM}/${PREFIX}_from-B0+raw_to-${TO}_xfm-stack.nii.gz,1] \
  -t ${DIR_XFM}/${PREFIX}_from-B0+raw_to-${TO}_xfm-syn.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-B0+raw_to-${TO}_xfm-affine.mat \
  -r ${FIXED}
antsApplyTransforms -d 3 \
  -o [${DIR_XFM}/${PREFIX}_from-${TO}_from-B0+raw_xfm-stack.nii.gz,1] \
  -t [${DIR_XFM}/${PREFIX}_from-B0+raw_to-${TO}_xfm-affine.mat,1] \
  -t ${DIR_XFM}/${PREFIX}_from-${TO}_from-B0+raw_xfm-syn.nii.gz \
  -r ${B0_IMAGE}

#===============================================================================
# End of Function
#===============================================================================

# Exit function ---------------------------------------------------------------
exit 0

