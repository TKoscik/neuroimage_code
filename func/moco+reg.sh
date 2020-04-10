#!/bin/bash -e

#===============================================================================
# Functional Timeseries - Motion Correction and Registration
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-27
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvkl --long group:,prefix:,\
ts-bold:,target:,template:,space:,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
keep,help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
TS_BOLD=
TARGET=T1w
TEMPLATE=
SPACE=
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
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --target) TARGET="$2" ; shift 2 ;;
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

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo 'Author: <<author names>>'
  echo 'Date:   <<date of authorship>>'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --target <value>         target modality to work with, default=T1w'
  echo '  --template <value>       name of template to use, e.g., HCPICBM'
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

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${TS_BOLD}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "ses"`
TASK=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "task"`
RUN=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "run"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_NIMGCORE}/code/bids/get_bidsbase -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/func
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#==============================================================================
# Motion Correction + registration
#==============================================================================

# Get timeseries info ---------------------------------------------------------
NUM_TR=`PrintHeader ${TS_BOLD} | grep Dimens | cut -d ',' -f 4 | cut -d ']' -f 1`
TR=`PrintHeader ${TS_BOLD} | grep "Voxel Spac" | cut -d ',' -f 4 | cut -d ']' -f 1`

# Motion correction -----------------------------------------------------------
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

# get brain mask of mean BOLD -------------------------------------------------
bet ${DIR_SCRATCH}/${PREFIX}_avg.nii.gz ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz -m -n
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain_mask.nii.gz ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz

# Registration to subject space -----------------------------------------------
T1=(`ls ${DIR_PROJECT}/derivatives/anat/native/sub-${SUBJECT}_ses-${SESSION}*${TARGET}.nii.gz`)
T1_MASK=(`ls ${DIR_PROJECT}/derivatives/anat/mask/sub-${SUBJECT}_ses-${SESSION}*mask-brain.nii.gz`)
# use raw to rigid transform to initialize, if it exists
RAW_TO_RIGID=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}/sub-${SUBJECT}_ses-${SESSION}*${TARGET}+raw*.mat`)
if [[ -f ${RAW_TO_RIGID} ]]; then
  INIT_XFM=${RAW_TO_RIGID}
else
  INIT_XFM=[${T1},${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,1]
fi

antsRegistration \
  -d 3 -u 0 -z 1 -l 1 -n Linear -v ${VERBOSE} \
  -o ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_ \
  -r ${INIT_XFM} \
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

# Push mean bold to template --------------------------------------------------
XFM_NORM=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}/*${TARGET}+rigid_to-${TEMPLATE}+*_xfm-stack.nii.gz`)
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

# redo motion correction to normalized mean bold ------------------------------
antsMotionCorr \
  -d 3 -u 1 -e 1 -n ${NUM_TR} -l 1 -v ${VERBOSE} \
  -o [${DIR_SCRATCH}/${PREFIX}_moco+warp_,${DIR_SCRATCH}/${PREFIX}_moco+warp.nii.gz,${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz] \
  -t Rigid[0.25] -m MI[${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz,${TS_BOLD},1,32,Regular,0.2] \
  -i 20x15x5x1 -s 3x2x1x0 -f 4x3x2x1 \
  -t Affine[0.25] -m MI[${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz,${TS_BOLD},1,32,Regular,0.2] \
  -i 20x15x5x1 -s 3x2x1x0 -f 4x3x2x1 \
  -t SyN[0.2,3,0] -m MI[${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz,${TS_BOLD},1,32,Regular,0.2] \
  -i 20x15x5x1 -s 3x2x1x0 -f 4x3x2x1

# Depad images ----------------------------------------------------------------
fslsplit ${DIR_SCRATCH}/${PREFIX}_moco+warp.nii.gz ${DIR_SCRATCH}/vol -t
for (( i=0; i<${NUM_TR}; i++ )); do
  VOL_NUM=$(printf "%04d" ${i})
  ImageMath 3 ${DIR_SCRATCH}/vol${VOL_NUM}.nii.gz PadImage ${DIR_SCRATCH}/vol${VOL_NUM}.nii.gz -5
done
MERGE_LS=(`ls ${DIR_SCRATCH}/vol*`)
fslmerge -tr ${DIR_SCRATCH}/${PREFIX}_bold.nii.gz ${MERGE_LS[@]} ${TR}
rm ${MERGE_LS[@]}

# Move files to appropriate locations -----------------------------------------
DIR_REGRESSOR=${DIR_PROJECT}/derivatives/func/regressors/sub-${SUBJECT}/ses-${SESSION}
mkdir -p ${DIR_REGRESSOR}
mv ${DIR_SCRATCH}/${PREFIX}_moco+6.1D ${DIR_REGRESSOR}/
mv ${DIR_SCRATCH}/${PREFIX}_moco+12.1D ${DIR_REGRESSOR}/

mkdir -p ${DIR_PROJECT}/derivatives/func/mask
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz \
  ${DIR_PROJECT}/derivatives/func/mask/${PREFIX}_acq-bold_mask-brain.nii.gz
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain+warp.nii.gz \
  ${DIR_ROJECT}/derivatives/func/mask/${PREFIX}_reg-${TEMPLATE}+${SPACE}_acq-bold_mask-brain.nii.gz

mkdir -p ${DIR_PROJECT}/derivatives/func/moco_${TEMPLATE}+${SPACE}
mv ${DIR_SCRATCH}/${PREFIX}_moco+warp.nii.gz \
  ${DIR_PROJECT}/derivatives/func/moco_${TEMPLATE}+${SPACE}/${PREFIX}_bold.nii.gz
  
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/func/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/func/prep/sub-${SUBJECT}/ses-${SESSION}/
fi

# clean up scratch
rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi
