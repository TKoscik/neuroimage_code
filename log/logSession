#!/bin/bash

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt --long dir-project:,operator:,pid:,sid:, \
hardware:,kernel:,hpc-q:,hpc-slots:, \
fcn-name:,proc-start:,proc-end:,exit-code: \
-n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

OPERATOR=
DIR_PROJECT=
PID=
SID=
HARDWARE=
KERNEL=
HPC_Q=
HPC_SLOTS=
FCN_NAME=
PROC_START=
PROC_STOP=
EXIT_CODE=

while true; do
  case "$1" in
    -o | --operator) OPERATOR="$2" ; shift 2 ;;
    -d | --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    -p | --sid) PID="$2" ; shift 2 ;;
    -n | --pid) SID="$2" ; shift 2 ;;
    -h | --hardware) HARDWARE="$2" ; shift 2 ;;
    -k | --kernel) KERNEL="$2" ; shift 2 ;;
    -q | --hpc-q) HPC_Q="$2" ; shift 2 ;;
    -s | --hpc-slots) HPC_SLOTS="$2" ; shift 2 ;;
    -f | --fcn-name) FCN_NAME="$2" ; shift 2 ;;
    -t | --proc-start) PROC_START="$2" ; shift 2 ;;
    -e | --proc-end) PROC_END="$2" ; shift 2 ;;
    -c | --exit-code) EXIT_CODE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

LOG_STRING=$(date +"${OPERATOR}\t${PID}\t${SID}\t${HARDWARE}\t${KERNEL}\t${HPC_Q}\t${HPC_SLOTS}\t${FCN_NAME}\t${PROC_START}\t${PROC_END}\t${EXIT_CODE}")
if [[ ! -d "${DIR_PROJECT}/log" ]]; then
  mkdir -p ${DIR_PROJECT}/log
fi
FCN_LOG=${DIR_PROJECT}/log/sub-${PID}_ses-${SID}.log
if [[ ! -f ${FCN_LOG} ]]; then
  echo -e 'operator\tparticipant_id\tsession_id\thardware\tkernel\thpc_queue\thpc_slots\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
fi
echo -e ${LOG_STRING} >> ${FCN_LOG}
exit 0


