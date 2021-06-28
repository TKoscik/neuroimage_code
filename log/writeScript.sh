#!/bin/bash

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hd:p:n:s: --long dir-project:,pid:,sid:,string:,filename: -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DIR_PROJECT=
PID=
SID=
STRING=
FNAME=

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -d | --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    -p | --pid) PID="$2" ; shift 2 ;;
    -n | --sid) SID="$2" ; shift 2 ;;
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
  echo '  -d | --dir-project    directory listing for project'
  echo '  -p | --pid            participant identifier (no "sub-")'
  echo '  -n | --sid            session identifier (no "ses-"'
  echo '  -s | --string         string of function call'
  echo '  --filename            non-default filename to write to'
  echo ''
  exit 0
fi

# ------------------------------------------------------------------------------
# Start of function
# ------------------------------------------------------------------------------
if [[ -d ${DIR_PROJECT} ]]; then
  PIDSTR=sub-${PID}
  if [[ -n ${SID} ]]; then PIDSTR="${PIDSTR}_ses-${SID}"; fi
  date +%Y-%m-%dT%H:%M:%S%z >> ${DIR_PROJECT}/log/${PIDSTR}_script.log
  echo "${STRING}" >> ${DIR_PROJECT}/log/${PIDSTR}_script.log
fi

if [[ -n ${FNAME} ]]; then
  date +%Y-%m-%dT%H:%M:%S%z >> ${DIR_PROJECT}/log/${PIDSTR}_script.log
  echo "${STRING}" >> ${DIR_PROJECT}/log/${PIDSTR}_script.log
fi

# ------------------------------------------------------------------------------
# End of function
# ------------------------------------------------------------------------------
exit 0

