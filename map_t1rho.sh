#!/bin/bash -e

#===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvkl --long group:,prefix:,\
input:,times:,map-algorithm:,max-time:,threshold:,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
INPUT=
TIMES=
MAPPING_ALGORITHM=Linear
MAX_TIME=400.0
THRESHOLD=50
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
KEEP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --input) INPUT="$2" ; shift 2 ;;
    --times) TIMES="$2" ; shift 2 ;;
    --map-algorithm) MAPPING_ALGORITHM="$2" ; shift 2 ;;
    --max-time) MAX_TIME="$2" ; shift 2 ;;
    --threshold) THRESHOLD="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo 'Author: <<author names>>'
  echo 'Date:   <<date of authorship>>'
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
  echo '  --input <value>          Comma-separated list of paths to T1rho images'
  echo '  --times <value>          Comma-separated list of times for T1rho'
  echo '  --map-algorithm <value>  Mapping algorithm, default=Linear'
  echo '  --max-time <value>       default=400.0'
  echo '  --threshold <value>      default=50'
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

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${INPUT_FILE}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${INPUT_FILE} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${INPUT_FILE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#===============================================================================
# Start of Function
#===============================================================================

/Shared/pinc/sharedopt/apps/T1rhoMap/Linux/x86_64/2017/T1rhoMap \
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

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

