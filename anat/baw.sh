#!/bin/bash -e

#===============================================================================
# Function Description
# Authors: Josh Cochran
# Date: 10/19/20
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false
umask 007

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
OPTS=$(getopt -o ha --long \
project-name:,t1:,t2:,\
dir-save:,queue:,r-flag:,\
help,all -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PROJECT_NAME=
T1=
T2=
R_FLAG=SGEGraph
QUEUE=UI,CCOM
DIR_SAVE=
HELP=false
ALL=false
DIR_INC=/Shared/inc_scratch/code

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -a | --all) ALL=true ; shift ;;
    --project-name) PROJECT_NAME="$2" ; shift 2 ;;
    --t1) T1="$2" ; shift 2 ;;
    --t2) T2="$2" ; shift 2 ;;
    --queue) QUEUE="$2" ; shift 2 ;;
    --r-flag) R_FLAG="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done


# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FCN_NAME=($(basename "$0"))
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -a | --all               run for all subjects in csv'
  echo '  --project-name <value>   Name of project'
  echo '  --t1 <value>             T1w images, can take multiple comma seperated images'
  echo '  --t2 <value>             T2w images, can take multiple comma seperated images'
  echo '  --queue <value>          HPC queues to submit jobs to, default: PINC,CCOM'
  echo '  --r-flag <value>         Changes r flag for running BAW, default: SGEGraph'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${T1})
SUBJECT=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f "sub")
SESSION=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f "ses")
if [ -z "${PREFIX}" ]; then
  PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${T1})
fi

CSV=${DIR_PROJECT}/code/baw.csv
CONFIGFILE=${DIR_PROJECT}/code/${PROJECT_NAME}.config

if [[ ! -f "${CONFIGFILE}" ]]; then
  ${DIR_INC}/anat/baw_config.sh \
    --project-name ${PROJECT_NAME} \
    --csv-file ${CSV} \
    --dir-save ${DIR_PROJECT}/derivatives/baw \
    --queue ${QUEUE}
fi

T1=(${T1//,/ })
T2=(${T2//,/ })
N_T1=${#T1[@]}
N_T2=${#T2[@]}

unset IMAGES
for (( i=0; i<${N_T1}; i++ )); do
  IMAGES+=(\'T1-30\':[\'${T1[${i}]}\']) 
done

for (( i=0; i<${N_T2}; i++ )); do
  IMAGES+=(\'T2-30\':[\'${T2[${i}]}\'])
done

IMAGES=$(IFS=, ; echo "${IMAGES[*]}")


echo '"'${PROJECT_NAME}'","sub-'${SUBJECT}'","ses-'${SESSION}'","{'${IMAGES}'}"' >> ${CSV}

#sort -u ${CSV} -o ${CSV}
if [[ "${ALL}" == "true" ]]; then
  SESID=all
else
  SESID=ses-${SESSION}
fi

export PATH=/Shared/pinc/sharedopt/apps/anaconda3/Linux/x86_64/4.3.0/bin:$PATH
bash ${DIR_INC}/anat/runbaw.sh -p 1 -s ${SESID} -r ${R_FLAG} -c ${CONFIGFILE}


#===============================================================================
# End of Function
#===============================================================================

exit 0

