#!/bin/bash -e
#===============================================================================
# Convert DICOM to NIfTI1, designed to work with automatic XNAT downloads
# Authors: Timothy R. Koscik, PhD
# Date: 2021-01-21
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
OPTS=$(getopt -o hvkl --long prefix:,\
other-inputs:,template:,space:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
INPUT_ZIP=
PI=
PROJECT=
PID=
SID=
DCM_VERSION=1.0.20200331
DIR_DCM2NIIX=/Shared/pinc/sharedopt/apps/dcm2niix/Linux/x86_64

DIR_SCRATCH=${DIR_TMP}/dicomConversion_${DATE_SUFFIX}
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --other-inputs) OTHER_INPUTS="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
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
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --other-inputs <value>   other inputs necessary for function'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# if no input given, use import directory for automated conversion
if [[ -z "${INPUT_ZIP}" ]]; then
  INPUT_ZIP=($(ls ${DIR_IMPORT}/*.zip))
fi
N=${#INPUT_ZIP[@]}

mkdir -p ${DIR_SCRATCH}
for (( i=0; i<${N}; i++ )); do
  unset PI PROJECT PID SID
  PI=$(${DIR_INC}/bids/get_field.sh -i ${INPUT_ZIP[${i}]} -f pi)
  PROJECT=$(${DIR_INC}/bids/get_field.sh -i ${INPUT_ZIP[${i}]} -f project)
  SID=$(${DIR_INC}/bids/get_field.sh -i ${INPUT_ZIP[${i}]} -f modality)

  unzip ${INPUT_ZIP[${i}]} -qq -d ${DIR_SCRATCH}
  
  SCAN_DATE="${SID:0:4}-${SID:3:2}-${SID:5:5}:${SID:10:2}:${SID:12}"
  DIR_DCM=($(find ${DIR_SCRATCH} -type f -name '*.dcm*' -printf '%h\n' | sort -u))
  N_SCAN=${#DIR_DCM[@]}

  for (( j=0; j<${N_SCAN}; j++)) {
    ${DIR_DCM2NIIX}/${DCM_VERSION}/dcm2niix \
      -b y \
      -f "'%x_x-x_%n_x-x_%t_x-x_%s_x-x_%d'" \
      -o ${DIR_SCRATCH}/ \
      ${DIR_DCM[${j}]}
  }

  FNAME_ORIG=
  FNAME_AUTO=
  SUBDIR=
  OUT_STR=

  FLS=($(ls ${DIR_SCRATCH}/*.nii.gz))
  N_FLS=${#FLS[@]}
  for (( j=0; j<${N_SCAN}; j++)) {
    FNAME="${FLS[${j}]##*/}"
    BNAME="${FNAME[${j}]%%.*}"
    TEMP=(${BNAME//_x-x_/ })

    # get Participant ID
    PID=${TEMP[1]}
    
    # check Session ID
    CHK_SID="${TEMP[2]:0:8}T${TEMP[2]:8}"
    if [[ "${CHK_SID}" != "${SID}" ]]; then
      SID="${CHK_SID}"
    fi
    
    # look up file suffix
    CHK_DESC=$(echo "${TEMP[3]}" | sed 's/[^a-zA-Z0-9]//g')
    JSON_STR=$(jq '.[] | select(any(. == "${CHK_DESC}"))' < ${DIR_INC}/lut/series_description.lut)
    
  }
  
  for (( j=0; j<${N_SCAN}; j++)) {
    # save output variables
    FNAME_ORIG+="${BNAME}"
    FNAME_AUTO+="sub-${PID}_ses-${SID}_${SUFFIX[${j}]"
  }

  # move to DIR_QC
  ## move and rename zipfile
  ## move and rename scans
  ##
done


#===============================================================================
# End of Function
#===============================================================================
exit 0


