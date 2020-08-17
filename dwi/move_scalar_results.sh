#!/bin/bash -e

#===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
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
OPTS=`getopt -o hvkl --long group:,prefix:,\
dir-dwi:,dir-project:,dir-code:,\
help,verbose,no-log,keep -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
DIR_DWI=
DIR_PROJECT=
DIR_CODE=/Shared/inc_scratch/code
HELP=false
VERBOSE=0
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
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
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dir-dwi <value>        directory to save output, default varies by function'
  echo '  --dir-project <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
anyfile=`ls ${DIR_DWI}/sub-*.nii.gz`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

mkdir -p ${DIR_PROJECT}/derivatives/dwi/B0+mean
mv ${DIR_DWI}/${PREFIX}_B0+mean.nii.gz ${DIR_PROJECT}/derivatives/dwi/B0+mean/

mkdir -p ${DIR_PROJECT}/derivatives/dwi/mask
mv ${DIR_DWI}/${PREFIX}_mod-B0_mask-brain.nii.gz ${DIR_PROJECT}/derivatives/dwi/mask

mkdir -p ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
mv ${DIR_DWI}/*xfm* ${DIR_PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}

mkdir -p ${DIR_PROJECT}/derivatives/dwi/corrected_raw
mv ${DIR_DWI}/${PREFIX}_dwi+corrected.nii.gz ${DIR_PROJECT}/derivatives/dwi/corrected_raw/${PREFIX}_dwi.nii.gz

mkdir -p ${DIR_PROJECT}/derivatives/dwi/bvec+bval
mv ${DIR_DWI}/${PREFIX}.bvec ${DIR_PROJECT}/derivatives/dwi/bvec+bval
mv ${DIR_DWI}/${PREFIX}.bval ${DIR_PROJECT}/derivatives/dwi/bvec+bval

corrected_list=(`ls ${DIR_DWI}/${PREFIX}_reg*`)
for (( i=0; i<${#corrected_list[@]}; i++ )); do
  SPACE=`${DIR_CODE}/bids/get_field.sh -i ${corrected_list[${i}]} -f reg`
  mkdir -p ${DIR_PROJECT}/derivatives/dwi/corrected_${SPACE}
  mv ${corrected_list[${i}]} ${DIR_PROJECT}/derivatives/dwi/corrected_${SPACE}/
done

rsync -r ${DIR_DWI}/scalar* ${DIR_PROJECT}/derivatives/dwi/

rsync -r ${DIR_DWI}/tensor* ${DIR_PROJECT}/derivatives/dwi/

if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_DWI}/* ${DIR_PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}/
else
  if [[ "$(ls -A ${DIR_DWI})" ]]; then
    rm -R ${DIR_DWI}/*
  fi
  rmdir ${DIR_DWI}
fi

#===============================================================================
# End of Function
#===============================================================================

# Exit function ---------------------------------------------------------------
exit 0

