#!/bin/bash -e

#===============================================================================
# Creates basic fibertracking for dwi images using DSIStudio
# See here for more informatino on DSIStudio command line prompts that can used
#http://dsi-studio.labsolver.org/Manual/command-line-for-dsi-studio
# Authors: Josh Cochran
# Date: 6/10/2020
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
    logBenchmark --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    if [[ -n "${DIR_PROJECT}" ]]; then
      logProject --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
      --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      if [[ -n "${SID}" ]]; then
        logSession --operator ${OPERATOR} \
        --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
        --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
        --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      fi
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o h --long prefix:,\
bvec:,bval:,dwi-file:,brain-mask:,\
dir-save:,dir-scratch:,\
help -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
BVEC=
BVAL=
DWI_FILE=
BRAIN_MASK=
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --bvec) BVEC="$2" ; shift 2 ;;
    --bval) BVAL="$2" ; shift 2 ;;
    --dwi-file) DWI_FILE="$2" ; shift 2 ;;
    --brain-mask) BRAIN_MASK="$2" ; shift 2 ;;
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
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --bvec <value>           bvec file'
  echo '  --bval <value>           bval file'
  echo '  --dwi-file <value>       corrected dwi file'
  echo '  --brain-mask <value>     brain mask for dwi image'
  echo '  --dsi-studio <value>     DSIStudio path, preset to version 20200122'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(getDir -i ${{DWI_FILE})
PID=$(getField -i ${{DWI_FILE} -f sub)
SID=$(getField -i ${{DWI_FILE} -f ses)
DIR_SUBSES="sub-${PID}"
if [[ -n ${SID} ]]; then
  DIR_SUBSES="ses-${SID}"
fi
if [ -z "${PREFIX}" ]; then
  PREFIX=$(getBidsBase -s -i ${DWI_FILE})
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/dwi/tractography/${DIR_SUBSES}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# Create the src file ----------------------------------------------------------
${DSISTUDIO} --action=src \
--source=${DWI_FILE} \
--bvec=${BVEC} \
--bval=${BVAL} \
--output=${DIR_SCRATCH}/${PREFIX}.src.gz

# QC src file ------------------------------------------------------------------
${DIR_DSISTUDIO} --action=qc \
--source=${DIR_SCRATCH}

# Image reconstruction ---------------------------------------------------------
${DIR_DSISTUDIO} --action=rec \
--source=${DIR_SCRATCH}/${PREFIX}.src.gz \
--method=1 \
--mask=${BRAIN_MASK}

FIB_FILE=($(ls ${DIR_SCRATCH}/${PREFIX}*fib.gz))

#ALL INFO ON COMMAND PROMPTS FOR TRACKING CAN BE FOUND HERE
#http://dsi-studio.labsolver.org/Manual/command-line-for-dsi-studio

#Fiber tracking
#${DIR_DSISTUDIO}/dsi_studio --action=trk \
#--source=${FIB_FILE} \
#--connectivity=WBCXN \
#--fa_threshold=0.2 \
#--output=${DIR_SCRATCH}/${PREFIX}_wb-track.trk.gz

# Move files to save directory -------------------------------------------------
mv ${FIB_FILE} ${DIR_SAVE}/${PREFIX}.fib.gz
mkdir -p ${DIR_PROJECT}/qc/src_reports
mv ${DIR_SCRATCH}/src_report.txt ${DIR_PROJECT}/qc/src_reports/${PREFIX}_src_report.txt
mv ${DIR_SCRATCH}/${PREFIX}_wb-track* ${DIR_SAVE}
mv ${DIR_SCRATCH}/*mapping.gz ${DIR_SAVE}

#===============================================================================
# End of Function
#===============================================================================
exit 0

