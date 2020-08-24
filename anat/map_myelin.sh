#!/bin/bash
#===============================================================================
# Calculate Myelin Map
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-12
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
OPTS=`getopt -o hdvl --long group:,prefix:,\
t1:,t2:,\
dir-save:,dir-scratch:,dir-code:,dir-pincsource:,\
help,debug,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
PREFIX=
T1=
T2=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -d | --debug) DEBUG=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --t1) T1="$2" ; shift 2 ;;
    --t2) T2="$2" ; shift 2 ;;
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
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo 'Author: <<author names>>'
  echo 'Date:   <<date of authorship>>'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -d | --debug             keep scratch folder for debugging'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --t1 <value>             T1-weighted image'
  echo '  --t2 <value>             T2-weighted image'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${DIR_PROJECT}/derivatives/anat/myelin_${SPACE}'
  echo '                           Space will be drawn from folder name,'
  echo '                           e.g., native = native'
  echo '                                 reg_${TEMPLATE}_${SPACE}'
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
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${T1}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${T1} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${T1} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

#==============================================================================
# Start of function
#==============================================================================
SPACE=`${DIR_CODE}/bids/get_space_label.sh -i ${T1}`
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/myelin_${SPACE}
fi
mkdir -p ${DIR_SAVE}

# resample T2-weighted image to match T1-weighted as necessary
IFS=x read -r -a pixdim_t1 <<< $(PrintHeader ${T1} 1)
IFS=x read -r -a pixdim_t2 <<< $(PrintHeader ${T2} 1)
if [[ "${pixdim_t1[0]}" != "${pixdim_t2[0]}" ]] || \
   [[ "${pixdim_t1[1]}" != "${pixdim_t2[1]}" ]] || \
   [[ "${pixdim_t1[2]}" != "${pixdim_t2[2]}" ]]; then
   mkdir -p ${DIR_SCRATCH}
   T2_NAME=`basename ${T2}`
   antsApplyTransforms -d 3 \
     -i ${T2} -o ${DIR_SCRATCH}/${T2_NAME} \
     -r ${T1}
  T2=${DIR_SCRATCH}/${T2_NAME}
fi

# Calculate Myelin Map
fslmaths ${T1} -div ${T2} ${DIR_SAVE}/${PREFIX}_reg-${SPACE}_myelin.nii.gz -odt float

#==============================================================================
# End of function
#==============================================================================
exit 0

