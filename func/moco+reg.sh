#!/bin/bash -x

PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false

#===============================================================================
# Functional Timeseries - Motion Correction and Registration
#-------------------------------------------------------------------------------
# This function performs BOLD timeseries motion correction and normalization to
# an anatomical template in a single-interpolation. All registrations and motion
# corrections are completed using ANTs. The processing steps in the procedure
# are as follows:
# 1) volumes in the BOLD timeseries (TS) are padded by 5 voxels on each side
# 2) calculate mean BOLD TS, for an initial target for motion correction
# 3) rigid-body (6 DF) motion correction, remake mean BOLD TS
# 4) affine (12 DF) motion correction, remake mean BOLD TS
# 5) generate brain mask using FSL's bet on mean BOLD TS
# 6) register mean BOLD to participant's anatomical image (usually T1w), using
#    rigid, affine, syn registrations. Collapse affine transformations and
#    deformation matrix into a single deformation field.
# 7) push mean BOLD TS and brain mask to template space using the registration
#    to participant's anatomical and a transformation from their anatomical to
#    template space that was generated during anatomical preprocessing
#    (e.g., participant T1w -> template T1w)
# 8) Redo motion correction from raw BOLD TS to the normalized mean BOLD TS,
#    using rigid, affine, and SyN components
# 9) Depad motion-corrected, normalized BOLD TS
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-27
# ------------------------------------------------------------------------------
# UPDATED BY L. HOPKINS 2020-07-02
# 10) Added 4D file check
# 11) Added option for no session variable
# 12) Stack check
# TODO: Add QC function or source QC script
#===============================================================================

#userID=`whoami`
set -e

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  #if [[ "${DEBUG}" = false ]]; then
  if [[ "${KEEP}" = false ]]; then
    if [[ -n "${DIR_SCRATCH}" ]]; then
      if [[ -d "${DIR_SCRATCH}" ]]; then
        if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
          rm -R ${DIR_SCRATCH}
        else
          rmdir ${DIR_SCRATCH}
        fi
      fi
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" = false ]]; then
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
OPTS=`getopt -o hvkl --long prefix:,\
ts-bold:,target:,template:,space:,is_ses:,\
dir-save:,dir-scratch:,dir-code:,dir-template:,dir-pincsource:,\
keep,help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
PREFIX=
TS_BOLD=
TARGET=T1w
TEMPLATE=
SPACE=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${OPERATOR}_${DATE_SUFFIX}
#For testing below
#DIR_SCRATCH=~
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=1
KEEP=false
NO_LOG=false
IS_SES=true

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --target) TARGET="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --is_ses) IS_SES="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-template) DIR_TEMPLATE="$2" ; shift 2 ;;
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
  echo 'Date:   2020-03-27'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --is_ses <boolean>       is there a session folder,'
  echo '                           default: true'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --target <value>         target modality to work with, default=T1w'
  echo '  --template <value>       name of template to use, e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-template <value>   directory where INC templates are stored,'
  echo '                           default: ${DIR_TEMPLATE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

#Debugging statement - only uncomment if debugging
#read -p "Press [Enter] key to continue debugging..."

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

if [ -f "${TS_BOLD}" ]; then
  DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${TS_BOLD}`
  SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "sub"`
  SESSION=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "ses"`
  TASK=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "task"`
  RUN=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "run"`
  if [ -z "${PREFIX}" ]; then
    PREFIX=`${DIR_CODE}/bids/get_bidsbase -s -i ${TS_BOLD}}`
  fi
else
  echo "The BOLD file does not exist. Exiting."
  echo "Check paths, file names, and arguments."
  exit 1
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

### put check in here for 4d file.
### L. Hopkins 7/2/2020
if [ "${NUM_TR}" == 1 ]; then
    echo "Input file is not a 4D file. Aborting."
    exit
fi


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
#read -p "Press [Enter] key to continue debugging..."

mv ${DIR_SCRATCH}/${PREFIX}_mask-brain_mask.nii.gz ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz

# Registration to subject space -----------------------------------------------
# L. Hopkins 7/22/2020 - Add options for situations where there is no SESSION info
if [ "${IS_SES}" = true ]; then
  T1=(`ls ${DIR_PROJECT}/derivatives/anat/native/sub-${SUBJECT}_ses-${SESSION}*${TARGET}.nii.gz`)
  T1_MASK=(`ls ${DIR_PROJECT}/derivatives/anat/mask/sub-${SUBJECT}_ses-${SESSION}*mask-brain*.nii.gz`)
  # use raw to rigid transform to initialize, if it exists
  RAW_TO_RIGID=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}/sub-${SUBJECT}_ses-${SESSION}*${TARGET}+raw*.mat`)
else
  T1=(`ls ${DIR_PROJECT}/derivatives/anat/native/sub-${SUBJECT}*${TARGET}.nii.gz`)
  T1_MASK=(`ls ${DIR_PROJECT}/derivatives/anat/mask/sub-${SUBJECT}*mask-brain*.nii.gz`)
  RAW_TO_RIGID=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/sub-${SUBJECT}*${TARGET}+raw*.mat`)
