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
OPTS=`getopt -o hvl --long group:,prefix:,\
b0-image:,bo-mask:,fixed:,fixed-mask:,init-xfm:,\
dir-code:,dir-pincsource:,\
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
B0_MASK=
FIXED=
FIXED_MASK=
INIT_XFM=
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
    --b0-image) B0_IMAGE="$2" ; shift 2 ;;
    --b0-mask) B0_MASK="$2" ; shift 2 ;;
    --fixed) FIXED="$2" ; shift 2 ;;
    --fixed-mask) FIXED_MASK="$2" ; shift 2 ;;
    --init-xfm) INIT_XFM="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
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
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --b0-image <value>       B0 image'
  echo '  --b0-mask <value>        mask of B0 image'
  echo '  --fixed <vaule>          fixed image to registar to'
  echo '  --fixed-mask <value>     mask of the fixed image'
  echo '  --init-xfm <vaule>       inital rigid registration mat file'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${B0_IMAGE} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${B0_IMAGE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

DIR_SAVE=$(dirname "${B0_IMAGE}")

#===============================================================================
# Start of Function
#===============================================================================
antsRegistration \
  -d 3 -u 0 -z 1 -l 1 -n Linear -v ${VERBOSE} \
  -o ${DIR_SCRATCH}/${PREFIX}_xfm_ \
  -r ${INIT_XFM} \
  -t Rigid[0.25] \
  -m Mattes[${FIXED},${B0_IMAGE},1,32,Regular,0.2] \
  -c [1200x1200x100,1e-6,5] -f 4x2x1 -s 2x1x0vox \
  -x [${FIXED_MASK},${B0_MASK}] \
  -t Affine[0.25] \
  -m Mattes[${FIXED},${B0_IMAGE},1,32,Regular,0.2] \
  -c [200x20,1e-6,5] -f 2x1 -s 1x0vox \
  -x [${FIXED_MASK},${B0_MASK}] \
  -t SyN[0.2,3,0] \
  -m Mattes[${FIXED},${B0_IMAGE},1,32] \
  -c [40x20x0,1e-7,8] -f 4x2x1 -s 2x1x0vox \
  -x [${FIXED_MASK},${B0_MASK}]  

TO=`${DIR_CODE}/bids/get_space_label.sh -i ${FIXED}`
mv ${DIR_SAVE}/${PREFIX}_xfm_0GenericAffine.mat ${DIR_SAVE}/${PREFIX}_from-B0+raw_to-${TO}_xfm-affine.mat
mv ${DIR_SAVE}/${PREFIX}_xfm_1Warp.nii.gz ${DIR_SAVE}/${PREFIX}_from-B0+raw_to-${TO}_xfm-syn.nii.gz
mv ${DIR_SAVE}/${PREFIX}_xfm_1InverseWarp.nii.gz ${DIR_SAVE}/${PREFIX}_from-${TO}_to-B0+raw_xfm-syn.nii.gz

antsApplyTransforms -d 3 \
  -o [${DIR_SAVE}/${PREFIX}_from-B0+raw_to-${TO}_xfm-stack.nii.gz,1] \
  -t ${DIR_SAVE}/${PREFIX}_from-B0+raw_to-${TO}_xfm-syn.nii.gz \
  -t ${DIR_SAVE}/${PREFIX}_from-B0+raw_to-${TO}_xfm-affine.mat \
  -r ${FIXED}
antsApplyTransforms -d 3 \
  -o [${DIR_SAVE}/${PREFIX}_from-${TO}_from-B0+raw_xfm-stack.nii.gz,1] \
  -t [${DIR_SAVE}/${PREFIX}_from-B0+raw_to-${TO}_xfm-affine.mat,1] \
  -t ${DIR_SAVE}/${PREFIX}_from-${TO}_to-B0+raw_xfm-syn.nii.gz \
  -r ${B0_IMAGE}

#===============================================================================
# End of Function
#===============================================================================

# Exit function ---------------------------------------------------------------
exit 0

