#!/bin/bash -e

#===============================================================================
# Functional Timeseries -  Nuisance Regression
# Authors: Timothy R. Koscik
# Date: 2020-03-27
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -hvkl --long group:,prefix:,\
ts-bold:,mask-brain:,pass-lo:,pass-hi:,regressor:,\
dir-scratch:,dir-nimgcore:,dir-pincsource:,\
keep,help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
TEMPLATE=
SPACE=
TS_BOLD=
MASK_BRAIN=
PASS_LO=99999
PASS_HI=0
REGRESSOR=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
KEEP=false
VERBOSE=0
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --mask-brain) MASK_BRAIN="$2" ; shift 2 ;;
    --pass-lo) PASS_LO="$2" ; shift 2 ;;
    --pass-hi) PASS_HI="$2" ; shift 2 ;;
    --regressor) REGRESSOR+="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${TS_BOLD}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "ses"`
TASK=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "task"`
RUN=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${TS_BOLD} -f "run"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_NIMGCORE}/code/bids/get_bidsbase -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  mkdir -p ${DIR_PROJECT}/derivatives/func/resid_${TEMPLATE}+${SPACE}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#==============================================================================
# partial out nuisance variance
#==============================================================================
TR=`PrintHeader ${TS_BOLD} | grep "Voxel Spac" | cut -d ',' -f 4 | cut -d ']' -f 1`

AFNI_CALL="3dTproject -input ${TS_BOLD}"
AFNI_CALL="${AFNI_CALL} -prefix ${DIR_SCRATCH}/resid.nii.gz"
AFNI_CALL="${AFNI_CALL} -mask ${MASK_BRAIN}"
AFNI_CALL="${AFNI_CALL} -bandpass ${PASS_HI} ${PASS_LO}"
N_REG=${#REGRESSOR[@]}
for (( i=0; i<${N_REG}; i++ )); do
  AFNI_CALL="${AFNI_CALL} -ort ${REGRESSOR[${i}]}"
done
AFNI_CALL="${AFNI_CALL} -TR ${TR}"

eval ${AFNI_CALL}

mv ${DIR_SCRATCH}/resid.nii.gz ${DIR_SAVE}/${PREFIX}_bold.nii.gz

rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi
