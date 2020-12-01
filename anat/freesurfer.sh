#!/bin/bash -e

#===============================================================================
# Function Description
# Authors: Josh Cochran
# Date: 11/30/20
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
OPTS=$(getopt -o h --long \
t1:,t2:,\
help -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
T1=
T2=
HELP=false
DIR_INC=/Shared/inc_scratch/code

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    --t1) T1="$2" ; shift 2 ;;
    --t2) T2="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done


# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FCN_NAME=($(basename "$0"))
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  --t1 <value>             T1w images, can take multiple comma seperated images'
  echo '  --t2 <value>             T2w images, can take multiple comma seperated images'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${T1})
SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f "sub")
SESSION=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f "ses")
if [ -z "${PREFIX}" ]; then
  PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${T1})
fi
mkdir -p ${DIR_PROJECT}/derivatives/freesurfer/subject_dir

T1=(${T1//,/ })
T2=(${T2//,/ })
N_T1=${#T1[@]}
N_T2=${#T2[@]}

unset IMAGES
for (( i=0; i<${N_T1}; i++ )); do
  IMAGES+=(-i ${T1[${i}]}) 
done

for (( i=0; i<${N_T2}; i++ )); do
  IMAGES+=(-T2 ${T2[${i}]})
done
if [[ ${N_T2} -gt 0 ]];then
  IMAGES+=(-T2pial)
fi

export FREESURFER_HOME=/Shared/pinc/sharedopt/apps/freesurfer/Linux/x86_64/7.1.0
export SUBJECTS_DIR=${DIR_PROJECT}/derivatives/freesurfer
export FS_LICENSE=/Shared/inc_scratch/license/fs_license.txt
source ${FREESURFER_HOME}/FreeSurferEnv.sh
recon-all -subject ${PREFIX} ${IMAGES[*]} -all


#===============================================================================
# End of Function
#===============================================================================

exit 0


