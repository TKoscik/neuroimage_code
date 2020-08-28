#!/bin/bash -e

#===============================================================================
# Functional Timeseries -  Nuisance Regression
# Authors: Timothy R. Koscik
# Date: 2020-03-27
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvkl --long group:,prefix:,template:,space:,\
ts-bold:,mask-brain:,pass-lo:,pass-hi:,regressor:,is_ses:,\
dir-save:,dir-scratch:,dir-code:,dir-pincsource:,\
keep,help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
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

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
TS_BOLD=
MASK_BRAIN=
PASS_LO=99999
PASS_HI=0
REGRESSOR=
TEMPLATE=HCPICBM
SPACE=2mm
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
KEEP=false
VERBOSE=0
HELP=false
IS_SES=true

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --ts-bold) TS_BOLD="$2" ; shift 2 ;;
    --mask-brain) MASK_BRAIN="$2" ; shift 2 ;;
    --pass-lo) PASS_LO="$2" ; shift 2 ;;
    --pass-hi) PASS_HI="$2" ; shift 2 ;;
    --regressor) REGRESSOR="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --is_ses) IS_SES="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
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
  echo 'Author: Timothy R. Koscik, PhD'
  echo 'Date:   2020-03-07'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -c | --dry-run           test run of function'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --ts-bold <value>        full path to single, run timeseries'
  echo '  --mask-brain <value>     full path to brain mask'
  echo '  --pass-lo <value>        upper passband limit, default=99999'
  echo '  --pass-hi <value>        lower passband limit, default=0'
  echo '  --regressor <value>      comma separated list of regressors to use'
  echo '  --template <value>       name of template to use, default=HCPICBM'
  echo '  --space <value>          spacing of template to use, default=2mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
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
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${TS_BOLD}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "ses"`
TASK=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "task"`
RUN=`${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "run"`
if [ -z "${PREFIX}" ]; then
  PREFIX=`${DIR_CODE}/bids/get_bidsbase -s -i ${IMAGE}`
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/func/resid_${TEMPLATE}+${SPACE}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

##--------------- resample mask to fit input grid bc its off by like 1mm ---------------##
if [ -z "${MASK_BRAIN}" ]; then
  echo "No mask is provided."
else
  if [ -f "${DIR_PROJECT}/derivatives/func/mask/${maskBase}_resampled.nii.gz" ]; then
    rm ${DIR_PROJECT}/derivatives/func/mask/${maskBase}_resampled.nii.gz
  fi
  mask_resampling=${MASK_BRAIN}
  maskBase=`basename ${mask_resampling} | awk -F"." '{print $1}'`
  AFNI="3dresample -master ${TS_BOLD}"
  AFNI="${AFNI} -prefix ${DIR_PROJECT}/derivatives/func/mask/${maskBase}_resampled.nii.gz"
  AFNI="${AFNI} -input ${mask_resampling}"
  eval ${AFNI}
  MASK_BRAIN=${DIR_PROJECT}/derivatives/func/mask/${maskBase}_resampled.nii.gz
fi

#==============================================================================
# partial out nuisance variance
#==============================================================================
TR=`PrintHeader ${TS_BOLD} | grep "Voxel Spac" | cut -d ',' -f 4 | cut -d ']' -f 1`
REGRESSOR=(${REGRESSOR//,/ })
N_REG=${#REGRESSOR[@]}

AFNI_CALL="3dTproject -input ${TS_BOLD}"
AFNI_CALL="${AFNI_CALL} -prefix ${DIR_SCRATCH}/resid.nii.gz"
AFNI_CALL="${AFNI_CALL} -mask ${MASK_BRAIN}"
AFNI_CALL="${AFNI_CALL} -bandpass ${PASS_HI} ${PASS_LO}"
for (( i=0; i<${N_REG}; i++ )); do
  AFNI_CALL="${AFNI_CALL} -ort ${REGRESSOR[${i}]}"
done
AFNI_CALL="${AFNI_CALL} -TR ${TR}"

eval ${AFNI_CALL}

mv ${DIR_SCRATCH}/resid.nii.gz ${DIR_SAVE}/${PREFIX}_bold.nii.gz

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

exit 0
