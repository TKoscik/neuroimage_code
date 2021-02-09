#!/bin/bash -e
#===============================================================================
# Calculate Myelin Map
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-12
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
    ${DIR_INC}/log/logBenchmark.sh --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    if [[ -n "${DIR_PROJECT}" ]]; then
      ${DIR_INC}/log/logProject.sh --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
      --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      if [[ -n "${SID}" ]]; then
        ${DIR_INC}/log/logSession.sh --operator ${OPERATOR} \
        --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
        --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
        --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      fi
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hl --long prefix:,\
t1:,t2:,label:,label-vals:,norm-t1:,norm-t2:,\
dir-save:,dir-scratch:,\
help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
T1=
T2=
LABEL=
LABEL_VALS="1x2x3"
NORM_T1="0.1x1.45x2.45x3.55x3.765794"
NORM_T2="0.1x1.95x3.1x4.5x6.738198"
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --t1) T1="$2" ; shift 2 ;;
    --t2) T2="$2" ; shift 2 ;;
    --label) LABEL="$2" ; shift 2 ;;
    --label-vals) LABEL_VALS="$2" ; shift 2 ;;
    --norm-t1) NORM_T1="$2" ; shift 2 ;;
    --norm-t2) NORM_T2="$2" ; shift 2 ;;
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
  echo '  --t1 <value>             T1-weighted image'
  echo '  --t2 <value>             T2-weighted image'
  echo '  --label <value>          Tissue label image, 1 volume 3 labels'
  echo '  --label-vals <value>     x-separated list of values indicating value'
  echo '                           of CSF, GM, and WM ROIs, default="1x2x3"'
  echo '  --norm-t1 <value>        set of values to use to normalize T1w images,'
  echo '                           values correspond to:'
  echo '                            -mode of background voxels'
  echo '                            -mode of CSF voxels'
  echo '                            -mode of GM voxels'
  echo '                            -mode of WM voxels'
  echo '                            -98% quantile of all voxels'
  echo '                           default="0.1x1.45x2.45x3.55x3.765794"'
  echo '  --norm-t2 <value>        set of values to use to normalize T2w images,'
  echo '                           values correspond to:'
  echo '                            -mode of background voxels'
  echo '                            -mode of WM voxels'
  echo '                            -mode of GM voxels'
  echo '                            -mode of CSF voxels'
  echo '                            -98% quantile of CSF voxels'
  echo '                           default="0.1x1.95x3.1x4.5x6.738198"'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${DIR_PROJECT}/derivatives/inc/anat/myelin_${SPACE}'
  echo '                           Space will be drawn from folder name,'
  echo '                           e.g., native = native'
  echo '                                 reg_${TEMPLATE}+${SPACE}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================
# Set up BIDs compliant variables and workspace -------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${T1})
PID=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f ses)
if [[ -z "${PREFIX}" ]]; then
  PREFIX="sub-${PID}"
  if [[ -n ${SID} ]]; then
    PREFIX="${PREFIX}_ses-${SID}"
  fi
fi

SPACE_LAB=$(${DIR_INC}/bids/get_space.sh -i ${T1})
if [[ -z ${SPACE_LAB} ]]; then
  SPACE_LAB="map"
fi

# Copy images to scratch, for manipulation
mkdir -p ${DIR_SCRATCH}
cp ${T1} ${DIR_SCRATCH}/t1.nii.gz
cp ${T2} ${DIR_SCRATCH}/t2.nii.gz
cp ${LABEL} ${DIR_SCRATCH}/label.nii.gz
gunzip ${DIR_SCRATCH}/*.gz

# create save directory
if [[ -z "${DIR_SAVE}" ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/myelin_${SPACE_LAB}
fi
mkdir -p ${DIR_SAVE}

# calculate myelin map
Rscript ${DIR_INC}/anat/mapMyelin.R \
  "t1" ${DIR_SCRATCH}/t1.nii "t2" ${DIR_SCRATCH}/t2.nii \
  "label" ${DIR_SCRATCH}/label.nii "label-values" ${LABEL_VALS} \
  "t1.norms" ${NORM_T1} "t2.norms" ${NORM_T2}

# zip and move output
gzip ${DIR_SCRATCH}/myelin.nii
CopyImageHeaderInformation ${T1} \
  ${DIR_SCRATCH}/myelin.nii.gz \
  ${DIR_SCRATCH}/${PREFIX}_myelin.nii.gz \
  1 1 1
mv ${DIR_SCRATCH}/${PREFIX}_myelin.nii.gz ${DIR_SAVE}

#==============================================================================
# End of function
#==============================================================================
exit 0

