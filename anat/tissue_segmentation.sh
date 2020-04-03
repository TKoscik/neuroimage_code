#!/bin/bash -e

#===============================================================================
# K-Means Tissue Segmentation
# Authors: Timothy R. Koscik
# Date: 2020-03-03
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvkl --long group:,prefix:,\
image:,mask:,n-class:,class-label:,\
dimension:,convergence:,likelihood-model:,mrf:,use-random:,posterior-form:,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
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
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
KEEP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE+="$2" ; shift 2 ;;
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
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
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
  echo 'Author: Timothy R. Koscik, PhD'
  echo 'Date: 2020-02-26'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -c | --dry-run           test run of function'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
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
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_NIMGCORE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${INPUT_FILE}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${INPUT_FILE} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${INPUT_FILE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_NIMGCORE}/code/bids/get_bidsbase -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

if [ -z "${CLASS_LABEL}" ]; then
  CLASS_LABEL=(`seq 1 1 ${N_CLASS}`)
fi

# =============================================================================
# Start of Function
# =============================================================================
# Resample images to 1mm isotropic voxels for GMM modeling,
# useful for very large images
ResampleImage 3 ${IMAGE[0]} ${DIR_SCRATCH}/temp.nii.gz 1x1x1 0 0 1
ResampleImage 3 ${MASK} ${DIR_SCRATCH}/mask.nii.gz 1x1x1 0 0 1
gunzip ${DIR_SCRATCH}/*.gz

# fit a Gaussian mixture model to get initial values for k-means
INIT_VALUES=(`Rscript ${DIR_NIMGCORE}/code/anat/histogram_peaks_GMM.R ${DIR_SCRATCH}/temp.nii ${DIR_SCRATCH}/mask.nii ${DIR_SCRATCH} "k" ${N_CLASS}`)

# run Atropos tisue segmentation
NUM_IMAGE=${#IMAGE[@]}
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
# Clean workspace --------------------------------------------------------------
rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

