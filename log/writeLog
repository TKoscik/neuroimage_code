#!/bin/bash

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hbqs: --long benchmark,qc,string:,filename: -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

BENCHMARK="false"
QC="false"
STRING=
FNAME=

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -b | --benchmark) BENCHMARK=true ; shift ;;
    -q | --qc) QC=true ; shift ;;
    -s | --string) STRING="$2" ; shift 2 ;;
    --filename) FNAME="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo '  -h | --help           display command help'
  echo '  -b | --benchmark      write benchmarking logs (main, project, subject)'
  echo '  -q | --qc             write QC logs (main, project)'
  echo '  -s | --string         log string, comma-delimited'
  echo '     benchmark items: operator, dir_project, participant_id,'
  echo '                      session_id, hardware, kernel, hpc_queue'
  echo '                      hpc_slots, fcn-name, proc-start, proc-stop,'
  echo '                      exit-code'
  echo '     qc items:        pi, dir_project, file_dir, file_name, action'
  echo '                      status, qc, comment, operator, proc_start proc_end'
  echo '  --filename          additional filename to write log to'
  echo ''
  exit 0
fi

# ------------------------------------------------------------------------------
# Start of function
# ------------------------------------------------------------------------------
# replace commas with tabs
STRING=${STRING//,/\t}
PSTR=($(echo -e ${STRING[@]}))
DIR_PROJECT=${PSTR[1]}
PID=${PSTR[2]}
SID=${PSTR[3]}

BM_HDR='operator\tdir_project\tparticipant_id\tsession_id\thardware\tkernel\thpc_queue\thpc_slots\tfcn-name\tproc-start\tproc-stop\texit-code'
QC_HDR='pi\tdir_project\tfile_dir\tfile_name\taction\tstatus\tqc\tcomment\toperator\tproc_start\tproc_end'

# Benchmark Logging ------------------------------------------------------------
if [[ "${BENCHMARK}" == "true" ]]; then
  FCN_LOG=${INC_LOG}/benchmark_$(date +FY%Y)Q$((($(date +%-m)-1)/3+1)).log
  if [[ ! -f ${FCN_LOG} ]]; then
    echo -e ${BM_HDR} > ${FCN_LOG}
  fi
  echo -e ${STRING[@]} >> ${FCN_LOG}

  if [[ -d ${DIR_PROJECT} ]]; then
    mkdir -p ${DIR_PROJECT}/log
    if [[ ! -f ${PROJ_LOG} ]]; then
      echo -e ${BM_HDR} > ${DIR_PROJECT}/log/inc_processing.log
    fi
    if [[ ! -f ${PID_LOG} ]]; then
      echo -e ${BM_HDR} > ${DIR_PROJECT}/log/sub-${PID}_ses-${PID}_processing.log
    fi
    echo -e ${STRING[@]} >> ${DIR_PROJECT}/log/inc_processing.log
    echo -e ${STRING[@]} >> ${DIR_PROJECT}/log/sub-${PID}_ses-${PID}_processing.log
  fi
fi

# QC Logging -------------------------------------------------------------------
if [[ "${QC}" == "true" ]]; then
  QC_LOG=${INC_LOG}/qc_$(date +FY%Y)Q$((($(date +%-m)-1)/3+1)).log
  
  if [[ ! -f ${QC_LOG} ]]; then
    echo -e ${QC_HDR} > ${QC_LOG}
  fi
  echo -e ${STRING[@]} >> ${QC_LOG}

  PSTR=($(echo -e ${STRING[@]}))
  DIR_PROJECT=${PSTR[1]}
  if [[ -d ${DIR_PROJECT} ]]; then
    mkdir -p ${DIR_PROJECT}/log
    if [[ ! -f ${DIR_PROJECT}/log/inc_qc.log ]]; then
      echo -e ${QC_HDR} > ${DIR_PROJECT}/log/inc_qc.log
    fi
    echo -e ${STRING[@]} >> ${PROJ_QC_LOG}
  fi
fi

# write log to specified file --------------------------------------------------
if [[ -n ${FNAME} ]]; then
  if [[ ! -f ${FNAME} ]]; then
    if [[ "${PSTR[0]}" == "operator" ]]; then
      echo -e ${BM_STR} > ${FNAME}
    else
      echo -e ${QC_STR} > ${FNAME}
    fi
  fi
  echo -e ${STRING[@]} >> ${FNAME}
fi

# ------------------------------------------------------------------------------
# End of function
# ------------------------------------------------------------------------------
exit 0

