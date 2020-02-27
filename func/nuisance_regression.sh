#!/bin/bash -e

OPTS=`getopt -ovk --long researcher:,project:,group:,subject:,session:,prefix:,template:,space:,ts-bold:,mask-brain:,pass-lo:,pass-hi:,regressor:,dir-scratch:,dir-nimgcore:,dir-pincsource:,keep,help,verbose -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S)
RESEARCHER=
PROJECT=
GROUP=
SUBJECT=
SESSION=
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
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --mask-brain) MASK_BRAIN="$2" ; shift 2 ;;
    --pass-lo) PASS_LO="$2" ; shift 2 ;;
    --pass-hi) PASS_HI="$2" ; shift 2 ;;
    --regressor) REGRESSOR+="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

#==============================================================================
# partial out nuisance variance
#==============================================================================
mkdir -p ${DIR_SCRATCH}
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

mkdir -p ${RESEARCHER}/${PROJECT}/derivatives/func/resid_${TEMPLATE}_${SPACE}
mv ${DIR_SCRATCH}/resid.nii.gz \
  ${RESEARCHER}/${PROJECT}/derivatives/func/resid_${TEMPLATE}_${SPACE}/${PREFIX}_bold.nii.gz

rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

