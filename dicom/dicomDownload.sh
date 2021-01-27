#!/bin/bash -e
#===============================================================================
# DICOM download from XNAT
# Authors: Steve Slevinski, Timothy R. Koscik
# Date: 2021-01-27
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
  LOG_STRING=$(date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}")
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v ${DIR_PROJECT} ]]; then
      PROJECT_LOG=${DIR_PROJECT}/log/${PREFIX}.log
      if [[ ! -f ${PROJECT_LOG} ]]; then
        echo -e 'operator\tfunction\tstart\tend\texit_status' > ${PROJECT_LOG}
      fi
      echo -e ${LOG_STRING} >> ${PROJECT_LOG}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvl --long prefix:,\
xnat-project:,download-date:,pi:,project:,dir-save:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
XNAT_PROJECT=
DOWNLOAD_DATE=
PI=
PROJECT=
DIR_SAVE=${DIR_IMPORT}
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --xnat-project) XNAT_PROJECT="$2" ; shift 2 ;;
    --download-date) DOWNLOAD_DATE="$2" ; shift 2 ;;
    --pi) PI="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
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
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --xnat-project <value>   (required) name of the project on xnat,'
  echo '                           e.g. "TK_BLACK"'
  echo '  --download-date <value>  (required) date range for data download,'
  echo '                           e.g., single date = "YYYY-mm-dd"'
  echo '                                 date range = "YYYY-mm-dd:YYYY-mm-dd"'
  echo '                           default=previous day'
  echo '  --pi <value>             (optional) name of the PI to use in output'
  echo '                           filename, default will us the INC lookup'
  echo '                           table. e.g.,'
  echo '                           pi-${PI}_project-${PROJECT}_YYYYmmddTHHMMSS'
  echo '  --project <value>        (optional) name of the project to use in the'
  echo '                           output filename'
  echo '  --dir-save <value>       (optional) directory to save output,'
  echo '                           default=${DIR_IMPORT}'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
if [[ "${DIR_SAVE}" != "${DIR_IMPORT}" ]]; then mkdir -p ${DIR_SAVE}; fi

# use lookup table, as necessary -----------------------------------------------
if [[ -z ${PI} ]] |
   [[ -z ${PROJECT} ]]; then
  XNAT_LS=($(${DIR_INC}/lut/get_column.sh -i ${DIR_DB}/projects.tsv -f xnat_project))
  for (( i=1; i${#XNAT_LS[@]}; i++ )); do
    if [[ "${XNAT_LS[${i}]" == "${XNAT_PROJECT}" ]]; then
      WHICH_PROJECT=${i}
      break
    fi
  done
  if [[ -z ${PI} ]]; then
    PI_LS=($(${DIR_INC}/lut/get_column.sh -i ${DIR_DB}/projects.tsv -f pi))
    PI="${PI_LS[${WHICH_PROJECT}]}"
  fi
  if [[ -z ${PROJECT} ]]; then
    PROJECT_LS=($(${DIR_INC}/lut/get_column.sh -i ${DIR_DB}/projects.tsv -f project_name))
    PROJECT="${PROJECT_LS[${WHICH_PROJECT}]}"
  fi
fi

# generate date list if range is given -----------------------------------------
if [[ -z ${DOWNLOAD_DATE} ]]; then
  DOWNLOAD_DATE=$(date -d "yesterday 13:00" '+%Y-%m-%d')
fi
DATE_LS=(${DOWNLOAD_DATE//:/ })
if [[ "${#DATE_LS[@]}" == "2" ]]; then
  start_time=$(date -u -d 'TZ="UTC" '${DATE_LS[0]}' 00:00:00' '+%s')   
  end_time=$(date -u -d 'TZ="UTC" '${DATE_LS[1]}' 23:59:59' '+%s')
  interval=86400
  DATE_LS=($(seq ${start_time} ${interval} ${end_time} | xargs -I{} date -u -d 'TZ="UTC" @'{} '+%F'))
fi

# download scans from specified project and date range -------------------------
for (( i=0; i${#DATE_LS[@]}; i++ )); do
  URL="https://rpacs.iibi.uiowa.edu/xnat/data/projects/"${XNAT_PROJECT}"/experiments?format=csv"
  curl -X GET -u ${UP} ${URL} --fail --silent --show-error \
  | awk -F "\"*,\"*" '{ print $2"\t"$7 }' \
  | grep ${DATE_LS[${i}]} \
  | cut -f1 > ${DIR_SAVE}"/"${XNAT_PROJECT}_${DATE_LS[${i}]}".pids"

  while read PID; do
    URL="https://rpacs.iibi.uiowa.edu/xnat/data/experiments/"${PID}"/scans/ALL/files?format=zip"
    curl -X GET -u $UP $URL --fail --silent --show-error > ${DIR_SAVE}"/pi-"${PI}"_project-"${PROJECT}"_sub-"${PID}"_"${DATE_LS[${i}]//-}".zip"
  done < ${DIR_SAVE}"/"${XNAT_PROJECT}_${DATE_LS[${i}]}".pids"
  rm ${DIR_SAVE}"/"${XNAT_PROJECT}_${DATE_LS[${i}]}".pids"
done


#===============================================================================
# End of Function
#===============================================================================
exit 0


