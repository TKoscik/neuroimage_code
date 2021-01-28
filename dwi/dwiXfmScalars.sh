#!/bin/bash -e
#===============================================================================
# Apply transforms to scalars
# Authors: Josh Cochran
# Date: 2020-07-01
#===============================================================================
PPROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
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
  LOG_STRING=$(date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}")
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
OPTS=$(getopt -o hl --long prefix:,\
dir-dwi:,scalars:,xfms:,ref-image:,\
help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DIR_DWI=
SCALARS=FA,MD,AD,RD
XFMS=
REF_IMAGE=
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --scalars) SCALARS="$2" ; shift 2 ;;
    --xfms) XFMS="$2" ; shift 2 ;;
    --ref-image) REF_IMAGE="$2" ; shift 2 ;;
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
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --scalars <value>        name of scalars default: fa,md,ad,rd'
  echo '  --xfms <value>           transform files '
  echo '  --dir-dwi <value>        dwi working directory'
  echo '  --ref-image <value>      referance image'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
anyfile=$(ls ${DIR_DWI}/sub-*.nii.gz)
if [ -z "${PREFIX}" ]; then
  SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f "sub")
  PREFIX="sub-${SUBJECT}"
  SESSION=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f "ses")
  if [[ -n ${SESSION} ]]; then
    PREFIX="${PREFIX}_ses-${SESSION}"
  fi
fi

XFMS=(${XFMS//,/ })
N_XFM=${#XFMS[@]}
SCALARS=(${SCALARS//,/ })
N_SCALAR=${#SCALARS[@]}

SPACE=$(${DIR_INC}/bids/get_field.sh -i ${XFMS[0]} -f to)
mkdir -p ${DIR_DWI}/scalar_${SPACE}

for (( i=0; i<${N_SCALAR}; i++ )); do
  mkdir -p ${DIR_DWI}/scalar_${SPACE}/${SCALARS[${i}]^^}
  xfm_fcn="antsApplyTransforms -d 3"
  if [[ "${SCALARS[${i}]^^}" == "FA" ]] || \
     [[ "${SCALARS[${i}]^^}" == "MD" ]] || \
     [[ "${SCALARS[${i}]^^}" == "S0" ]]; then
    xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/tensor/${PREFIX}_${SCALARS[${i}]^^}.nii.gz"
  fi
  if [[ "${SCALARS[${i}]^^}" == "AD" ]]; then
    xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/tensor/${PREFIX}_L1.nii.gz"
  fi
  if [[ "${SCALARS[${i}]^^}" == "RD" ]]; then
    fslmaths ${DIR_DWI}/tensor/${PREFIX}_L2.nii.gz \
      -add ${DIR_DWI}/tensor/${PREFIX}_L3.nii.gz \
      -div 2 \
      ${DIR_DWI}/tensor/${PREFIX}_RD.nii.gz
    xfm_fcn="${xfm_fcn} -i ${DIR_DWI}/tensor/${PREFIX}_RD.nii.gz"
  fi
  xfm_fcn="${xfm_fcn} -o ${DIR_DWI}/scalar_${SPACE}/${SCALARS[${i}]^^}/${PREFIX}_${SCALARS[${i}]^^}.nii.gz"
  for (( j=0; j<${N_XFM}; j++ )); do
    xfm_fcn="${xfm_fcn} -t ${XFMS[${j}]}"
  done
  xfm_fcn="${xfm_fcn} -r ${REF_IMAGE}"
  eval ${xfm_fcn}
done

#===============================================================================
# End of Function
#===============================================================================
exit 0

