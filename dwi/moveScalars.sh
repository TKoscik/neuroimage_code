#!/bin/bash -e
#===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
# NOTES rewrite to specify save dierctory or default to: derivatives/inc
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(unname -s)"
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
    ${DIR_INC}/log/logBenchmark.sh \
      -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
      -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
    ${DIR_INC}/log/logProject.sh \
      -d ${DIR_PROJECT} -p ${PID} -n ${SID} \
      -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
      -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
    ${DIR_INC}/log/logSession.sh \
      -d ${DIR_PROJECT} -p ${PID} -n ${SID} \
      -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
      -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hl --long prefix:,\
dir-dwi:,dir-project:,dir-save:,\
help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
DIR_DWI=
DIR_PROJECT=
DIR_SAVE=
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dir-dwi <value>        directory to save output, default varies by function'
  echo '  --dir-project <value>    directory for temporary workspace'
  echo '  --dir-save <value>       directory to save data to'
  echo '                           default=DIR_PROJECT/derivatives/inc'
  echo '                           will make xfm and dwi (and more) subdirectories'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
anyfile=$(ls ${DIR_DWI}/sub-*.nii.gz)
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${anyfile[0]})
PID=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${anyfile[0]} -f ses)
if [[ -z "${PREFIX}" ]]; then
  PREFIX="sub-${PID}"
  if [[ -n ${SID} ]]; then
    PREFIX="${PREFIX}_ses-${SID}"
  fi
fi
DIR_SUBSES="sub-${PID}"
if [[ -n ${SID} ]]; then
  DIR_SUBSES="ses-${SID}"
fi
if [[ -z ${DIR_SAVE} ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc
fi

mkdir -p ${DIR_SAVE}/dwi/B0+mean
mv ${DIR_DWI}/${PREFIX}_B0+mean.nii.gz ${DIR_SAVE}/dwi/B0+mean/

mkdir -p ${DIR_SAVE}/dwi/mask
mv ${DIR_DWI}/${PREFIX}_mod-B0_mask-brain.nii.gz ${DIR_SAVE}/dwi/mask

mkdir -p ${DIR_SAVE}/xfm/${DIR_SUBSES}
mv ${DIR_DWI}/*xfm* ${DIR_SAVE}/xfm/${DIR_SUBSES}

mkdir -p ${DIR_SAVE}/dwi/corrected_raw
mv ${DIR_DWI}/${PREFIX}_dwi+corrected.nii.gz ${DIR_SAVE}/dwi/corrected_raw/${PREFIX}_dwi.nii.gz

mkdir -p ${DIR_SAVE}/dwi/bvec+bval
mv ${DIR_DWI}/${PREFIX}.bvec ${DIR_SAVE}/dwi/bvec+bval
mv ${DIR_DWI}/${PREFIX}.bval ${DIR_SAVE}/dwi/bvec+bval

corrected_list=(`ls ${DIR_DWI}/${PREFIX}_reg*`)
for (( i=0; i<${#corrected_list[@]}; i++ )); do
  SPACE=$(${DIR_CODE}/bids/get_space.sh -i ${corrected_list[${i}]})
  mkdir -p ${DIR_SAVE}/dwi/corrected_${SPACE}
  mv ${corrected_list[${i}]} ${DIR_SAVE}/dwi/corrected_${SPACE}/
done

rsync -r ${DIR_DWI}/scalar* ${DIR_SAVE}/dwi/

rsync -r ${DIR_DWI}/tensor* ${DIR_SAVE}/dwi/

if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_SAVE}/dwi/prep/${DIR_SUBSES}
  mv ${DIR_DWI}/* ${DIR_SAVE}/dwi/prep/${DIR_SUBSES}/
else
  if [[ "$(ls -A ${DIR_DWI})" ]]; then
    rm -R ${DIR_DWI}/*
  fi
  rmdir ${DIR_DWI}
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0

