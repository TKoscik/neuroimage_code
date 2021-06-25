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
    -p | --project) PROJECT=true ; shift ;;
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
  exit 0
fi

# ------------------------------------------------------------------------------
# Start of function
# ------------------------------------------------------------------------------
# replace commas with tabs
STRING=${STRING//,/\t}

if [[ "${BENCHMARK}" == "true" ]]; then
  FCN_LOG=${INC_LOG}/benchmark_$(date +FY%Y)Q$((($(date +%-m)-1)/3+1)).log
  if [[ ! -f ${FCN_LOG} ]]; then
    echo -e 'operator\tdir_project\tparticipant_id\tsession_id\thardware\tkernel\thpc_queue\thpc_slots\tfcn-name\tproc-start\tproc-stop\texit-code' > ${FCN_LOG}
  fi
  echo -e ${STRING[@]} >> ${FCN_LOG}

  PSTR=($(echo -e ${STRING[@]}))
  DIR_PROJECT=${PSTR[1]}
  if [[ -d ${DIR_PROJECT} ]]; then
    DIR_LOG==${DIR_PROJECT}/log
    mkdir -p ${DIR_LOG}
    PROJ_LOG=${DIR_LOG}/inc_processing.log
    if [[ ! -f ${PROJ_LOG} ]]; then
      echo -e 'operator\tdir_project\tparticipant_id\tsession_id\thardware\tkernel\thpc_queue\thpc_slots\tfcn-name\tproc-start\tproc-stop\texit-code' > ${PROJ_LOG}
    fi
    echo -e ${STRING[@]} >> ${PROJ_LOG}
  fi
fi

if [[ "${QC}" == "true" ]]; then
  QC_LOG=${INC_LOG}/qc_$(date +FY%Y)Q$((($(date +%-m)-1)/3+1)).log
  if [[ ! -f ${QC_LOG} ]]; then
    echo -e 'pi\tdir_project\tfile_dir\tfile_name\taction\tstatus\tqc\tcomment\toperator\tproc_start\tproc_end' > ${QC_LOG}
  fi
  echo -e ${STRING[@]} >> ${QC_LOG}

  PSTR=($(echo -e ${STRING[@]}))
  DIR_PROJECT=${PSTR[1]}
  if [[ -d ${DIR_PROJECT} ]]; then
    DIR_LOG==${DIR_PROJECT}/log
    mkdir -p ${DIR_LOG}
    PROJ_QC_LOG=${DIR_LOG}/inc_qc.log
    if [[ ! -f ${PROJ_QC_LOG} ]]; then
      echo -e 'operator\tdir_project\tparticipant_id\tsession_id\thardware\tkernel\thpc_queue\thpc_slots\tfcn-name\tproc-start\tproc-stop\texit-code' > ${PROJ_QC_LOG}
    fi
    echo -e ${STRING[@]} >> ${PROJ_QC_LOG}
  fi
fi

if [[ -n ${FNAME} ]]; then
  echo -e ${STRING[@]} >> ${FNAME}
fi

exit 0


