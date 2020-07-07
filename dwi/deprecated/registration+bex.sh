#!/bin/bash -e

#===============================================================================
# Registration native space to create brain mask
# Authors: Josh Cochran
# Date: 3/30/2020
#===============================================================================

PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
DEBUG=false
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v DIR_PROJECT ]]; then
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
OPTS=`getopt -o hcvkl --long group:,prefix:,template:,space:,method:,b0-mean:,\
dir-scratch:,dir-code:,dir-pincsource:,dir-save:,\
keep,help,verbose,dry-run,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

GROUP=
PREFIX=
B0_MEAN=
TEMPLATE=HCPICBM
SPACE=1mm
DIR_SAVE=
METHOD=ANTs
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
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
    --b0-mean) B0_MEAN="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --method) METHOD="$2" ; shift 2 ;;
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
  echo '  --b0-mean <value>        topup B0 mean file'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --method <value>         brain mask method, e.g., ANTs'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_NIMGCORE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${B0_MEAN}`
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
# Brain Mask/T2 registration
#==============================================================================

DIR_XFM=${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
DIR_ANAT_MASK=${DIR_PROJECT}/derivatives/anat/mask
DIR_ANAT_NATIVE=${DIR_PROJECT}/derivatives/anat/native

mkdir -p ${DIR_XFM}

#rm ${DIR_SAVE}/*.mat  > /dev/null 2>&1
#rm ${DIR_SAVE}/*prep-rigid*  > /dev/null 2>&1

FIXED_IMAGE=${DIR_ANAT_NATIVE}/${PREFIX}_T2w.nii.gz
MOVING_IMAGE=${B0_MEAN}
antsRegistration \
  -d 3 \
  --float 1 \
  --verbose ${VERBOSE} \
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
  -i ${DIR_ANAT_MASK}/${PREFIX}_mask-brain+${METHOD}.nii.gz \
  -o ${DIR_SCRATCH}/DTI_undilatedMask.nii.gz \
  -t [${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affineMask.mat,1] \
  -r ${DIR_SAVE}/All_hifi_b0_mean.nii.gz

ImageMath 3 ${DIR_SAVE}/DTI_mask.nii.gz MD ${DIR_SCRATCH}/DTI_undilatedMask.nii.gz 5

cp ${DIR_SCRATCH}/DTI_undilatedMask.nii.gz ${DIR_SAVE}/DTI_undilatedMask.nii.gz

chgrp -R ${GROUP} ${DIR_SAVE} > /dev/null 2>&1
chmod -R g+rw ${DIR_SAVE} > /dev/null 2>&1

# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}/
fi

# Exit function ---------------------------------------------------------------
exit 0