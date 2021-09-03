#!/bin/bash -e
#===============================================================================
# Calculate Z score on 4D file
# Authors: Timothy R. Koscik
# Date: 2021-09-03
# CHANGELOG: 
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(uname -s)"
HARDWARE="$(uname -m)"
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  PROC_STOP=$(date +%Y-%m-%dT%H:%M:%S%z)
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
  if [[ "${NO_LOG}" == "false" ]]; then
    unset LOGSTR
    LOGSTR="${OPERATOR},${DIR_PROJECT},${PID},${SID},${HARDWARE},${KERNEL},${HPC_Q},${HPC_SLOTS},${FCN_NAME},${PROC_START},${PROC_STOP},${EXIT_CODE}"
    writeLog --benchmark --string ${LOGSTR}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvl --long prefix:,image:,lo:,hi:,\
dir.save:,dir-scratch:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
LO=0.5
HI=1
DIR_SAVE=
DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --lo) LO="$2" ; shift 2 ;;
    --hi) HI="$2" ; shift 2 ;;
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
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix  <optional>     filename, without extension to use for file'
  echo '  --image                  filepath to 4D NIfTI file'
  echo '  --lo                     option to set intensity threshold, i.e.,'
  echo '                           lower values will be set to 0'
  echo '  --hi                     option to clip upper intensity at specified'
  echo '                           quantile'
  echo '  --dir-save               location to save output'
  echo '  --dir-scratch            location for temporary files'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(getDir -i ${IMAGE})
PID=$(getField -i ${IMAGE} -f sub)
SID=$(getField -i ${IMAGE} -f ses)
PIDSTR=sub-${PID}
DIRPID=sub-${PID}
if [[ -n ${SID} ]]; then PIDSTR="${PIDSTR}_ses-${SID}"; fi
if [[ -n ${SID} ]]; then DIRPID="${DIRPID}/ses-${SID}"; fi
if [[ -z ${PREFIX} ]]; then PREFIX=$(getBidsBase -i ${IMAGE} -s); fi

if [[ -z ${DIR_SAVE} ]]; then
  FCN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
  FCN_TYPE=(${FCN_DIR//\// })
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/${FCN_TYPE[-1]}/prep/${DIRPID}
fi
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_SCRATCH}

# copy and unzip 4D file to scratch --------------------------------------------
cp ${IMAGE} ${DIR_SCRATCH}/
TF=$(basename ${IMAGE})
gunzip ${DIR_SCRATCH}/${TF}
IMAGE=${DIR_SCRATCH}/${TF%%.*}.nii

# Calculate temporal Z Score along 4th Dimension -------------------------------
Rscript ${INC_R}/tensorZ.R ${IMAGE} "lo" ${LO} "hi" ${HI}

# move Z image to save directory
MOD=$(getField -i ${IMAGE} -f modality)
ZIMG=$(modField -i ${IMAGE} -m -f modality -v tensor-z)
ZIMG=$(modField -i ${ZIMG} -a -f mod -v ${MOD})
gzip ${ZIMG}
mv ${ZIMG} ${DIR_SAVE}/

#===============================================================================
# End of Function
#===============================================================================
exit 0

