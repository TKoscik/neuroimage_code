#!/bin/bash -e

#===============================================================================
# Registration native space to create brain mask
# Authors: Josh Cochran
# Date: 3/30/2020
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hcvkl --long group:,prefix:,template:,space:,\
dir-scratch:,dir-nimgcore:,dir-pincsource:,dir-save:,\
keep,help,verbose,dry-run,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
TEMPLATE=HCPICBM
SPACE=1mm
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
KEEP=false
VERBOSE=0
HELP=false
DRY_RUN=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -c | --dry-run) DRY-RUN=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo 'Author: Josh Cochran'
  echo 'Date:   3/30/2020'
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
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_NIMGCORE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${DIR_SAVE}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${DIR_SAVE} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${DIR_SAVE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}


#==============================================================================
# Brain Mask/T2 registration
#==============================================================================

DIR_XFM=${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
DIR_ANAT_MASK=${DIR_PROJECT}/derivatives/anat/mask
DIR_ANAT_NATIVE=${DIR_PROJECT}/derivatives/anat/native

mkdir -p ${DIR_XFM}

rm ${DIR_SAVE}/*.mat  > /dev/null 2>&1
rm ${DIR_SAVE}/*prep-rigid*  > /dev/null 2>&1

FIXED_IMAGE=${DIR_ANAT_NATIVE}/${PREFIX}_T2w.nii.gz
MOVING_IMAGE=${DIR_SAVE}/All_hifi_b0_mean.nii.gz
antsRegistration \
  -d 3 \
  --float 1 \
  --verbose 1 \
  -u 1 \
  -w [0.01,0.99] \
  -z 1 \
  -r [${FIXED_IMAGE},${MOVING_IMAGE},1] \
  -t Rigid[0.1] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE},1,32,Regular,0.25] \
  -c [1000x500x250x100,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -t Affine[0.1] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE},1,32,Regular,0.25] \
  -c [1000x500x250x100,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -o ${DIR_SCRATCH}/dwi_to_nativeMask_temp_

mv ${DIR_SCRATCH}/dwi_to_nativeMask_temp_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affineMask.mat

antsApplyTransforms -d 3 \
  -i ${DIR_ANAT_MASK}/${PREFIX}_mask-brain.nii.gz \
  -o ${DIR_SCRATCH}/DTI_undilatedMask.nii.gz \
  -t [${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affineMask.mat,1] \
  -r ${DIR_SAVE}/All_hifi_b0_mean.nii.gz

ImageMath 3 ${DIR_SAVE}/DTI_mask.nii.gz MD ${DIR_SCRATCH}/DTI_undilatedMask.nii.gz 5


chgrp -R ${GROUP} ${DIR_SAVE} > /dev/null 2>&1
chmod -R g+rw ${DIR_SAVE} > /dev/null 2>&1

# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}/
  rmdir ${DIR_SCRATCH}
else
  rm ${DIR_SCRATCH}/*  > /dev/null 2>&1
  rmdir ${DIR_SCRATCH}
fi

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi
