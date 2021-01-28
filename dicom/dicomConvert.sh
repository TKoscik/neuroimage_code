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
    FCN_LOG=${DIR_DB}/log/benchmark_${FCN_NAME}.log
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
dir-input:,dir-save:,dcm-version:,depth:,reorient:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
INPUT=
DIR_SAVE=
DCM_VERSION=
DEPTH=5
REORIENT=rpi
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --input) INPUT="$2" ; shift 2 ;;
    --dcm-version) DCM_VERSION="$2" ; shift 2 ;;
    --depth) DEPTH="$2" ; shift 2 ;;
    --reorient) REORIENT="$2" ; shift 2 ;;
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
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --dir-input <value>      directory listing containing dcm files to'
  echo '                           convert, must be unzipped'
  echo '  --dir-save <value>       location to save nifti data'
  echo '  --dcm-version <value>    can use any installed version of dcm2niix'
  echo '  --depth <value>          how far down directory tree to look for dicom'
  echo '                           files, default=5'
  echo '  --reorient <value>       three letter code to reorient image, default=rpi'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
mkdir -p ${DIR_SAVE}

# parse inputs -----------------------------------------------------------------
if [[ -d "${INPUT}" ]]; then
  DIR_DCM=($(find ${INPUT} -type f -name '*.dcm*' -printf '%h\n' | sort -u))
else
  FNAME="${INPUT##*/}"
  FEXT="${FNAME##*.}"
  if [[ "${FEXT,,}" != "zip" ]];
    echo "ERROR [INC:${FCN_NAME}] Input must be either a directory or zip file"
    exit 1
  fi
  cp ${INPUT} ${DIR_SAVE}/
  unzip ${DIR_SAVE}/${FNAME} -qq -d ${DIR_SAVE}
  DIR_DCM=($(find ${DIR_SAVE} -type f -name '*.dcm*' -printf '%h\n' | sort -u))
fi
N_SCAN=${#DIR_DCM[@]}

# convert dicoms ---------------------------------------------------------------
for (( i=0; i<${N_SCAN}; i++ )); do
  if [[ -n ${DCM_VERSION} ]];
    dcm_fcn="${DCM2NIIX}"
  else
    KERNEL="$(unname -s)"
    HARDWARE="$(uname -m)"
    dcm_fcn="${DIR_PINC}/dcm2niix/${KERNEL}/${HARDWARE}/${VERSION}/dcm2niix"
  fi
  dcm_fcn="${dcm_fcn} -b y -d ${DEPTH} -v ${VERBOSE}"
  dcm_fcn=${dcm_fcn}' -f "%x_x-x_%n_x-x_%t_x-x_%s_x-x_%d'
  dcm_fcn="${dcm_fcn} -o ${DIR_SAVE}/"
  dcm_fcn="${dcm_fcn} ${DIR_DCM[${i}]}"
  eval ${dcm_fcn}
fi

if [[ -n ${REORIENT} ]]; then
  if [[ "${REORIENT,,}" =~ "r" ]] | [[ "${REORIENT,,}" =~ "l" ]]; then
    if [[ "${REORIENT,,}" =~ "p" ]] | [[ "${REORIENT,,}" =~ "a" ]]; then
      if [[ "${REORIENT,,}" =~ "i" ]] | [[ "${REORIENT,,}" =~ "s" ]]; then
        FLS=($(ls ${DIR_SAVE}/*.nii.gz))
        N=${#FLS[@]}
        for (( i=0; i<${N}, i++ )); do
          CUR_ORIENT=$(3dinfo -orient ${FLS[${i}]})
          if [[ "${CUR_ORIENT,,}" != "${REORIENT,,}" ]]; then
            mv ${FLS[${i}]} ${DIR_SAVE}/temp.nii.gz
            3dresample -orient ${REORIENT,,} -prefix ${FLS[${i}]} -input ${DIR_SAVE}/temp.nii.gz
          fi
        done
      fi
    fi
  fi
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0