fi

if [ ! -z "${RAW_TO_RIGID}" ]; then
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
if [ "${IS_SES}" = true ]; then
  #XFM_NORM=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}/*${TARGET}+rigid_to-${TEMPLATE}+*_xfm-stack.nii.gz`)
  XFM_NORM=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}/sub-${SUBJECT}_ses-${SESSION}_from-native_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz`)
else
  #XFM_NORM=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/*${TARGET}+rigid_to-${TEMPLATE}+*_xfm-stack.nii.gz`)
  XFM_NORM=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/sub-${SUBJECT}_from-native_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz`)
fi

### ADD in here what to do if stack is not found but components are
### L. Hopkins 7/2/2020 -- still editing
# Holy shit is this even right?
<<<<<<< HEAD
=======
#Doesn't matter - this file no longer exists; can delete
>>>>>>> db01d2dfa36ab7402c32b2204b6c72165d331e1d
# if [ ! -z "${XFM_NORM}" ]; then
#   echo "Stack exists - applying transforms mean BOLD to template"
# else
#   echo "Stack does not exist - making stack from components"
#   if [ "${IS_SES}" = false ]; then
#     XFM_NORM=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/sub-${SUBJECT}_from-native_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz`)
#   else
#     XFM_NORM=(`ls ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}/sub-${SUBJECT}_ses-${SESSION}_from-native_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz`)
#   fi
# fi

antsApplyTransforms -d 3 \
  -o ${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz \
  -i ${DIR_SCRATCH}/${PREFIX}_avg.nii.gz \
  -t ${XFM_NORM} \
  -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_stack.nii.gz \
  -r ${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz
# apply to brain mask as well
antsApplyTransforms -d 3 -n NearestNeighbor\
  -o ${DIR_SCRATCH}/${PREFIX}_mask-brain+warp.nii.gz \
  -i ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz \
  -t ${XFM_NORM} \
  -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_stack.nii.gz \
  -r ${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz

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
if [ "${IS_SES}" = true ]; then
  DIR_REGRESSOR=${DIR_PROJECT}/derivatives/func/regressors/sub-${SUBJECT}/ses-${SESSION}
else
  DIR_REGRESSOR=${DIR_PROJECT}/derivatives/func/regressors/sub-${SUBJECT}
fi
mkdir -p ${DIR_REGRESSOR}
mv ${DIR_SCRATCH}/${PREFIX}_moco+6.1D ${DIR_REGRESSOR}/
mv ${DIR_SCRATCH}/${PREFIX}_moco+12.1D ${DIR_REGRESSOR}/

mkdir -p ${DIR_PROJECT}/derivatives/func/mask
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz \
  ${DIR_PROJECT}/derivatives/func/mask/${PREFIX}_acq-bold_mask-brain.nii.gz
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain+warp.nii.gz \
  ${DIR_PROJECT}/derivatives/func/mask/${PREFIX}_reg-${TEMPLATE}+${SPACE}_acq-bold_mask-brain.nii.gz

mkdir -p ${DIR_PROJECT}/derivatives/func/moco_${TEMPLATE}+${SPACE}
mv ${DIR_SCRATCH}/${PREFIX}_moco+warp.nii.gz \
  ${DIR_PROJECT}/derivatives/func/moco_${TEMPLATE}+${SPACE}/${PREFIX}_reg-${TEMPLATE}+${SPACE}_bold.nii.gz

if [[ "${KEEP}" == "true" ]]; then
  if [ "${IS_SES}" = true ]; then
    mkdir -p ${DIR_PROJECT}/derivatives/func/prep/sub-${SUBJECT}/ses-${SESSION}
    mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/func/prep/sub-${SUBJECT}/ses-${SESSION}/
  else
    mkdir -p ${DIR_PROJECT}/derivatives/func/prep/sub-${SUBJECT}
    mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/func/prep/sub-${SUBJECT}/
  fi
fi

#===============================================================================
# End of function
#===============================================================================

###ADD QC function - mriqc
# if [ ! command -v pip &> /dev/null ]; then
#     echo "pip could not be found"
#     exit
# fi

exit 0

