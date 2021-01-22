#!/bin/bash -x


#===============================================================================
# Quality Control for Automatic DICOM download & converstion to NIFTI
#-------------------------------------------------------------------------------
# by Lauren Hopkins (lauren-hopkins@uiowa.edu)

PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KEEP=false
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${KEEP}" = false ]]; then
    if [[ -n "${DIR_SCRATCH}" ]]; then
      if [[ -d "${DIR_SCRATCH}" ]]; then
        if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
          rm -R ${DIR_SCRATCH}
        else
          rmdir ${DIR_SCRATCH}
        fi
      fi
    fi
  fi
  LOG_STRING=$(date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}")
  if [[ "${NO_LOG}" = false ]]; then
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

##############  QUESTIONS #############
# 1) Are we gonna need inputs for this?
#   A) Yes
# 2) Are we gonna need a `help` section
#   A) Yes
#######################################

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvkl --long dir-project:,email:,participant:,session:,\
dicom-home:,dicom-depth:,dont-use:,dir-scratch:,version:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DIR_PROJECT=
EMAIL=lauren-hopkins@uiowa.edu
PARTICIPANT=
SESSION=
DICOM_HOME=
DICOM_DEPTH=5
VERSION=1.0.20200331
ITK_VER=3.8.0-20190612
DONT_USE=loc,cal,orig
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_INC=/Shared/inc_scratch/code
HELP=false
VERBOSE=false
KEEP=false
#DEIDENTIFY=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=true ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    --email) EMAIL="$2" ; shift 2 ;;
    --participant) PARTICIPANT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --dicom-home) DICOM_HOME="$2" ; shift 2 ;;
    --dicom-depth) DICOM_DEPTH="$2" ; shift 2 ;;
    --version) VERSION="$2" ; shift 2 ;;
    --dont-use) DONT_USE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help               display command help'
  echo '  -v | --verbose            add verbose output to log file'
  echo '  -k | --keep               keep intermediates'
  echo '  -l | --no-log             disable writing to output log'
  echo '  --dir-project <value>     directory containing the project, e.g. /Shared/koscikt'
  echo '  --email <values>          comma-delimited list of email addresses'
  echo '  --participant <value>     participant identifier string'
  echo '  --session <value>         session identifier string'
  echo '  --dicom-home <value>       directory listing for unzipped DICOM files'
  echo '  --dicom-depth <value>     depth to search dicom directory, default=5'
  echo '  --version <value>         version of dcm2niix to use, default 1.0.20200331'
  echo '                            Avoid 1.0.20180328 & 1.0.20190903'
  echo '  --dir-scratch <value>     directory for temporary data'
  echo '  --dont-use                comma separated string of files to skip,'
  echo '                            default: loc,cal,orig'
  echo ''
  NO_LOG=true
  exit 0
fi



#==============================================================================
# Start of Function
#==============================================================================
DIR_DCM2NIIX=/Shared/pinc/sharedopt/apps/dcm2niix/Linux/x86_64/${VERSION}
ITKSNAP_DIR=/Shared/pinc/sharedopt/apps/itk-snap/Linux/x86_64/${ITK_VER}/bin

# Determine if input is a zip file or a DICOM directory ------------------------
# 0 for zip file - 1 for DICOM directory ---------------------------------------
if [ -f "${DICOM_HOME}" ]; then 
  FILE_TYPE=0
  echo "${PARTICIPANT} ${SESSION} is "; exit $ERRCODE;
fi



# Set up BIDs compliant variables and workspace --------------------------------
# if [ -f "${TS_BOLD}" ]; then
#   DIR_PROJECT=$(${DIR_CODE}/bids/get_dir.sh -i ${TS_BOLD})
#   SUBJECT=$(${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "sub")
#   SESSION=$(${DIR_CODE}/bids/get_field.sh -i ${TS_BOLD} -f "ses")
#   if [ -z "${PREFIX}" ]; then
#     PREFIX=$(${DIR_CODE}/bids/get_bidsbase.sh -s -i ${TS_BOLD})
#   fi
# else
#   echo "The BOLD file does not exist. Exiting."
#   exit 1
# fi

# Set DIR_SAVE variable
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/qc
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}



## CAN'T TEST ANYTHING BECAUSE MY ITKSNAP IS MESSED UP

  ${ITKSNAP_DIR}/itksnap