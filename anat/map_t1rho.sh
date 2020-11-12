#!/bin/bash -e
#===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
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
OPTS=$(getopt -o hvkl --long prefix:,\
input:,times:,map-algorithm:,max-time:,threshold:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
PREFIX=
INPUT=
TIMES=
MAPPING_ALGORITHM=Linear
MAX_TIME=400.0
THRESHOLD=50
DIR_SAVE=
#DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
HELP=false
VERBOSE=0
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --input) INPUT="$2" ; shift 2 ;;
    --times) TIMES="$2" ; shift 2 ;;
    --map-algorithm) MAPPING_ALGORITHM="$2" ; shift 2 ;;
    --max-time) MAX_TIME="$2" ; shift 2 ;;
    --threshold) THRESHOLD="$2" ; shift 2 ;;
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
  echo '  --input <value>          Comma-separated list of paths to T1rho images'
  echo '  --times <value>          Comma-separated list of times for T1rho'
  echo '  --map-algorithm <value>  Mapping algorithm, default=Linear'
  echo '  --max-time <value>       default=400.0'
  echo '  --threshold <value>      default=50'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
fi

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${INPUT})
SUBJECT=$(${DIR_INC}/code/bids/get_field.sh -i ${INPUT} -f "sub")
SESSION=$(${DIR_INC}/code/bids/get_field.sh -i ${INPUT} -f "ses")
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}
  if [ -n "${SESSION}" ]; then
    PREFIX=${PREFIX}_ses-${SESSION}
  fi
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
#mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#===============================================================================
# Start of Function
#===============================================================================

${DIR_INC}/anat/T1rhoMap \
--inputVolumes ${INPUT} \
--t1rhoTimes ${TIMES} \
--mappingAlgorithm ${MAPPING_ALGORITHM} \
--maxTime ${MAX_TIME} \
--threshold ${THRESHOLD} \
--outputFilename ${DIR_SAVE}/${PREFIX}_T1rho.nii.gz \
--outputExpConstFilename ${DIR_SAVE}/${PREFIX}_prep-expConstant_T1rho.nii.gz \
--outputConstFilename ${DIR_SAVE}/${PREFIX}_prep-constant_T1rho.nii.gz \
--outputRSquaredFilename ${DIR_SAVE}/${PREFIX}_prep-r2_T1rho.nii.gz

#===============================================================================
# End of Function
#===============================================================================

exit 0

