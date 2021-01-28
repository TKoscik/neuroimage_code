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
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
umask 007

# actions on exit --------------------------------------------------------------
## capture time, exit code, write to benchmark log
function egress {
  EXIT_CODE=$?
  PROC_STOP=$(date +%Y-%m-%dT%H:%M:%S%z)
  ${DIR_INC}/log/logBenchmark.sh \
    -o ${OPERATOR} -h ${HARDWARE} -k ${KERNEL} -q ${HPC_Q} -s ${HPC_SLOTS} \
    -f ${FCN_NAME} -t ${PROC_START} -e ${PROC_STOP} -x ${EXIT_CODE}
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

#===============================================================================
# End of Function
#===============================================================================
exit 0

