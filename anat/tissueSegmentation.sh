#!/bin/bash -e
#===============================================================================
# K-Means Tissue Segmentation
# Authors: Timothy R. Koscik
# Date: 2020-03-03
# NOTES:
# -implement SAMSEG tissue segmentation option
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(unname -s)"
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
    ${DIR_INC}/log/logBenchmark.sh \
      -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
      -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
    ${DIR_INC}/log/logProject.sh \
      -d ${DIR_PROJECT} -p ${PID} -n ${SID} \
      -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
      -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
    ${DIR_INC}/log/logSession.sh \
      -d ${DIR_PROJECT} -p ${PID} -n ${SID} \
      -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
      -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvkl --long prefix:,\
image:,mask:,n-class:,class-label:,\
dimension:,convergence:,likelihood-model:,mrf:,use-random:,posterior-form:,\
dir-save:,dir-scratch:\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
MASK=
N_CLASS=
CLASS_LABEL=
DIM=3
CONVERGENCE=[5,0.001]
LIKELIHOOD_MODEL=Gaussian
MRF=[0.1,1x1x1]
USE_RANDOM=1
POSTERIOR_FORM=Socrates[0]
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=0
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --n-class) N_CLASS="$2" ; shift 2 ;;
    --class-label) CLASS_LABEL="$2" ; shift 2 ;;
    --dimension) DIM="$2" ; shift 2 ;;
    --convergence) CONVERGENCE="$2" ; shift 2 ;;
    --likelihood-model) LIKELIHOOD_MODEL="$2" ; shift 2 ;;
    --mrf) MRF="$2" ; shift 2 ;;
    --use-random) USE_RANDOM="$2" ; shift 2 ;;
    --posterior-form) POSTERIOR_FORM="$2" ; shift 2 ;;
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
  echo '  --image <value>          image(s) to use for segmentation, multiple'
  echo '                           inputs allowed. T1w first, T2w second, etc.'
  echo '  --mask <value>           binary mask of region to include in'
  echo '                           segmentation'
  echo '  --n-class <value>        number of segmentation classes, default=3'
  echo '  --class-label <values>   array of names for classes, default is'
  echo '                           numeric'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default" ${RESEARCHER}/${PROJECT}/derivatives/inc/anat/label'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_INC}'
  echo ''
  NO_LOG=true
  exit 0
fi

# =============================================================================
# Start of Function
# =============================================================================
IMAGE=(${IMAGE//,/ })
NUM_IMAGE=${#IMAGE[@]}

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${IMAGE[0]})
PID=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE} -f ses)
if [[ -z "${PREFIX}" ]]; then
  PREFIX=`${DIR_INC}/bids/get_bidsbase.sh -s -i ${IMAGE[0]})
fi

if [[ -z "${DIR_SAVE}" ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/sub-${PID}
  if [[ -n "${SID}" ]]; then
    DIR_SAVE=${DIR_SAVE}/ses-${SID}
  fi
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

if [[ -z "${CLASS_LABEL}" ]]; then
  CLASS_LABEL=($(seq 1 1 ${N_CLASS}))
fi

# Resample images to 1mm isotropic voxels for GMM modeling,
# useful for very large images
ResampleImage 3 ${IMAGE[0]} ${DIR_SCRATCH}/temp.nii.gz 1x1x1 0 0 1
ResampleImage 3 ${MASK} ${DIR_SCRATCH}/mask.nii.gz 1x1x1 0 0 1
gunzip ${DIR_SCRATCH}/*.gz

# fit a Gaussian mixture model to get initial values for k-means
INIT_VALUES=($(Rscript ${DIR_INC}/anat/histogramPeaksGMM.R \
  ${DIR_SCRATCH}/temp.nii \
  ${DIR_SCRATCH}/mask.nii \
  ${DIR_SCRATCH} \
  "k" ${N_CLASS}))

# run Atropos tisue segmentation
atropos_fcn="Atropos -d ${DIM}"
atropos_fcn="${atropos_fcn} -c ${CONVERGENCE}"
atropos_fcn="${atropos_fcn} -k ${LIKELIHOOD_MODEL}"
atropos_fcn="${atropos_fcn} -m ${MRF}"
atropos_fcn="${atropos_fcn} -r ${USE_RANDOM}"
atropos_fcn="${atropos_fcn} -p ${POSTERIOR_FORM}"
atropos_fcn="${atropos_fcn} -v ${VERBOSE}"
for (( i=0; i<${NUM_IMAGE}; i++ )); do
 atropos_fcn="${atropos_fcn} -a ${IMAGE[${i}]}"
done
if [ -n "${MASK}" ]; then
  atropos_fcn="${atropos_fcn} -x ${MASK}"
fi
atropos_fcn="${atropos_fcn} -i kmeans[${N_CLASS},${INIT_VALUES}]"
atropos_fcn="${atropos_fcn} -o [${DIR_SCRATCH}/${PREFIX}_label-atropos+${N_CLASS}.nii.gz,${DIR_SCRATCH}/posterior%d.nii.gz]"
eval ${atropos_fcn}

mv ${DIR_SCRATCH}/${PREFIX}_label-atropos+${N_CLASS}.nii.gz ${DIR_SAVE}/
for (( i=0; i<${N_CLASS}; i++)); do
  POST_NUM=$((${i}+1))
  mv ${DIR_SCRATCH}/posterior${POST_NUM}.nii.gz ${DIR_SAVE}/${PREFIX}_posterior-${CLASS_LABEL[${i}]}
done

#===============================================================================
# End of Function
#===============================================================================
exit 0
