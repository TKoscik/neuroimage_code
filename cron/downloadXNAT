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
KERNEL="$(uname -s)"
HARDWARE="$(uname -m)"
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
umask 007

# actions on exit --------------------------------------------------------------
## capture time, exit code, write to benchmark log
function egress {
  EXIT_CODE=$?
  PROC_STOP=$(date +%Y-%m-%dT%H:%M:%S%z)
  logBenchmark --operator ${OPERATOR} \
  --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
  --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
}
trap egress EXIT

#===============================================================================
# Start of Function
#===============================================================================
PROJECT_LS=($(getColumn -i ${DIR_DB}/projects.tsv -f xnat_project))
N=${#PROJECT[@]}
for (( i=0; i<${N}; i++ )); do
  dicomDownload --xnat-project ${PROJECT_LS[${i}]}
done

#===============================================================================
# End of Function
#===============================================================================
exit 0

