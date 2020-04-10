#!/bin/bash -e

#===============================================================================
# Create scalars
# Authors: Josh Cochran
# Date: 3/30/2020
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hcvkl --long group:,prefix:,template:,space:,\
smoothing:,dir-scratch:,dir-nimgcore:,dir-pincsource:,dir-save:,\
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
SMOOTHING=
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
    --smoothing) SMOOTHING="$2" ; shift 2 ;;
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
  echo '  --smoothing <value>      size of the smoothing kernal, e.g., 0'
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
# DWI Scalars
#==============================================================================

DIR_TENSOR=${DIR_PROJECT}/derivatives/dwi/tensor/sub-${SUBJECT}/ses-${SESSION}

mkdir -p ${DIR_TENSOR}

if [ "${SMOOTHING}" != 0 ]; then
  fslmaths ${DIR_SAVE}/All_dwi_hifi_eddy.nii.gz -s ${SMOOTHING} ${DIR_SAVE}/All_dwi_hifi_eddy_smoothed.nii.gz
fi

if [ "${SMOOTHING}" != 0 ]; then
  dtifit \
    -k ${DIR_SAVE}/All_dwi_hifi_eddy_smoothed.nii.gz \
    -o ${DIR_SCRATCH}/All_Scalar \
    -r ${DIR_SAVE}/All.bvec \
    -b ${DIR_SAVE}/All.bval \
    -m ${DIR_SAVE}/DTI_mask.nii.gz 
else
  dtifit \
    -k ${DIR_SAVE}/All_dwi_hifi_eddy.nii.gz \
    -o ${DIR_SCRATCH}/All_Scalar \
    -r ${DIR_SAVE}/All.bvec \
    -b ${DIR_SAVE}/All.bval \
    -m ${DIR_SAVE}/DTI_mask.nii.gz 
fi
mv ${DIR_SCRATCH}/All_Scalar* ${DIR_TENSOR}/


chgrp -R ${GROUP} ${DIR_SAVE} > /dev/null 2>&1
chmod -R g+rw ${DIR_SAVE} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_TENSOR} > /dev/null 2>&1
chmod -R g+rw ${DIR_TENSOR} > /dev/null 2>&1

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
