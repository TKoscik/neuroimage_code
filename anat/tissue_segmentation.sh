#!/bin/bash -e

#===============================================================================
# K-Means Tissue Segmentation
# Authors: Timothy R. Koscik
# Date: 2020-03-03
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
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
OPTS=`getopt -o hvkl --long group:,prefix:,\
image:,mask:,n-class:,class-label:,\
dimension:,convergence:,likelihood-model:,mrf:,use-random:,posterior-form:,\
dir-save:,dir-scratch:,dir-code:,dir-template:,\
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
N_CLASS=
CLASS_LABEL=
DIM=3
CONVERGENCE=[5,0.001]
LIKELIHOOD_MODEL=Gaussian
MRF=[0.1,1x1x1]
USE_RANDOM=1
POSTERIOR_FORM=Socrates[0]
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
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
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
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
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
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
  echo '                           default" ${RESEARCHER}/${PROJECT}/derivatives/anat/label'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
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
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${IMAGE[0]}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${IMAGE[0]} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${IMAGE[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${IMAGE[0]}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

if [ -z "${CLASS_LABEL}" ]; then
  CLASS_LABEL=(`seq 1 1 ${N_CLASS}`)
fi

# Resample images to 1mm isotropic voxels for GMM modeling,
# useful for very large images
ResampleImage 3 ${IMAGE[0]} ${DIR_SCRATCH}/temp.nii.gz 1x1x1 0 0 1
ResampleImage 3 ${MASK} ${DIR_SCRATCH}/mask.nii.gz 1x1x1 0 0 1
gunzip ${DIR_SCRATCH}/*.gz

# fit a Gaussian mixture model to get initial values for k-means
INIT_VALUES=(`Rscript ${DIR_CODE}/anat/histogram_peaks_GMM.R ${DIR_SCRATCH}/temp.nii ${DIR_SCRATCH}/mask.nii ${DIR_SCRATCH} "k" ${N_CLASS}`)

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

