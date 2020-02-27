#!/bin/bash -e

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvk --long researcher:,project:,group:,subject:,session:,prefix:,ts-bold:,target:,template:,space:,dir-scratch:,dir-nimgcore:,dir-pincsource:,keep,help,verbose -n 'parse-options' -- "$@"`
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
TS_BOLD=
TARGET=T1w
TEMPLATE=
SPACE=
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
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --target) TARGET="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------

#==============================================================================
# Motion Correction + registration
#==============================================================================
# add in logging

mkdir -p ${DIR_SCRATCH}
NUM_TR=`PrintHeader ${TS_BOLD} | grep Dimens | cut -d ',' -f 4 | cut -d ']' -f 1`
TR=`PrintHeader ${TS_BOLD} | grep "Voxel Spac" | cut -d ',' -f 4 | cut -d ']' -f 1`

#------------------------------------------------------------------------------
# Motion correction
#------------------------------------------------------------------------------
# pad image
fslsplit ${TS_BOLD} ${DIR_SCRATCH}/vol -t
for (( i=0; i<${NUM_TR}; i++ )); do
  VOL_NUM=$(printf "%04d" ${i})
  ImageMath 3 ${DIR_SCRATCH}/vol${VOL_NUM}.nii.gz PadImage ${DIR_SCRATCH}/vol${VOL_NUM}.nii.gz 5
done
MERGE_LS=(`ls ${DIR_SCRATCH}/vol*`)
fslmerge -tr ${DIR_SCRATCH}/${PREFIX}_bold+pad.nii.gz ${MERGE_LS[@]} ${TR}
TS_BOLD=${DIR_SCRATCH}/${PREFIX}_bold+pad.nii.gz
rm ${MERGE_LS[@]}

# calculate mean BOLD
antsMotionCorr -d 3 -a ${TS_BOLD} -o ${DIR_SCRATCH}/${PREFIX}_avg.nii.gz

# Rigid registration to mean BOLD, to refine any large motions out of average
antsMotionCorr \
  -d 3 -u 1 -e 1 -n ${NUM_TR} -v ${VERBOSE} \
  -o [${DIR_SCRATCH}/${PREFIX}_rigid_,${DIR_SCRATCH}/${PREFIX}.nii.gz,${DIR_SCRATCH}/${PREFIX}_avg.nii.gz] \
  -t Rigid[0.1] -m MI[${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,${TS_BOLD},1,32,Regular,0.2] \
  -i 20x15x5x1 -s 3x2x1x0 -f 4x3x2x1  

cat ${DIR_SCRATCH}/${PREFIX}_rigid_MOCOparams.csv | tail -n+2 > ${DIR_SCRATCH}/temp.csv
cut -d, -f1-2 --complement ${DIR_SCRATCH}/temp.csv > ${DIR_SCRATCH}/${PREFIX}_moco+6.1D
rm ${DIR_SCRATCH}/temp.csv
rm ${DIR_SCRATCH}/${PREFIX}_rigid_MOCOparams.csv

# Affine registration to mean BOLD
antsMotionCorr \
  -d 3 -u 1 -e 1 -n ${NUM_TR} -l 1 -v ${VERBOSE} \
  -o [${DIR_SCRATCH}/${PREFIX}_affine_,${DIR_SCRATCH}/${PREFIX}.nii.gz,${DIR_SCRATCH}/${PREFIX}_avg.nii.gz] \
  -t Affine[0.1] -m MI[${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,${TS_BOLD},1,32,Regular,0.2] \
  -i 20x15x5x1 -s 3x2x1x0 -f 4x3x2x1

cat ${DIR_SCRATCH}/${PREFIX}_affine_MOCOparams.csv | tail -n+2 > ${DIR_SCRATCH}/temp.csv
cut -d, -f1-2 --complement ${DIR_SCRATCH}/temp.csv > ${DIR_SCRATCH}/${PREFIX}_moco+12.1D
rm ${DIR_SCRATCH}/temp.csv
rm ${DIR_SCRATCH}/${PREFIX}_affine_MOCOparams.csv

#------------------------------------------------------------------------------
# get brain mask of mean BOLD
#------------------------------------------------------------------------------
bet ${DIR_SCRATCH}/${PREFIX}_avg.nii.gz ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz -m -n
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain_mask.nii.gz ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz

#------------------------------------------------------------------------------
# Registration to subject space
#------------------------------------------------------------------------------
T1=(`ls ${RESEARCHER}/${PROJECT}/derivatives/anat/native/sub-${SUBJECT}_ses-${SESSION}*${TARGET}.nii.gz`)
T1_MASK=(`ls ${RESEARCHER}/${PROJECT}/derivatives/anat/mask/sub-${SUBJECT}_ses-${SESSION}*mask-brain.nii.gz`)
# use raw to rigid transform to initialize
RAW_TO_RIGID=(`ls ${RESEARCHER}/${PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}/sub-${SUBJECT}_ses-${SESSION}*${TARGET}+raw*.mat`)

antsRegistration \
  -d 3 -u 0 -z 1 -l 1 -n Linear -v ${VERBOSE} \
  -o ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_ \
  -r ${RAW_TO_RIGID} \
  -t Rigid[0.25] \
  -m Mattes[${T1},${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,1,32,Regular,0.2] \
  -c [1200x1200x100,1e-6,5] -f 4x2x1 -s 2x1x0vox \
  -x [${T1_MASK},${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz] \
  -t Affine[0.25] \
  -m Mattes[${T1},${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,1,32,Regular,0.2] \
  -c [200x20,1e-6,5] -f 2x1 -s 1x0vox \
  -x [${T1_MASK},${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz] \
  -t SyN[0.2,3,0] \
  -m Mattes[${T1},${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,1,32] \
  -c [40x20x0,1e-7,8] -f 4x2x1 -s 2x1x0vox \
  -x [${T1_MASK},${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz]
  
# collapse transforms to deformation field
antsApplyTransforms -d 3 \
  -o [${DIR_SCRATCH}/${PREFIX}_xfm_toNative_stack.nii.gz,1] \
  -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_1Warp.nii.gz \
  -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_0GenericAffine.mat \
  -r ${T1}

#------------------------------------------------------------------------------
# Push mean bold to template
#------------------------------------------------------------------------------
XFM_NORM=(`ls ${RESEARCHER}/${PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}/*${TARGET}+rigid_to-${TEMPLATE}+*_xfm-stack.nii.gz`)
antsApplyTransforms -d 3 \
  -o ${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz \
  -i ${DIR_SCRATCH}/${PREFIX}_avg.nii.gz \
  -t ${XFM_NORM} \
  -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_stack.nii.gz \
  -r ${DIR_NIMGCORE}/templates_human/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz
# apply to brain mask as well
antsApplyTransforms -d 3 -n NearestNeighbor\
  -o ${DIR_SCRATCH}/${PREFIX}_mask-brain+warp.nii.gz \
  -i ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz \
  -t ${XFM_NORM} \
  -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_stack.nii.gz \
  -r ${DIR_NIMGCORE}/templates_human/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz

#------------------------------------------------------------------------------
# redo motion correction to normalized mean bold
#------------------------------------------------------------------------------
antsMotionCorr \
  -d 3 -u 1 -e 1 -n ${NUM_TR} -l 1 -v ${VERBOSE} \
  -o [${DIR_SCRATCH}/${PREFIX}_moco+warp_,${DIR_SCRATCH}/${PREFIX}_moco+warp.nii.gz,${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz] \
  -t Rigid[0.25] -m MI[${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz,${TS_BOLD},1,32,Regular,0.2] \
  -i 20x15x5x1 -s 3x2x1x0 -f 4x3x2x1 \
  -t Affine[0.25] -m MI[${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz,${TS_BOLD},1,32,Regular,0.2] \
  -i 20x15x5x1 -s 3x2x1x0 -f 4x3x2x1 \
  -t SyN[0.2,3,0] -m MI[${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz,${TS_BOLD},1,32,Regular,0.2] \
  -i 20x15x5x1 -s 3x2x1x0 -f 4x3x2x1

#------------------------------------------------------------------------------
# Depad images
#------------------------------------------------------------------------------
fslsplit ${DIR_SCRATCH}/${PREFIX}_moco+warp.nii.gz ${DIR_SCRATCH}/vol -t
for (( i=0; i<${NUM_TR}; i++ )); do
  VOL_NUM=$(printf "%04d" ${i})
  ImageMath 3 ${DIR_SCRATCH}/vol${VOL_NUM}.nii.gz PadImage ${DIR_SCRATCH}/vol${VOL_NUM}.nii.gz -5
done
MERGE_LS=(`ls ${DIR_SCRATCH}/vol*`)
fslmerge -tr ${DIR_SCRATCH}/${PREFIX}_bold.nii.gz ${MERGE_LS[@]} ${TR}
rm ${MERGE_LS[@]}

#------------------------------------------------------------------------------
# Move files to appropriate locations
#------------------------------------------------------------------------------
DIR_REGRESSOR=${RESEARCHER}/${PROJECT}/derivatives/func/regressors/sub-${SUBJECT}/ses-${SESSION}
mkdir -p ${DIR_REGRESSOR}
mv ${DIR_SCRATCH}/${PREFIX}_moco+6.1D ${DIR_REGRESSOR}/
mv ${DIR_SCRATCH}/${PREFIX}_moco+12.1D ${DIR_REGRESSOR}/

mkdir -p ${RESEARCHER}/${PROJECT}/derivatives/func/mask
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz \
  ${RESEARCHER}/${PROJECT}/derivatives/func/mask/${PREFIX}_acq-bold_mask-brain.nii.gz
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain+warp.nii.gz \
  ${RESEARCHER}/${PROJECT}/derivatives/func/mask/${PREFIX}_reg-${TEMPLATE}+${SPACE}_acq-bold_mask-brain.nii.gz

mkdir -p ${RESEARCHER}/${PROJECT}/derivatives/func/moco_${TEMPLATE}_${SPACE}
mv ${DIR_SCRATCH}/${PREFIX}_moco+warp.nii.gz \
  ${RESEARCHER}/${PROJECT}/derivatives/func/moco_${TEMPLATE}_${SPACE}/${PREFIX}_bold.nii.gz
  
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${RESEARCHER}/${PROJECT}/derivatives/func/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${RESEARCHER}/${PROJECT}/derivatives/func/prep/sub-${SUBJECT}/ses-${SESSION}/
fi

# clean up scratch
rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

