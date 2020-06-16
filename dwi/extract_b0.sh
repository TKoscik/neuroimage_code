#!/bin/bash -e

#===============================================================================
# Extract B0 images from file, makes assumption that anything less than 10 is a B0
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
OPTS=`getopt -o hcvkl --long group:,prefix:,\
dwi:,\
dir-raw:,dir-scratch:,dir-code:,dir-pincsource:,dir-save:,\
keep,help,verbose,dry-run,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
DIR_RAW=
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
    --dir-raw) DIR_RAW="$2" ; shift 2 ;;
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
  echo '  --dir-raw <value>        location of the raw DWI data'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
DWI=(${DWI//,/ })
N_DWI=${#DWI[@]}

DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${DWI[0]}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${DWI[0]} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${DWI[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#==============================================================================
# B0 extracter
#==============================================================================

for (( i=0; i<${N_DWI}; i++ )); do
  NAME_BASE=`${DIR_CODE}/bids/get_bidsbase.sh -i ${DWI[${i}]}`
  NAME_DTI=${DWI::-11}
  B0s=($(cat ${NAME_DTI}_dwi.bval))
  mkdir ${DIR_SCRATCH}/split

  fslsplit ${DWI[${i}]} ${DIR_SCRATCH}/split/${NAME_BASE}-split-0000 -t
  for j in ${!B0s[@]}; do 
    k=$(echo "(${B0s[${j}]}/10)" | bc)
    if [ ${k} -ne 0 ]; then
      rm ${DIR_SCRATCH}/split/${NAME_BASE}-split-*000${j}.nii.gz
    fi
  done
  fslmerge -t ${DIR_SAVE}/${NAME_BASE}_b0 ${DIR_SCRATCH}/split/${NAME_BASE}*
  rm -r ${DIR_SCRATCH}/split
done

#for i in ${DIR_RAW}/*_dwi.nii.gz; do
#  NAMEBASE=$( basename $i )
#  NAMEBASE=${NAMEBASE::-11}
#  DTINAME=${i::-11}
#  B0s=($(cat ${DTINAME}_dwi.bval))
#  mkdir ${DIR_SCRATCH}/split
#
#  fslsplit ${i} ${DIR_SCRATCH}/split/${NAMEBASE}-split-0000 -t
#
#  for j in ${!B0s[@]}; do 
#    k=$(echo "(${B0s[${j}]}/10)" | bc)
#    if [ ${k} -ne 0 ]; then
#      rm ${DIR_SCRATCH}/split/${NAMEBASE}-split-*000${j}.nii.gz
#    fi
#  done
#
#  fslmerge -t ${DIR_SAVE}/${NAMEBASE}_b0 ${DIR_SCRATCH}/split/${NAMEBASE}*
#
#  rm -r ${DIR_SCRATCH}/split
#done


#===============================================================================
# End of function
#===============================================================================

exit 0

