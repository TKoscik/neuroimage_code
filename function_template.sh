#!/bin/bash -e
#===============================================================================
# <<DESCRIPTION>>
# Authors: <GIVENNAME> <FAMILYNAME>, 
# Date: <date of initial commit>
# CHANGELOG: <description of major changes to functionality>
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
OPTS=$(getopt -o hvkl --long prefix:,other:,dir.save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
OTHER=
DIR_SAVE=
DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --other) OTHER="$2" ; shift 2 ;;
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
  echo '  --other                  other inputs as needed'
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
DIR_PROJECT=$(getDir -i ${INPUT})
PID=$(getField -i ${INPUT} -f sub)
SID=$(getField -i ${INPUT} -f ses)
PIDSTR=sub-${PID}
if [[ -n ${SID} ]]; then ${PIDSTR}="${PIDSTR}_ses-${SID}"; fi
DIRPID=sub-${PID}
if [[ -n ${SID} ]]; then ${DIRPID}="${DIRPID}/ses-${SID}"; fi

if [[ -z ${PREFIX} ]]; then
  PREFIX=$(getBidsBase -i ${TS})
  PREP=$(getField -i ${PREFIX} -f prep)
  if [[ -n ${PREP} ]]; then
    PREFIX=$(modField -i ${PREFIX} -m -f prep -v "${PREP}+pad${PAD}")
  else
    PREFIX=$(modField -i ${PREFIX} -a -f prep -v "pad${PAD}")
  fi
fi

## not sure if this works and will not always be applicable ----
### may be easier to hard code the anat/func/dwi folders
FCN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FCN_TYPE=(${FCN_DIR//\// })
## ----

if [[ -z ${DIR_SAVE} ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/${FCN_TYPE[-1]}/prep/${DIRPID}
fi
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_SCRATCH}

# body of function here --------------------------------------------------------
## insert comments for important chunks
## use dashes as above to separate chunks of code visually
## move files to appropriate locations

#===============================================================================
# End of Function
#===============================================================================
exit 0


