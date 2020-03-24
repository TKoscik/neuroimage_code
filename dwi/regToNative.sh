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
# Topup
#==============================================================================

mkdir -p ${DIR_SCRATCH}

DIR_PREP=${RESEARCHER}/${PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
DIR_TENSOR=${RESEARCHER}/${PROJECT}/derivatives/dwi/tensor/sub-${SUBJECT}/ses-${SESSION}
DIR_XFM=${RESEARCHER}/${PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
DIR_ANAT_NATIVE=${RESEARCHER}/${PROJECT}/derivatives/anat/native
DIR_NATIVE_SCALARS=${RESEARCHER}/${PROJECT}/derivatives/dwi/scalars_native

rm ${DIR_PREP}/*.mat ${DIR_PREP}/dwi_to_native_temp_1Warp.nii.gz ${DIR_PREP}/dwi_to_native_temp_1InverseWarp.nii.gz
rm ${DIR_XFM}/${PREFIX}_from-T2w+rigid_to-dwi+b0_xfm-syn.nii.gz ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat

antsApplyTransforms -d 3 \
  -i ${DIR_PREP}/DTI_mask.nii.gz \
  -o ${DIR_PREP}/${PREFIX}_mask-brain_native.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affineMask.mat \
  -r ${DIR_ANAT_NATIVE}/${PREFIX}_T2w.nii.gz

FIXED_IMAGE=${DIR_ANAT_NATIVE}/${PREFIX}_T2w.nii.gz
MOVING_IMAGE1=${DIR_TENSOR}/All_Scalar_FA.nii.gz
MOVING_IMAGE2=${DIR_TENSOR}/All_Scalar_MD.nii.gz
MOVING_IMAGE3=${DIR_TENSOR}/All_Scalar_S0.nii.gz

# Inital registration added to get closer for final registration
antsRegistration \
  -d 3 \
  -x [${DIR_PREP}/${PREFIX}_mask-brain_native.nii.gz,${DIR_PREP}/DTI_undilatedMask.nii.gz] \
  --float 1 \
  --verbose 1 \
  -u 1 \
  -w [0.01,0.99] \
  -z 1 \
  -r [${FIXED_IMAGE},${MOVING_IMAGE1},0] \
  -t Rigid[0.1] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE1},1,32,Regular,0.25] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE2},1,32,Regular,0.25] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE3},1,32,Regular,0.25] \
  -c [1000x500x250x100,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -o ${DIR_PREP}/dwi_to_native_temp_

antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_FA.nii.gz \
  -o ${DIR_TENSOR}/All_Scalar_FA.nii.gz \
  -t ${DIR_PREP}/dwi_to_native_temp_0GenericAffine.mat \
  -r ${FIXED_IMAGE}

antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_MD.nii.gz \
  -o ${DIR_TENSOR}/All_Scalar_MD.nii.gz \
  -t ${DIR_PREP}/dwi_to_native_temp_0GenericAffine.mat \
  -r ${FIXED_IMAGE}

antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_S0.nii.gz \
  -o ${DIR_TENSOR}/All_Scalar_S0.nii.gz \
  -t ${DIR_PREP}/dwi_to_native_temp_0GenericAffine.mat \
  -r ${FIXED_IMAGE}
#reset variables to newly moved images
MOVING_IMAGE1=${DIR_TENSOR}/All_Scalar_FA.nii.gz
MOVING_IMAGE2=${DIR_TENSOR}/All_Scalar_MD.nii.gz
MOVING_IMAGE3=${DIR_TENSOR}/All_Scalar_S0.nii.gz


antsRegistration \
  -d 3 \
  -x [${DIR_PREP}/${PREFIX}_mask-brain_native.nii.gz,${DIR_PREP}/DTI_undilatedMask.nii.gz] \
  --float 1 \
  --verbose 1 \
  -u 1 \
  -w [0.01,0.99] \
  -z 1 \
  -r [${FIXED_IMAGE},${MOVING_IMAGE1},1] \
  -t Rigid[0.1] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE1},1,32,Regular,0.25] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE2},1,32,Regular,0.25] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE3},1,32,Regular,0.25] \
  -c [1000x500x250x100,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -t Affine[0.1] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE1},1,32,Regular,0.25] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE2},1,32,Regular,0.25] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE3},1,32,Regular,0.25] \
  -c [1000x500x250x100,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -t SyN[0.1,3,0] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE1},1,32,Regular,0.25] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE2},1,32,Regular,0.25] \
  -m Mattes[${FIXED_IMAGE},${MOVING_IMAGE3},1,32,Regular,0.25] \
  -c [100x70x50x20,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -o ${DIR_PREP}/dwi_to_native_temp_

mv ${DIR_PREP}/dwi_to_native_temp_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat
mv ${DIR_PREP}/dwi_to_native_temp_1Warp.nii.gz \
  ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz
mv ${DIR_PREP}/dwi_to_native_temp_1InverseWarp.nii.gz \
  ${DIR_XFM}/${PREFIX}_from-T2w+rigid_to-dwi+b0_xfm-syn.nii.gz

FIXED_IMAGE=${DIR_ANAT_NATIVE}/${PREFIX}_T2w_brain.nii.gz
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_FA.nii.gz \
  -o ${DIR_NATIVE_SCALARS}/FA/${PREFIX}_reg-T2w+rigid_FA.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat \
  -r ${FIXED_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_MD.nii.gz \
  -o ${DIR_NATIVE_SCALARS}/MD/${PREFIX}_reg-T2w+rigid_MD.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat \
  -r ${FIXED_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_L1.nii.gz \
  -o ${DIR_NATIVE_SCALARS}/AD/${PREFIX}_reg-T2w+rigid_AD.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat \
  -r ${FIXED_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_S0.nii.gz \
  -o ${DIR_NATIVE_SCALARS}/S0/${PREFIX}_reg-T2w+rigid_S0.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat \
  -r ${FIXED_IMAGE}

fslmaths ${DIR_TENSOR}/All_Scalar_L2.nii.gz -add ${DIR_TENSOR}/All_Scalar_L3.nii.gz -div 2 ${DIR_TENSOR}/All_Scalar_RD.nii.gz

antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_RD.nii.gz \
  -o ${DIR_NATIVE_SCALARS}/RD/${PREFIX}_reg-T2w+rigid_RD.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat \
  -r ${FIXED_IMAGE}


rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

chgrp -R ${GROUP} ${DIR_PREP} > /dev/null 2>&1
chmod -R g+rw ${DIR_PREP} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_TENSOR} > /dev/null 2>&1
chmod -R g+rw ${DIR_TENSOR} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_XFM} > /dev/null 2>&1
chmod -R g+rw ${DIR_XFM} > /dev/null 2>&1
