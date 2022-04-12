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
OPTS=$(getopt -o hvkl --long dir-nii:,df-data:,pid:,sid:,factor:,\
formula:,model-prefix:,lm,lme,glme,\
roi:,coef,aov,diffmeans,\
fdr:,ci:,\
dir-save:,restart,no-rand,num-cores:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DIR_NII=
DF_DATA=
PID="participant_id"
SID="session_id"
FACTOR=
FORMULA=
MODEL_PFX="inc-voxelwise-model"
LM=false
LME=false
GLME=false
ROI=
COEF=false
AOV=false
DIFFMEANS=false
FDR=NA
CI=95
RESTART=false
NO_RAND=false
NUM_CORES=${NSLOTS}
DIR_SAVE=
DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    --dir-nii) DIR_NII="$2" ; shift 2 ;;
    --df-data) DF_DATA="$2" ; shift 2 ;;
    --pid) PID="$2" ; shift 2 ;;
    --sid) SID="$2" ; shift 2 ;;
    --factor) FACTOR="$2" ; shift 2 ;;
    --formula) FORMULA="$2" ; shift 2 ;;
    --model-prefix) MODEL_PFX="$2" ; shift 2 ;;
    --lm) LM="true" ; shift ;;
    --lme) LME="true" ; shift ;;
    --glme) GLME="true" ; shift ;;
    --roi) ROI="$2" ; shift 2 ;;
    --coef) COEF="true" ; shift ;;
    --aov) AOV="true" ; shift ;;
    --diffmeans) DIFFMEANS="true" ; shift ;;
    --fdr) FDR="$2" ; shift 2 ;;
    --ci) CI="$2" ; shift 2 ;;
    --restart) RESTART="true" ; shift ;;
    --no-rand) NO_RAND="true" ; shift ;;
    --num-cores) NUM_CORES="$2" ; shift 2 ;;
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
PROJECT=$(getProject -i ${NII_DATA})
DIR_PROJECT=$(getDir -i ${NII_DATA})

# check inputs -----------------------------------------------------------------
## check for FORMULA
if [[ -z FORMULA ]]; then
  echo "You must specify a model FORMULA. aborting"
  exit 2
fi

## check FUNCTION, set to LM or LME if blank and a pipe is present
if [[ "${FORMULA}" == *"|"* ]]; then
  if [[ "${LME}" == "false" ]] \
  && [[ "${GLME}" == "false" ]]; then
    LME="true"
    LM="false"
  fi
else
  LM="true"
  LME="false"
  GLME="false"
fi
if [[ "${VERBOSE}" == "true" ]]; then
  if [[ "${LM}" == "true" ]]; then echo "Using LM for modelling"; fi
  if [[ "${LME}" == "true" ]]; then echo "Using LMER for modelling"; fi
  if [[ "${GLME}" == "true" ]]; then echo "Using GLMER for modelling"; fi
fi

## check OUTPUTS ---------------------------------------------------------------
if [[ "${COEF}" == "false" ]] \
&& [[ "${AOV}" == "false" ]] \
&& [[ "${DIFFMEANS}" == "false" ]]; then
  echo "You must specify at least one output type, either COEF, AOV, or DIFFMEANS"
  exit 3
fi

## check NUM_CORES -------------------------------------------------------------
if [[ ${NUM_CORES} -gt ${NSLOTS} ]]; then
  echo "cores cannot exceed available slots, setting cores to ${NSLOTS}"
  NUM_CORES=${NSLOTS}
elif [[ ${NUM_CORES} -lt ${NSLOTS} ]]; then
  echo "there are ${NSLOTS} slots available, you are using ${NUM_CORES}"
fi

## check CI --------------------------------------------------------------------
if [[ ${CI} -gt 100 ]]; then
  echo "Confidence interval must be between 90 and 100"
  exit 4
elif [[ ${CI} -lt 90 ]]; then
  echo "You are using a very generous confidence interval; consider what you are doing carefully. Continuing under duress..."
fi

# set save directory -----------------------------------------------------------
if [[ -z ${DIR_SAVE} ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/analyses
fi
DIR_SAVE=${DIR_SAVE}/${MODEL_PFX}_${DATE_SUFFIX}
mkdir -p ${DIR_SAVE}

# gather NII files -------------------------------------------------------------
## check for *.nii.gz, if any copy, all to scratch and unzip
GZLS=($(ls ${DIR_NII}/*.nii.gz))
if [[ ${#GZLS[@]} -gt 0 ]]; then
  mkdir -p ${DIR_SCRATCH}
  cp ${DIR_NII}/*.nii ${DIR_SCRATCH}/
  cp ${DIR_NII}/*.nii.gz ${DIR_SCRATCH}/
  gunzip ${DIR_SCRATCH}/*
  DIR_NII=${DIR_SCRATCH}
fi



## be sure to exclude ses-id if NULL

#===============================================================================
# End of Function
#===============================================================================
exit 0



