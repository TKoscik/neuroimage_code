#!/bin/bash -e

#===============================================================================
# Rician Denoising
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-23
# Software: ANTs
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvk --long researcher:,project:,group:,subject:,session:,prefix:,\
image:,mask:,dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose,keep -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S)
RESEARCHER=
PROJECT=
GROUP=
SUBJECT=
SESSION=
PREFIX=
IMAGE=
MASK=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix)  PREFIX="$2" ; shift 2 ;;
    --image) IMAGE+="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
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
  echo 'Author: Timothy R. Koscik, Phd'
  echo 'Date:   2020-02-25'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  --researcher <value>     directory containing the project,'
  echo '                           e.g. /Shared/koscikt'
  echo '  --project <value>        name of the project folder, e.g., iowa_black'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --subject <value>        subject identifer, e.g., 123'
  echo '  --session <value>        session identifier, e.g., 1234abcd'
  echo '  --prefix <value>         prefix for output,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --image <value>          full path to image to denoise'
  echo '  --mask <value>           full path to binary mask'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo "                           default: ${DIR_NIMGCORE}"
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo "                           default: ${DIR_PINCSOURCE}"
  echo ''
  exit 0
fi

# Get time stamp for log -------------------------------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

# Setup directories ------------------------------------------------------------
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${RESEARCHER}/${PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir-p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# set output prefix if not provided --------------------------------------------
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

#===============================================================================
# Rician Denoising
#===============================================================================
NUM_IMAGE=${#IMAGE[@]}
for (( i=0; i<${NUM_IMAGE}; i++ )); do
  #find dimensionality of image (3d or 4d)
  NUM_VOLS=`PrintHeader ${IMAGE[${i}]} | grep Dimens | cut -d ',' -f 4 | cut -d ']' -f 1`
  if [[ "${NUM_VOLS}" == 1 ]]; then
    IMAGE_DIM=3
  else
    IMAGE_DIM=4
  fi
  
  # gather names for output
  MOD=(${IMAGE[${i}]})
  MOD=(`basename "${MOD%.nii.gz}"`)
  MOD=(${MOD##*_})

  # Denoise image
  dn_fcn="DenoiseImage -d ${IMAGE_DIM} -s 1 -p 1 -r 2 -v ${VERBOSE} -n Rician"
  dn_fcn="${dn_fcn} -i ${IMAGE[${i}]}"
  if [ -z "${MASK}" ]; then
    dn_fcn="${dn_fcn} -i ${MASK}"
  fi
  dn_fcn="${dn_fcn} -o [${DIR_SCRATCH}/${PREFIX}_prep-denoise_${MOD}.nii.gz,${DIR_SCRATCH}/${PREFIX}_prep-noise_${MOD}.nii.gz]"
done

mv ${DIR_SCRATCH}/${OUT_PREFIX}_prep-denoise* ${DIR_SAVE}/

# Clean workspace --------------------------------------------------------------
if [[ "${KEEP}" == "true" ]]; then
  mv ${DIR_SCRATCH}/${OUT_PREFIX}_prep-noise* ${DIR_SAVE}/
else
  rm ${DIR_SCRATCH}/*
fi
rmdir ${DIR_SCRATCH}

#===============================================================================
# End of Function
#===============================================================================

# Write log entry on conclusion ------------------------------------------------
LOG_FILE=${RESEARCHER}/${PROJECT}/log/sub-${SUBJECT}_ses-${SESSION}.log
date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}

