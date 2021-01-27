#!/bin/bash -e
#===============================================================================
# Autodownload files from xnat
# Authors: Timothy R. Koscik
# Date: 2021-01-27
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(unname -s)"
HARDWARE="$(uname -m)"
if [[ "${HARDWARE,,}" == "argon" ]]; then
  HPC_Q=${QUEUE}
  HPC_SLOTS=${NSLOTS}
else
  HPC_Q="LOCAL"
  HPC_SLOTS="NA"
fi
umask 007

# actions on exit, write to logs, clean scratch
operator, hardware, kernel, hpc queue, hpc slots, start time, end time, exit code
function egress {
  EXIT_CODE=$?
  LOG_STRING=$(date +"${OPERATOR}\t${HARDWARE}\t${KERNEL}\t${HPC_Q}\t${HPC_SLOTS}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}")
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark/${FCN_NAME}_$(date +FY%Y)Q$((($(date +%-m)-1)/3+1)).log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\thardware\tkernel\thpc_queue\thpc_slots\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
  fi
}
trap egress EXIT

#===============================================================================
# Start of Function
#===============================================================================
PROJECT_LS=($(${DIR_INC}/bids/get_column.sh -i ${DIR_DB}/projects.tsv -f xnat_project))
N=${#PROJECT[@]}
for (( i=0; i<${N}; i++ )); do
  ${DIR_INC}/dicom/dicomDownload.sh --xnat-project ${PROJECT_LS[${i}]}
done

${DIR_INC}/cron/dicomAutoconvert.sh
