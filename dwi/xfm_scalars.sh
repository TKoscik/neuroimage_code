#!/bin/bash -e

#===============================================================================
# Apply transforms to scalars
# Authors: Josh Cochran
# Date: 7/1/2020
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
OPTS=`getopt -o hdcvkl --long group:,prefix:,\
dir-dwi:,scalars:,xfms:,ref-image:,\
dir-code:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
DIR_DWI=
SCALARS=fa,md,ad,rd
XFMS=
REF_IMAGE=
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --scalars) SCALARS="$2" ; shift 2 ;;
    --xfms) XFMS="$2" ; shift 2 ;;
    --ref-image) REF_IMAGE="$2" ; shift 2 ;;
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
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --scalars <value>        name of scalars'
  echo '                           default: fa,md,ad,rd'
  echo '  --xfms <value>           transform files '
  echo '  --dir-dwi <value>        dwi working directory'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --ref-image <value>      referance image'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
anyfile=`ls ${DIR_DWI}/sub-*.nii.gz`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

#===============================================================================
# Start of Function
#===============================================================================
XFM_LIST=(${XFMS//,/ })
N_XFM=${#XFM[@]}
SCALAR_LIST=(${SCALARS//,/ })
N_SCALAR=${#SCALAR_LIST[@]}

SPACE=`${DIR_CODE}/bids/get_field.sh -i ${XFM_LIST[0]} -f to`
mkdir -p ${DIR_DWI}/scalar_${SPACE}

for (( i=0; i<${N_SCALAR}; i++ )); then
  xfm_fcn="antsApplyTransforms -d 3"
  if [[ "${SCALAR_LIST[${i}],,}" == "fa" ]]; then
    mkdir -p ${DIR_DWI}/scalar_${SPACE}/FA
    xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/tensor/${PREFIX}_Scalar_FA.nii.gz"
    xfm_fcn="${xfm_fcn} -o ${DIR_DWI}/scalar_${SPACE}/${PREFIX}_Scalar_FA.nii.gz"
  fi
  if [[ "${SCALAR_LIST[${i}],,}" == "md" ]]; then
    mkdir -p ${DIR_DWI}/scalar_${SPACE}/MD
    xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/tensor/${PREFIX}_Scalar_MD.nii.gz"
    xfm_fcn="${xfm_fcn} -o ${DIR_DWI}/scalar_${SPACE}/${PREFIX}_Scalar_MD.nii.gz"
  fi
  if [[ "${SCALAR_LIST[${i}],,}" == "ad" ]]; then
    mkdir -p ${DIR_DWI}/scalar_${SPACE}/AD
    xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/tensor/${PREFIX}_Scalar_L1.nii.gz"
    xfm_fcn="${xfm_fcn} -o ${DIR_DWI}/scalar_${SPACE}/${PREFIX}_Scalar_AD.nii.gz"
  fi
  if [[ "${SCALAR_LIST[${i}],,}" == "rd" ]]; then
    mkdir -p ${DIR_DWI}/scalar_${SPACE}/RD
    fslmaths ${DIR_DWI}/tensor/${PREFIX}_Scalar_L2.nii.gz \
      -add ${DIR_DWI}/tensor/${PREFIX}_Scalar_L3.nii.gz -div 2 \
      ${DIR_DWI}/tensor/${PREFIX}_Scalar_RD.nii.gz
    xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/tensor/${PREFIX}_Scalar_RD.nii.gz"
    xfm_fcn="${xfm_fcn} -o ${DIR_DWI}/scalar_${SPACE}/${PREFIX}_Scalar_RD.nii.gz"
  fi
  if [[ "${SCALAR_LIST[${i}],,}" == "s0" ]]; then
    mkdir -p ${DIR_DWI}/scalar_${SPACE}/S0
    xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/tensor/${PREFIX}_Scalar_S0.nii.gz"
    xfm_fcn="${xfm_fcn} -o ${DIR_DWI}/scalar_${SPACE}/${PREFIX}_Scalar_S0.nii.gz"
  fi
  for (( j=0; j<${N_XFM}; j++ )); do
    xfm_fcn="${xfm_fcn} -t ${XFM_LIST[${j}]}"
  done
  xfm_fcn="${xfm_fcn} -r ${REF_IMAGE}"
  eval ${xfm_fcn}
done

#===============================================================================
# End of Function
#===============================================================================

# Exit function ---------------------------------------------------------------
exit 0

