#!/bin/bash -e
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
# ------------------------------------------------------------------------------
# UPDATE BY T. KOSCIK 2020-10-22
# - fixed location and specification of transforms
# --will now check early in script for necessary transforms
# --no longer requires a stacked transform, will append affine and syn
#   unless stack is present
# --fixed handling of voxel spacing
# -changed the way lack of session variables are handled to be more efficient
# TODO: Add QC function or source QC script
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(unname -s)"
HARDWARE="$(uname -m)"
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  PROC_STOP=$(date +%Y-%m-%dT%H:%M:%S%z)
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
  if [[ "${NO_LOG}" == "false" ]]; then
    ${DIR_INC}/log/logBenchmark.sh --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    ${DIR_INC}/log/logProject.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    ${DIR_INC}/log/logSession.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvkl --long prefix:,\
ts-bold:,target:,template:,space:,\
dir-save:,dir-scratch:,\
keep,help,verbose,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
TS_BOLD=
TARGET=T1w
TEMPLATE=
SPACE=
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=1
KEEP=false

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
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        Full path to single, run timeseries'
  echo '  --target <value>         target modality to work with, default=T1w'
  echo '  --template <value>       name of template to use, e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#==============================================================================
# Start of Function
#==============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
if [ -f "${TS_BOLD}" ]; then
  DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${TS_BOLD})
  PID=$(${DIR_INC}/bids/get_field.sh -i ${TS_BOLD} -f "sub")
  SID=$(${DIR_INC}/bids/get_field.sh -i ${TS_BOLD} -f "ses")
  if [ -z "${PREFIX}" ]; then
    PREFIX=$(${DIR_INC}/bids/get_bidsbase -s -i ${TS_BOLD})
  fi
else
  echo "The BOLD file does not exist. Exiting."
  exit 1
fi

# Set DIR_SAVE variable
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/func
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# Check if required files exist -----------------------------------------------
# Set some helper variables depending on whether session is specified
DIR_SUBSES=sub-${PID}
SUBSES=sub-${PID}
if [[ -n "${SID}" ]]; then
  DIR_SUBSES=${DIR_SUBSES}/ses-${SID}
  SUBSES=${SUBSES}_ses-${SID}
fi

# Native anatomical, brain mask, and rigid alignment transform
ANAT=($(ls ${DIR_PROJECT}/derivatives/inc/anat/native/${SUBSES}*${TARGET}.nii.gz))
ANAT_MASK=($(ls ${DIR_PROJECT}/derivatives/inc/anat/mask/${SUBSES}*mask-brain*.nii.gz))
XFM_ALIGN=($(ls ${DIR_PROJECT}/derivatives/inc/xfm/${DIR_SUBSES}/${SUBSES}*from-${TARGET}+raw_to-${TEMPLATE}*.mat))
if [[ -z ${ANAT} ]]; then
  echo "Native anatomical not found, aborting."
  exit 1
fi
if [[ -z ${ANAT_MASK} ]]; then
  echo "Native anatomical mask not found, aborting."
  exit 1
fi
if [[ -n ${XFM_ALIGN} ]]; then
  INIT_XFM=${XFM_ALIGN}
