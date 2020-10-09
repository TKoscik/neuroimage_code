#!/bin/bash -e

#===============================================================================
# Build a neuroanatomical template using iterative registration to a group
# average.
#  -can be built on a subset of participants with an appropriate *.tsv file
#  -input list can specify projects and/or file paths as well, header row will 
#   be used looking for keywords (capitalization doesn't matter):
#       -participant_id         mandatory
#       -session_id             mandatory 
#       -project                optional project directory, if used it will look
#                               for the ${DIR_PROJECT}/derivatives/anat/native
#                               folder. If not included, will default to the
#                               project associated with the input list, or to
#                               the project specified by the dir-project input
#       -directory              optional
# Authors: Timothy R. Koscik, PhD
# Date: 2020-09-03
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false

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
OPTS=`getopt -o hvkl --long prefix:,\
id-ls:,mod-ls:,dir-project:,mask-name:,mask-dil:,iterations:,resolution:,template:,space:,template-name:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
ID_LS=
MOD_LS=T1w,T2w
DIR_PROJECT=NULL
MASK_NAME=brain+ANTs
MASK_DIL=2
ITERATIONS=0x1x3x2
RESOLUTION=1x1x1
TEMPLATE=HCPICBM
SPACE=1mm
TEMPLATE_NAME=NULL
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --id-ls) ID_LS="$2" ; shift 2 ;;
    --mod-ls) MOD_LS="$2" ; shift 2 ;;
    --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    --mask-name) MASK_NAME="$2" ; shift 2 ;;
    --mask-dil) MASK_DIL="$2" ; shift 2 ;;
    --iterations) ITERATIONS="$2" ; shift 2 ;;
    --resolution) RESOLUTION="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --template-name) TEMPLATE_NAME="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done
### NOTE: DIR_CODE, DIR_PINCSOURCE may be deprecated and possibly replaced
#         by DIR_INC for version 0.0.0.0. Specifying the directory may
#         not be necessary, once things are sourced

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FCN_NAME=($(basename "$0"))
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
  echo '  --other-inputs <value>   other inputs necessary for function'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
mkdir -p ${DIR_SCRATCH}/coreg
mkdir -p ${DIR_SCRATCH}/xfm
mkdir -p ${DIR_SCRATCH}/job

SUBJECT=($(${DIR_CODE}/bids/get_column.sh -i ${ID_LS} -f pariticipant_id))
SESSION=($(${DIR_CODE}/bids/get_column.sh -i ${ID_LS} -f session_id))
PROJECT=($(${DIR_CODE}/bids/get_column.sh -i ${ID_LS} -f project))
DIRECTORY=($(${DIR_CODE}/bids/get_column.sh -i ${ID_LS} -f directory))
## probably need to adjust this to add masks

N_SUB=${#SUBJECT[@]}

MOD_LS=(${MOD_LS//,/ })
N_MOD=${#MOD_LS[@]}

if [[ "${DIRECTORY}" == "NULL" ]]; then
  if [[ "${PROJECT}" == "NULL" ]]; then
    if [[ "${DIR_PROJECT}" == "NULL" ]]; then
        for (( i=1; i<${N_SUB}; i++ )); do
          SUB_PREFIX=sub-${SUBJECT[${i}]}
          if [ -n "${SESSION}" ]; then
            SUB_PREFIX=${SUB_PREFIX}_ses-${SESSION[${i}]}
          fi
          for (( j=1; j<${N_MOD}; j++ )); do
            TEMP+=($(ls ${DIR_PROJECT}/derivatives/anat/native/${SUB_PREFIX}*${MOD_LS[${j}]}))
          done
          FLS+=$(IFS=, ; echo "${TEMP[*]}")
        done
    fi
  else
    for (( i=1; i<${N_SUB}; i++ )); do
      SUB_PREFIX=sub-${SUBJECT[${i}]}
      if [ -n "${SESSION}" ]; then
        SUB_PREFIX=${SUB_PREFIX}_ses-${SESSION[${i}]}
      fi
      for (( j=1; j<${N_MOD}; j++ )); do
        TEMP+=($(ls ${PROJECT[${i}]}/derivatives/anat/native/sub-${SUBJECT[${i}]}_sub-${SESSION[${i}]}*${MOD_LS[${j}]}))
      done
      FLS+=$(IFS=, ; echo "${TEMP[*]}")
    done
  fi
else
  for (( i=1; i<${N_SUB}; i++ )); do
    SUB_PREFIX=sub-${SUBJECT[${i}]}
    if [ -n "${SESSION}" ]; then
      SUB_PREFIX=${SUB_PREFIX}_ses-${SESSION[${i}]}
    fi
    for (( j=1; j<${N_MOD}; j++ )); do
      TEMP+=($(ls ${DIRECTORY}/sub-${SUBJECT[${i}]}_sub-${SESSION[${i}]}*${MOD_LS[${j}]}))
    done
    FLS+=$(IFS=, ; echo "${TEMP[*]}")
  done
fi

# Do rigid if necessary to put in same space
ITERATIONS=(${ITERATIONS//x/ })
for k in {0..4}; do
  for (( j=0; j<${ITERATIONS[${k}]}; j++ ))
    for (( i=1; i<${N_SUB}; i++ )); do
      SUB_PREFIX=sub-${SUBJECT[${i}]}
      if [ -n "${SESSION}" ]; then
        SUB_PREFIX=${SUB_PREFIX}_ses-${SESSION[${i}]}
      fi
      unset HOLD_LS
      JOB=${DIR_SCRATCH}/job/${SUB_PREFIX}_reg-${k}-${j}.job
      SH=${DIR_SCRATCH}/job/${SUB_PREFIX}_reg-${k}-${j}.sh

      echo '#!/bin/bash -e' > ${JOB}
      echo '#$ -q '${HPC_Q} >> ${JOB}
      echo '#$ -pe '${HPC_PE} >> ${JOB}
      echo '#$ -ckpt user' >> ${JOB}
      echo '#$ -j y' >> ${JOB}
      echo '#$ -o '${HPC_O} >> ${JOB}
      echo '' >> ${JOB}
      echo 'CHILD='${SH} >> ${JOB}
      echo 'sg - Research-INC_img_core "chmod g+rwx ${CHILD}"' >> ${JOB}
      echo 'sg - Research-INC_img_core "bash ${CHILD}"' >> ${JOB}
      echo '' >> ${JOB}
      echo '' >> ${JOB}

      echo '' > ${SH}
      echo 'source /Shared/pinc/sharedopt/apps/sourcefiles/ants_source.sh' >> ${SH}
      echo '' >> ${SH}
      echo ${DIR_CODE}'/anat/coregistration.sh \' >> ${SH}
    done
  fi
fi
