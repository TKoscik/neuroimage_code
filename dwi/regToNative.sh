#!/bin/bash -e

#===============================================================================
# Register DWI to native spacing
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

# actions on exit, e.g., cleaning scratch on error ----------------------------
function egress {
  if [[ -d ${DIR_SCRATCH} ]]; then
    if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
      rm -R ${DIR_SCRATCH}/*
    fi
    rmdir ${DIR_SCRATCH}
  fi
}
trap egress EXIT

# Set default values for function ---------------------------------------------
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
  echo '  --dir-raw <value>        location of the raw DWI data'
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
# Register DWI to Native space
#==============================================================================

DIR_TENSOR=${DIR_PROJECT}/derivatives/dwi/tensor/sub-${SUBJECT}/ses-${SESSION}
DIR_XFM=${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
DIR_ANAT_NATIVE=${DIR_PROJECT}/derivatives/anat/native
DIR_NATIVE_SCALARS=${DIR_PROJECT}/derivatives/dwi/scalars_native

mkdir -p ${DIR_NATIVE_SCALARS}/RD
mkdir -p ${DIR_NATIVE_SCALARS}/S0
mkdir -p ${DIR_NATIVE_SCALARS}/FA
mkdir -p ${DIR_NATIVE_SCALARS}/MD
mkdir -p ${DIR_NATIVE_SCALARS}/AD

rm ${DIR_SAVE}/*.mat ${DIR_SAVE}/dwi_to_native_temp_1Warp.nii.gz ${DIR_SAVE}/dwi_to_native_temp_1InverseWarp.nii.gz  > /dev/null 2>&1
rm ${DIR_XFM}/${PREFIX}_from-T2w+rigid_to-dwi+b0_xfm-syn.nii.gz ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat  > /dev/null 2>&1

antsApplyTransforms -d 3 \
  -i ${DIR_SAVE}/DTI_mask.nii.gz \
  -o ${DIR_SAVE}/${PREFIX}_mask-brain_native.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affineMask.mat \
  -r ${DIR_ANAT_NATIVE}/${PREFIX}_T2w.nii.gz

FIXED_IMAGE=${DIR_ANAT_NATIVE}/${PREFIX}_T2w.nii.gz
MOVING_IMAGE1=${DIR_TENSOR}/All_Scalar_FA.nii.gz
MOVING_IMAGE2=${DIR_TENSOR}/All_Scalar_MD.nii.gz
MOVING_IMAGE3=${DIR_TENSOR}/All_Scalar_S0.nii.gz

# Inital registration added to get closer for final registration
antsRegistration \
  -d 3 \
  -x [${DIR_SAVE}/${PREFIX}_mask-brain_native.nii.gz,${DIR_SAVE}/DTI_undilatedMask.nii.gz] \
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
  -o ${DIR_SCRATCH}/dwi_to_native_temp_

antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_FA.nii.gz \
  -o ${DIR_TENSOR}/All_Scalar_FA.nii.gz \
  -t ${DIR_SCRATCH}/dwi_to_native_temp_0GenericAffine.mat \
  -r ${FIXED_IMAGE}

antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_MD.nii.gz \
  -o ${DIR_TENSOR}/All_Scalar_MD.nii.gz \
  -t ${DIR_SCRATCH}/dwi_to_native_temp_0GenericAffine.mat \
  -r ${FIXED_IMAGE}

antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_S0.nii.gz \
  -o ${DIR_TENSOR}/All_Scalar_S0.nii.gz \
  -t ${DIR_SCRATCH}/dwi_to_native_temp_0GenericAffine.mat \
  -r ${FIXED_IMAGE}
#reset variables to newly moved images
MOVING_IMAGE1=${DIR_TENSOR}/All_Scalar_FA.nii.gz
MOVING_IMAGE2=${DIR_TENSOR}/All_Scalar_MD.nii.gz
MOVING_IMAGE3=${DIR_TENSOR}/All_Scalar_S0.nii.gz


antsRegistration \
  -d 3 \
  -x [${DIR_SAVE}/${PREFIX}_mask-brain_native.nii.gz,${DIR_SAVE}/DTI_undilatedMask.nii.gz] \
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
  -o ${DIR_SCRATCH}/dwi_to_native_temp_

mv ${DIR_SCRATCH}/dwi_to_native_temp_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat
mv ${DIR_SCRATCH}/dwi_to_native_temp_1Warp.nii.gz \
  ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz
mv ${DIR_SCRATCH}/dwi_to_native_temp_1InverseWarp.nii.gz \
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

#==============================================================================
# End of function
#==============================================================================

chgrp -R ${GROUP} ${DIR_SAVE} > /dev/null 2>&1
chmod -R g+rw ${DIR_SAVE} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_TENSOR} > /dev/null 2>&1
chmod -R g+rw ${DIR_TENSOR} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_XFM} > /dev/null 2>&1
chmod -R g+rw ${DIR_XFM} > /dev/null 2>&1

# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}/
fi

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

exit 0

