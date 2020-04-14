#!/bin/bash -e

#===============================================================================
# Registration of images to a participant's base image
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-25
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
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hdvksl --long group:,prefix:,\
fixed:,moving:,interpolation:,syn,\
dir-save:,dir-scratch:,dir-code:,dir-pincsource:,\
help,debug,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
FIXED_IMAGE=
FIXED_SPACE=native
MOVING_IMAGE=
DO_SYN=false
INTERPOLATION=BSpline[3]
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -d | --debug) DEBUG=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -s | --syn) DO_SYN=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --fixed) FIXED_IMAGE="$2" ; shift 2 ;;
    --moving) MOVING_IMAGE="$2" ; shift 2 ;;
    --interpolation) INTERPOLATION="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
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
  echo '  -c | --dry-run           test run of function'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --fixed <value>          "native" to keep base image spacing [default],'
  echo '                           "raw" to keep moving image spacing, or'
  echo '                           "MxNxO" to set desired spacing'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${MOVING_IMAGE}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${MOVING_IMAGE} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${MOVING_IMAGE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase.sh -s -i ${MOVING_IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
DIR_XFM==${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

#===============================================================================
# Start of Function
#===============================================================================
# Set reference image to specified spacing
REFERENCE_IMAGE=${DIR_SCRATCH}/reference_image.nii.gz
if [[ "${FIXED_SPACE[0]}" == "native" ]]; then
  # use base image space
  cp ${FIXED_IMAGE} ${REFERENCE_IMAGE}
elif [[ "${FIXED_SPACE[0]}" == "raw" ]]; then
  # set reference image to spacing of moving image
  IFS=x read -r -a pixdim <<< $(PrintHeader ${MOVING_IMAGE} 1)
  ResampleImage 3 ${FIXED_IMAGE} ${REFERENCE_IMAGE} \
    ${pixdim[0]}x${pixdim[1]}x${pixdim[2]} 0 0 6
else
  # set reference image to spacing provided
  SPACE=${FIXED_SPACE//mm/}
  SPACE=${SPACE//um/}
  UNIT=${FIXED_SPACE:(-2)}
  if [[  "${UNIT}" == "um" ]]; then
    SPACE=`echo "${SPACE}/1000" | bc -l | awk '{printf "%0.3f", $0}'` 
  fi
  ResampleImage 3  ${FIXED_IMAGE} ${REFERENCE_IMAGE} ${SPACE}x${SPACE}x${SPACE} 0 0 6
fi

# setup filenames
FIXED_MOD=`${DIR_CODE}/bids/get_field.sh -i ${FIXED_IMAGE} -f "modality"`
MOVING_MOD=`${DIR_CODE}/bids/get_field.sh -i ${MOVING_IMAGE} -f "modality"`

# perform ANTs registration
reg_fcn="antsRegistration"
reg_fcn="${reg_fcn} -d 3 --float 1 --verbose ${VERBOSE} -u 0 -z 1"
reg_fcn="${reg_fcn} -n ${INTERPOLATION}"
reg_fcn="${reg_fcn} -o [${DIR_SCRATCH}/xfm_,${DIR_SAVE}/${PREFIX}_reg-${FIXED_MOD}+${FIXED_SPACE}_${MOVING_MOD}.nii.gz]"
reg_fcn="${reg_fcn} -r [${FIXED_IMAGE},${MOVING_IMAGE},1]"
reg_fcn="${reg_fcn} -t Rigid[0.1]"
reg_fcn="${reg_fcn} -m MI[${FIXED_IMAGE},${MOVING_IMAGE},1,32,Regular,0.25]"
reg_fcn="${reg_fcn} -c [2000x2000x1000x1000,1e-6,10] -f 8x4x2x1 -s 3x2x1x0vox"
reg_fcn="${reg_fcn} -t Affine[0.1]"
reg_fcn="${reg_fcn} -m MI[${FIXED_IMAGE},${MOVING_IMAGE},1,32,Regular,0.25]"
reg_fcn="${reg_fcn} -c [2000x2000x1000x1000,1e-6,10] -f 8x4x2x1 -s 3x2x1x0vox"
if [[ "${DO_SYN}" == "true" ]]; then
  reg_fcn="${reg_fcn} -t SyN[0.1,3,0]"
  reg_fcn="${reg_fcn} -m MI[${FIXED_IMAGE},${MOVING_IMAGE},1,32,Regular,0.25]"
  reg_fcn="${reg_fcn} -c [500x200x100x50,1e-6,10] -f 8x4x2x1 -s 3x2x1x0vox"
fi
eval ${reg_fcn}

# Move transforms 
mv ${DIR_SCRATCH}/xfm${i}_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-${MOVING_MOD}+raw_to-${FIXED_MOD}+${FIXED_SPACE}_xfm-affine.mat
if [[ "${DO_SYN}" == "true" ]]; then
  mv ${DIR_SCRATCH}/xfm${i}_1Warp.nii.gz \
    ${DIR_XFM}/${PREFIX}_from-${MOVING_MOD}+raw_to-${FIXED_MOD}+${FIXED_SPACE}_xfm-syn.nii.gz
  mv ${DIR_SCRATCH}/xfm${i}_1InverseWarp.nii.gz \
    ${DIR_XFM}/${PREFIX}_from-${FIXED_MOD}+${FIXED_SPACE}_to-${MOVING_MOD}+raw_xfm-syn.nii.gz
fi

#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}/
fi

exit 0

