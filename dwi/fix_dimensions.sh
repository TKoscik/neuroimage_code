#!/bin/bash -e
#===============================================================================
# Fix odd dimensions in file
# Authors: Josh Cochran & Timothy R. Koscik, PhD
# Date: 3/30/2020 - 2020-06-15
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
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
dir-dwi:,dir-save:,dir-scratch:,dir-code:,dir-pincsource:,\
keep,help,verbose,dry-run,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DIR_DWI=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix, default: sub-123_ses-1234abcd'
  echo '  --dir-dwi <value>        location of the raw DWI data'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DWI_LIST=($(ls ${DIR_DWI}/*_dwi.nii.gz))
N_DWI=${#DWI_LIST[@]}

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_DWI}
fi
mkdir -p ${DIR_SAVE}

#==============================================================================
# Check and Fix Odd Dimensions
#==============================================================================
for (( i=0; i<${N_DWI}; i++ )); do
  DWI=${DWI_LIST[${i}]}
  NAME_BASE=$(${DIR_CODE}/bids/get_bidsbase.sh -i ${DWI})
  unset DIM_TEMP
  DIM_TEMP=`PrintHeader ${DWI} 2`
  DIM_TEMP=(${DIM_TEMP//x/ })
  DIMCHK=0
  for j in {0..2}; do
    if [ $((${DIM_TEMP[${j}]}%2)) -eq 1 ]; then
      DIM_TEMP[${j}]=$((${DIM_TEMP[${j}]}-1))
      DIMCHK=1
    fi
  done
  if [ ${DIMCHK} -eq 1 ]; then
    fslroi ${DWI} ${DIR_SAVE}/${NAME_BASE}.nii.gz 0 ${DIM_TEMP[0]} 0 ${DIM_TEMP[1]} 0 ${DIM_TEMP[2]}
  fi
done

#==============================================================================
# End of function
#==============================================================================
exit 0

