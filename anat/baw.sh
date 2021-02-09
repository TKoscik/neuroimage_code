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
OPTS=$(getopt -o ha --long \
project-name:,t1:,t2:,\
dir-save:,queue:,runtype:,\
help,all -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PROJECT_NAME=
T1=
T2=
RUNTYPE=SGEGraph
QUEUE=UI,CCOM
DIR_SAVE=
HELP=false
ALL=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -a | --all) ALL=true ; shift ;;
    --project-name) PROJECT_NAME="$2" ; shift 2 ;;
    --t1) T1="$2" ; shift 2 ;;
    --t2) T2="$2" ; shift 2 ;;
    --queue) QUEUE="$2" ; shift 2 ;;
    --runtype) RUNTYPE="$2" ; shift 2 ;;
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
  echo '  --runtype <value>        Changes runtype flag for BAW, default: SGEGraph'
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
PID=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f "sub")
SID=$(${DIR_INC}/bids/get_field.sh -i ${T1} -f "ses")
if [[ -z "${PREFIX}" ]]; then
  PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${T1})
fi
mkdir -p ${DIR_PROJECT}/derivatives/baw
CSV=${DIR_PROJECT}/code/baw.csv
CONFIGFILE=${DIR_PROJECT}/code/${PROJECT_NAME}.config

if [[ ! -f "${CONFIGFILE}" ]]; then
  ${DIR_INC}/anat/bawConfig.sh \
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

echo '"'${PROJECT_NAME}'","sub-'${PID}'","ses-'${SID}'","{'${IMAGES}'}"' >> ${CSV}

#sort -u ${CSV} -o ${CSV}
if [[ "${ALL}" == "true" ]]; then
  SESID=all
else
  SESID=ses-${SID}
fi

export PATH=${DIR_PINC}/anaconda3/Linux/x86_64/4.3.0/bin:$PATH
bash ${DIR_INC}/anat/bawRun.sh -p 1 -s ${SESID} -r ${RUNTYPE} -c ${CONFIGFILE}

#===============================================================================
# End of Function
#===============================================================================
exit 0

