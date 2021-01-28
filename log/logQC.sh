#!/bin/bash

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o o:h:k:q:s:f:t:e:c \
--long operator:,fcn-name:,proc-start:,proc-end:,exit-code: \
-n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

OPERATOR=
SCAN_DATE=
FCN_NAME=
PROC_START=
PROC_END=
EXIT_CODE=
NOTES=

while true; do
  case "$1" in
    -o | --operator) OPERATOR="$2" ; shift 2 ;;
    -d | --scan-date) SCAN_DATE="$2" ; shift 2 ;;
    -f | --fcn-name) FCN_NAME="$2" ; shift 2 ;;
    -t | --proc-start) PROC_START="$2" ; shift 2 ;;
    -e | --proc-end) PROC_END="$2" ; shift 2 ;;
    -c | --exit-code) EXIT_CODE="$2" ; shift 2 ;;
    -n | --notes) NOTES="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

LOG_STRING=$(date +"${OPERATOR}\t${SCAN_DATE}\t${FCN_NAME}\t${PROC_START}\t${PROC_END}\t${EXIT_CODE}\t${NOTES}")
FCN_LOG=${DIR_LOG}/qc/${FCN_NAME}_$(date +FY%Y)Q$((($(date +%-m)-1)/3+1)).log
if [[ ! -f ${FCN_LOG} ]]; then
  echo -e 'operator\tscan_date\tfunction\tstart\tend\texit_status\tnotes' > ${FCN_LOG}
fi
echo -e ${LOG_STRING} >> ${FCN_LOG}
exit 0

