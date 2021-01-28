#!/bin/bash

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o d:o:h:k:q:s:f:p:n:t:e:c \
--long dir-project:,operator:,pid:,sid:, \
hardware:,kernel:,hpc-q:,hpc-slots:, \
fcn-name:,proc-start:,proc-end:,exit-code: \
-n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DIR_PROJECT=
OPERATOR=
HARDWARE=
KERNEL=
HPC_Q=
HPC_SLOTS=
FCN_NAME=
PID=
SID=
PROC_START=
PROC_END=
EXIT_CODE=

while true; do
  case "$1" in
    -d | --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    -p | --pid) PID="$2" ; shift 2 ;;
    -n | --sid) SID="$2" ; shift 2 ;;
    -f | --fcn-name) FCN_NAME="$2" ; shift 2 ;;
    -o | --operator) OPERATOR="$2" ; shift 2 ;;
    -h | --hardware) HARDWARE="$2" ; shift 2 ;;
    -k | --kernel) KERNEL="$2" ; shift 2 ;;
    -q | --hpc-q) HPC_Q="$2" ; shift 2 ;;
    -s | --hpc-slots) HPC_SLOTS="$2" ; shift 2 ;;
    -t | --proc-start) PROC_START="$2" ; shift 2 ;;
    -e | --proc-end) PROC_END="$2" ; shift 2 ;;
    -c | --exit-code) EXIT_CODE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# write to log within project
LOG_STRING=$(date +"${PID}\t${SID}\t${FCN_NAME}\t${OPERATOR}\t${HARDWARE}\t${KERNEL}\t${HPC_Q}\t${HPC_SLOTS}\t\t${PROC_START}\t${PROC_END}\t${EXIT_CODE}")
if [[ ! -d "${DIR_PROJECT}/log" ]]; then
  mkdir -p ${DIR_PROJECT}/log
fi
FCN_LOG=${DIR_PROJECT}/log/project.log
if [[ ! -f ${FCN_LOG} ]]; then
  echo -e 'participant_id\tsession_id\tfunction\toperator\thardware\tkernel\thpc_queue\thpc_slots\tstart\tend\texit_status' > ${FCN_LOG}
fi
echo -e ${LOG_STRING} >> ${FCN_LOG}

#write to master log for quarter
PROJECT=${DIR_PROJECT##*/}
if [[ -z ${PROJECT} ]]; then
  TEMP=${DIR_PROJECT::-1}
  PROJECT=${TEMP##*/}
fi
MAIN_LOG=${DIR_LOG}/project/project-${PROJECT}_$(date +FY%Y)Q$((($(date +%-m)-1)/3+1)).log
if [[ ! -f ${FCN_LOG} ]]; then
  echo -e 'dir_project\tparticipant_id\tsession_id\toperator\thardware\tkernel\thpc_queue\thpc_slots\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
fi
echo -e "${DIR_PROJECT}\t${LOG_STRING}" >> ${MAIN_LOG}

exit 0

