#!/bin/bash

OPTS=`getopt -hvk --long researcher:,project:,group:,subject:,session:,prefix:,dir-scratch:,dir-nimgcore:,dir-pincsource:,keep,help,verbose -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
RESEARCHER=
PROJECT=
GROUP=
SUBJECT=
SESSION=
PREFIX=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
KEEP=false
VERBOSE=0
HELP=false

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
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------


#==============================================================================
# Brain Mask/T2 registration
#==============================================================================

mkdir -p ${DIR_SCRATCH}

DIR_PREP=${RESEARCHER}/${PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
DIR_XFM=${RESEARCHER}/${PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
DIR_ANAT_MASK=${RESEARCHER}/${PROJECT}/derivatives/anat/mask
DIR_ANAT_NATIVE=${RESEARCHER}/${PROJECT}/derivatives/anat/native

rm ${DIR_PREP}/*.mat
rm ${DIR_PREP}/*prep-rigid*

FIXED_IMAGE=${DIR_ANAT_NATIVE}/${PREFIX}_T2w.nii.gz
MOVING_IMAGE=${DIR_PREP}/All_hifi_b0_mean.nii.gz
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
  -r ${DIR_PREP}/All_hifi_b0_mean.nii.gz

ImageMath 3 ${DIR_PREP}/DTI_mask.nii.gz MD ${DIR_SCRATCH}/DTI_undilatedMask.nii.gz 5


rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}


chgrp -R ${GROUP} ${DIR_PREP} > /dev/null 2>&1
chmod -R g+rw ${DIR_PREP} > /dev/null 2>&1
