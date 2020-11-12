#!/bin/bash -e
#===============================================================================
# DICOM Conversion Script
# Authors: Timothy R. Koscik & S. Joshua Cochran
# Date: 2020-04-21
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
NO_LOG=false

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
OPTS=$(getopt -o hvkl --long dir-project:,email:,participant:,session:,\
dicom-zip:,dicom-depth:,dont-use:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DIR_PROJECT=
EMAIL=steven-j-cochran@uiowa.edu
PARTICIPANT=
SESSION=
DICOM_ZIP=
DICOM_DEPTH=5
DONT_USE=loc,cal,orig
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
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
    --dicom-zip) DICOM_ZIP="$2" ; shift 2 ;;
    --dicom-depth) DICOM_DEPTH="$2" ; shift 2 ;;
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
  echo '  --participant <value>         participant identifier string'
  echo '  --session <value>         session identifier string'
  echo '  --dicom-zip <value>       directory listing for DICOM zip-file'
  echo '  --dicom-depth <value>     depth to search dicom directory, default=5'
  echo '  --dir-scratch <value>     directory for temporary data'
  echo '  --dont-use                comma separated string of files to skip,'
  echo '                            default: loc,cal,orig'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Determine if input is a zip file or a DICOM directory ------------------------
# 0 for zip file - 1 for DICOM directory ---------------------------------------
if [ -f "${DICOM_ZIP}" ]; then 
  FILE_TYPE=0
elif [ -d "${DICOM_ZIP}" ]; then
  FILE_TYPE=1
fi

# Unzip DICOM to scratch -------------------------------------------------------
mkdir -p ${DIR_SCRATCH}/sourcedata
mkdir -p ${DIR_SCRATCH}/rawdata

if [[ ${FILE_TYPE} == 0 ]]; then 
  if [[ "${VERBOSE}" == "true" ]]; then
    unzip ${DICOM_ZIP} -d ${DIR_SCRATCH}/sourcedata/
  else
    unzip -q ${DICOM_ZIP} -d ${DIR_SCRATCH}/sourcedata/
  fi
elif [[ ${FILE_TYPE} == 1 ]]; then
  if [[ "${VERBOSE}" == "true" ]]; then
    zip -r ${DIR_SCRATCH}/dicoms.zip ${DICOM_ZIP}
  else
    zip -r -q ${DIR_SCRATCH}/dicoms.zip ${DICOM_ZIP}
  fi
fi

# Convert DICOM to NIFTI -------------------------------------------------------
if [[ ${FILE_TYPE} == 0 ]]; then 
  ${DIR_DCM2NIIX}/dcm2niix \
    -b y -d ${DICOM_DEPTH} -z i -t y \
    -f '%x__%n__%t__%s__%d' \
    -o ${DIR_SCRATCH}/rawdata \
    ${DIR_SCRATCH}/sourcedata
elif [[ ${FILE_TYPE} == 1 ]]; then
  ${DIR_DCM2NIIX}/dcm2niix \
    -b y -d ${DICOM_DEPTH} -z i -t y \
    -f '%x__%n__%t__%s__%d' \
    -o ${DIR_SCRATCH}/rawdata \
    ${DICOM_ZIP}
fi

# Sort NIFTI files, giving them appropriate names ------------------------------
dcmsort_r_fcn="Rscript ${DIR_INC}/dicom/dicom_sort.R"
dcmsort_r_fcn="${dcmsort_r_fcn} ${DIR_PROJECT}"
dcmsort_r_fcn="${dcmsort_r_fcn} ${DIR_SCRATCH}/rawdata"
if [[ ${FILE_TYPE} == 0 ]]; then
  dcmsort_r_fcn="${dcmsort_r_fcn}  ${DICOM_ZIP}"
else
  dcmsort_r_fcn="${dcmsort_r_fcn} ${DIR_SCRATCH}/dicoms.zip"
fi
dcmsort_r_fcn=${dcmsort_r_fcn}' "dir.inc.root" '${DIR_INC}
dcmsort_r_fcn=${dcmsort_r_fcn}' "dont.use" '${DONT_USE}
if [ ! -z ${PARTICIPANT} ]; then
  dcmsort_r_fcn=${dcmsort_r_fcn}' "participant" '${PARTICIPANT}
fi
if [ ! -z ${SESSION} ]; then
  dcmsort_r_fcn=${dcmsort_r_fcn}' "session" '${SESSION}
fi
eval ${dcmsort_r_fcn}

# Extract all temporary nii.gz files -------------------------------------------
gunzip ${DIR_SCRATCH}/rawdata/sub*.gz

# Generate scan text descriptions ----------------------------------------------
NII_LS=($(ls ${DIR_SCRATCH}/rawdata/sub*.nii))
JSON_LS=($(ls ${DIR_SCRATCH}/rawdata/sub*.json))
N_SCANS=${#NII_LS[@]}
for (( i=0; i<${N_SCANS}; i++ )); do
  DESC_NAME=(${NII_LS[${i}]})
  DESC_NAME=(${DESC_NAME%.nii})
  echo ${DESC_NAME}
  DESC_TEMP=$(Rscript ${DIR_INC}/dicom/scan_description.R ${NII_LS[${i}]} ${JSON_LS[${i}]})
  echo ${DESC_TEMP} > ${DESC_NAME}_scanDescription.txt
done

# Generate DICOM Conversion QC Report ------------------------------------------
Rscript ${DIR_INC}/qc/qc_dicom_conversion.R ${DIR_PROJECT} ${DIR_SCRATCH}/rawdata

# Move QC report output --------------------------------------------------------
mkdir -p ${DIR_PROJECT}/qc/dcmConversion
cp ${DIR_SCRATCH}/rawdata/*dcmConversion.html ${DIR_PROJECT}/qc/dcmConversion/

# send email -------------------------------------------------------------------
# Gather participant info for email text
info_tsv=$(ls ${DIR_SCRATCH}/rawdata/*participant-info.tsv)
while IFS=$'\t\r' read -r a b c d;
do
  participant+=(${a})
  session+=(${b})
  site+=(${c})
  dot+=(${d})
done < ${info_tsv}
prefix=sub-${participant[1]}_ses-${session[1]}
DIR_TEXT=${DIR_PROJECT}/rawdata/sub-${participant[1]}/ses-${session[1]}/txt
mkdir -p ${DIR_TEXT}
cp ${DIR_SCRATCH}/rawdata/*_scanDescription.txt ${DIR_TEXT}/

ATTACHMENT=$(ls ${DIR_SCRATCH}/rawdata/*dcmConversion.html)
NSS_CFG_DIR=$(ls -d ~/.mozilla/firefox/*default)

echo "INPC DICOM Conversion Report

Participant: ${participant[1]}
Session: ${session[1]}
Site: ${site[1]}
Date of Scan: ${dot[1]}

" | mailx -v -s "INPC DICOM Conversion Report" \
-S smtp-use-starttls \
-S ssl-verify=ignore \
-S smtp-auth=login \
-S smtp=smtp://smtp.gmail.com:587 \
-S from="ianimgcore@gmail.com" \
-S smtp-auth-user="ianimgcore@gmail.com" \
-S smtp-auth-password="we process brains for you" \
-S ssl-verify=ignore \
-S nss-config-dir=${NSS_CFG_DIR} \
-a ${ATTACHMENT} \
${EMAIL}

exit 0