else
  echo "Alignment registration not found, continuing."
  INIT_XFM=[${ANAT},${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,1]
  #  exit 1
fi

# Find transforms
DIR_XFM=${DIR_PROJECT}/derivatives/inc/xfm/${DIR_SUBSES}
unset XFM_LS XFM_ARG XFM_NORM
XFM_LS=($(ls ${DIR_XFM}/*native_to-${TEMPLATE}* 2>/dev/null))
if [[ -z ${XFM_LS} ]]; then
  # note: the line below is for backward compatibility with slightly different naming scheme
  XFM_LS=($(ls ${DIR_XFM}/*${TARGET}+rigid_to-${TEMPLATE}* 2>/dev/null))
  if [[ -z ${XFM_LS} ]]; then
    echo "Normalization transform(s) not found, aborting"
    exit 1
  fi
fi

unset XFM_STACK XFM_RIGID XFM_AFFINE XFM_SYN
for (( i=0; i<${#XFM_LS[@]}; i++ )); do
  unset XFM_ARG
  XFM_ARG=$(${DIR_INC}/bids/get_field.sh -i ${XFM_LS[${i}]} -f xfm)
  if [[ "${XFM_ARG,,}" == "rigid" ]]; then XFM_RIGID=${XFM_LS[${i}]}; fi
  if [[ "${XFM_ARG,,}" == "affine" ]]; then XFM_AFFINE=${XFM_LS[${i}]}; fi
  if [[ "${XFM_ARG,,}" == "syn" ]]; then XFM_SYN=${XFM_LS[${i}]}; fi
  if [[ "${XFM_ARG,,}" == "stack" ]]; then XFM_STACK=${XFM_LS[${i}]}; fi
done
if [[ -n ${XFM_STACK} ]]; then 
  XFM_NORM=${XFM_STACK}
else
  if [[ -n ${XFM_SYN} ]]; then XFM_NORM+=(${XFM_SYN}); fi
  if [[ -n ${XFM_AFFINE} ]]; then XFM_NORM+=(${XFM_AFFINE}); fi
  if [[ -n ${XFM_RIGID} ]]; then XFM_NORM+=(${XFM_RIGID}); fi
fi
N_XFM=${#XFM_NORM[@]}

# Motion Correction + registration ============================================
# Get timeseries info ---------------------------------------------------------
NUM_TR=$(${DIR_INC}/generic/nii_info.sh -i ${TS_BOLD} -f numTR)
TR=$(${DIR_INC}/generic/nii_info.sh -i ${TS_BOLD} -f TR)
# check in here for 4d file.
if [[ "${NUM_TR}" == 1 ]]; then
    echo "Input file is not a 4D file. Aborting."
    exit 1
fi

# Motion correction -----------------------------------------------------------
# pad image for better registration
fslsplit ${TS_BOLD} ${DIR_SCRATCH}/vol -t
for (( i=0; i<${NUM_TR}; i++ )); do
  VOL_NUM=$(printf "%04d" ${i})
  ImageMath 3 ${DIR_SCRATCH}/vol${VOL_NUM}.nii.gz PadImage ${DIR_SCRATCH}/vol${VOL_NUM}.nii.gz 5
done
MERGE_LS=($(ls ${DIR_SCRATCH}/vol*))
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
antsRegistration \
  -d 3 -u 0 -z 1 -l 1 -n Linear -v ${VERBOSE} \
  -o ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_ \
  -r ${INIT_XFM} \
  -t Rigid[0.25] \
  -m Mattes[${ANAT},${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,1,32,Regular,0.2] \
  -c [1200x1200x100,1e-6,5] -f 4x2x1 -s 2x1x0vox \
  -x [${ANAT_MASK},${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz] \
  -t Affine[0.25] \
  -m Mattes[${ANAT},${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,1,32,Regular,0.2] \
  -c [200x20,1e-6,5] -f 2x1 -s 1x0vox \
  -x [${ANAT_MASK},${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz] \
  -t SyN[0.2,3,0] \
  -m Mattes[${ANAT},${DIR_SCRATCH}/${PREFIX}_avg.nii.gz,1,32] \
  -c [40x20x0,1e-7,8] -f 4x2x1 -s 2x1x0vox \
  -x [${ANAT_MASK},${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz]

# collapse transforms to deformation field
antsApplyTransforms -d 3 \
  -o [${DIR_SCRATCH}/${PREFIX}_xfm_toNative_stack.nii.gz,1] \
  -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_1Warp.nii.gz \
  -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_0GenericAffine.mat \
  -r ${ANAT}

# Push mean bold to template --------------------------------------------------
unset xfm_fcn
xfm_fcn="antsApplyTransforms -d 3"
xfm_fcn="${xfm_fcn} -o ${DIR_SCRATCH}/${PREFIX}_avg+warp.nii.gz"
xfm_fcn="${xfm_fcn} -i ${DIR_SCRATCH}/${PREFIX}_avg.nii.gz"
for (( i=0; i<${N_XFM}; i++ )); do
  xfm_fcn="${xfm_fcn} -t ${XFM_NORM}"
done
xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_stack.nii.gz"
xfm_fcn="${xfm_fcn} -r ${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz"
eval ${xfm_fcn}

# apply to brain mask as well
unset xfm_fcn
xfm_fcn="antsApplyTransforms -d 3 -n NearestNeighbor"
xfm_fcn="${xfm_fcn} -o ${DIR_SCRATCH}/${PREFIX}_mask-brain+warp.nii.gz"
xfm_fcn="${xfm_fcn} -i ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz"
for (( i=0; i<${N_XFM}; i++ )); do
  xfm_fcn="${xfm_fcn} -t ${XFM_NORM}"
done
xfm_fcn="${xfm_fcn} -t ${DIR_SCRATCH}/${PREFIX}_xfm_toNative_stack.nii.gz"
xfm_fcn="${xfm_fcn} -r ${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz"
eval ${xfm_fcn}

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
MERGE_LS=($(ls ${DIR_SCRATCH}/vol*))
fslmerge -tr ${DIR_SCRATCH}/${PREFIX}_bold.nii.gz ${MERGE_LS[@]} ${TR}
rm ${MERGE_LS[@]}

# Move files to appropriate locations -----------------------------------------
DIR_REGRESSOR=${DIR_PROJECT}/derivatives/inc/func/regressors/${DIR_SUBSES}
mkdir -p ${DIR_REGRESSOR}
mv ${DIR_SCRATCH}/${PREFIX}_moco+6.1D ${DIR_REGRESSOR}/
mv ${DIR_SCRATCH}/${PREFIX}_moco+12.1D ${DIR_REGRESSOR}/

mkdir -p ${DIR_PROJECT}/derivatives/inc/func/mask
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain.nii.gz \
  ${DIR_PROJECT}/derivatives/inc/func/mask/${PREFIX}_acq-bold_mask-brain.nii.gz
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain+warp.nii.gz \
  ${DIR_PROJECT}/derivatives/inc/func/mask/${PREFIX}_reg-${TEMPLATE}+${SPACE}_acq-bold_mask-brain.nii.gz

mkdir -p ${DIR_PROJECT}/derivatives/inc/func/moco_${TEMPLATE}+${SPACE}
mv ${DIR_SCRATCH}/${PREFIX}_moco+warp.nii.gz \
  ${DIR_PROJECT}/derivatives/inc/func/moco_${TEMPLATE}+${SPACE}/${PREFIX}_reg-${TEMPLATE}+${SPACE}_bold.nii.gz

if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/inc/func/prep/${DIR_SUBSES}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/inc/func/prep/${DIR_SUBSES}/
fi

#===============================================================================
# End of function
#===============================================================================
exit 0

