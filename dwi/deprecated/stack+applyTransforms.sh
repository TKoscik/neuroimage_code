#!/bin/bash -e

#===============================================================================
# Stack and apply transforms
# Authors: Josh Cochran
# Date: 3/30/2020
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hcvkl --long group:,prefix:,template:,space:,\
dir-scratch:,dir-code:,dir-pincsource:,dir-save:,\
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
DIR_CODE=/Shared/inc_scratch/code
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
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
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
  echo '  --dir-code <value>       top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${DIR_SAVE}`
anyfile=(`ls ${DIR_SAVE}/sub*.nii.gz`)
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}


#==============================================================================
# Stack and Apply Transforms
#==============================================================================

DIR_TENSOR=${DIR_PROJECT}/derivatives/dwi/tensor/sub-${SUBJECT}/ses-${SESSION}
DIR_XFM=${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
DIR_TEMPLATE_SCALARS=${DIR_PROJECT}/derivatives/dwi/scalars_${TEMPLATE}_${SPACE}

mkdir -p ${DIR_TEMPLATE_SCALARS}/FA
mkdir -p ${DIR_TEMPLATE_SCALARS}/MD
mkdir -p ${DIR_TEMPLATE_SCALARS}/AD
mkdir -p ${DIR_TEMPLATE_SCALARS}/RD
mkdir -p ${DIR_TEMPLATE_SCALARS}/S0

unset xfm
#rm ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz   > /dev/null 2>&1
REF_IMAGE=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz
antsApplyTransforms -d 3 \
  -o [${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz,1] \
  -t ${DIR_XFM}/${PREFIX}_from-native_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat \
  -r ${REF_IMAGE}



unset xfm
xfm[0]=${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz
REF_IMAGE=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_FA.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/FA/${PREFIX}_reg-${TEMPLATE}+${SPACE}_FA.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_MD.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/MD/${PREFIX}_reg-${TEMPLATE}+${SPACE}_MD.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_L1.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/AD/${PREFIX}_reg-${TEMPLATE}+${SPACE}_AD.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_RD.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/RD/${PREFIX}_reg-${TEMPLATE}+${SPACE}_RD.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_S0.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/S0/${PREFIX}_reg-${TEMPLATE}+${SPACE}_S0.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${TEMPLATE}+${SPACE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}



chgrp -R ${GROUP} ${DIR_SAVE} > /dev/null 2>&1
chmod -R g+rw ${DIR_SAVE} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_TEMPLATE_SCALARS} > /dev/null 2>&1
chmod -R g+rw ${DIR_TEMPLATE_SCALARS} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_XFM} > /dev/null 2>&1
chmod -R g+rw ${DIR_XFM} > /dev/null 2>&1

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
