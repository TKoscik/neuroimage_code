#!/bin/bash -e

#===============================================================================
# DICOM Conversion Script
# Authors: Timothy R. Koscik & S. Joshua Cochran
# Date: 2020-04-21
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
DEBUG=false
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v DIR_PROJECT ]]; then
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
OPTS=`getopt -o hdvkl --long dir-project:,group:,email:,subject:,session:,\
dicom-zip:,dicom-depth:,dont-use:,\
dir-scratch:,dir-code:,dir-pincsource:,dir-dicomsource:,\
help,debug,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DIR_PROJECT=
GROUP=
EMAIL=steven-j-cochran@uiowa.edu
SUBJECT=
SESSION=
DICOM_ZIP=
DICOM_DEPTH=5
DONT_USE=loc,cal,orig
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps
DIR_DICOMSOURCE=/Shared/pinc/sharedopt/apps/dcm2niix/Linux/x86_64/1.0.20190902
HELP=false
VERBOSE=false
KEEP=false
#DEIDENTIFY=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -d | --debug) DEBUG=true ; shift ;;
    -v | --verbose) VERBOSE=true ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --dir-project) DIR_PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --email) EMAIL="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --dicom-zip) DICOM_ZIP="$2" ; shift 2 ;;
    --dicom-depth) DICOM_DEPTH="$2" ; shift 2 ;;
    --dont-use) DONT_USE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    --dir-dicomsource) DIR_DICOMSOURCE="$2" ; shift 2 ;;
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
  echo '  -d | --debug              keep scratch folder for debugging'
  echo '  -v | --verbose            add verbose output to log file'
  echo '  -k | --keep               keep intermediates'
  echo '  -l | --no-log             disable writing to output log'
  echo '  --researcher <value>      directory containing the project, e.g. /Shared/koscikt'
  echo '  --project <value>         name of the project folder, e.g., iowa_black'
  echo '  --group <value>           group permissions for project, e.g., Research-kosciklab'
  echo '  --email <values>          comma-delimited list of email addresses'
  echo '  --dicom-zip <value>       directory listing for DICOM zip-file'
  echo '  --dicom-depth <value>     depth to search dicom directory, default=5'
  echo '  --dir-scratch <value>     directory for temporary data'
  echo '  --dir-nimgcore <value>    directory where INPC tools and atlases are stored, default: /Shared/nopoulos/nimg_core'
  echo '  --dir-pincsource <value>  directory where pinc apps are located, default: /Shared/pinc/sharedopt/apps'
  echo '  --dir-dicomsource <value> directory where dcm2niix source files are located, default: /Shared/pinc/sharedopt/apps/dcm2niix/Linux/x86_64/1.0.20180622'
  echo '  --save-loc                whether to save localizer scans, default: false'
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
  ${DIR_DICOMSOURCE}/dcm2niix \
    -b y -d ${DICOM_DEPTH} -z i -t y \
    -f '%x__%n__%t__%s__%d' \
    -o ${DIR_SCRATCH}/rawdata \
    ${DIR_SCRATCH}/sourcedata
elif [[ ${FILE_TYPE} == 1 ]]; then
  ${DIR_DICOMSOURCE}/dcm2niix \
    -b y -d ${DICOM_DEPTH} -z i -t y \
    -f '%x__%n__%t__%s__%d' \
    -o ${DIR_SCRATCH}/rawdata \
    ${DICOM_ZIP}
fi

# Sort NIFTI files, giving them appropriate names ------------------------------
dcmsort_r_fcn="Rscript ${DIR_CODE}/dicom/dicom_sort.R"
dcmsort_r_fcn="${dcmsort_r_fcn} ${DIR_PROJECT}"
dcmsort_r_fcn="${dcmsort_r_fcn} ${DIR_SCRATCH}/rawdata"
if [[ ${FILE_TYPE} == 0 ]]; then
  dcmsort_r_fcn="${dcmsort_r_fcn}  ${DICOM_ZIP}"
else
  dcmsort_r_fcn="${dcmsort_r_fcn} ${DIR_SCRATCH}/dicoms.zip"
fi
dcmsort_r_fcn=${dcmsort_r_fcn}' "dir.inc.root" '${DIR_CODE}
dcmsort_r_fcn=${dcmsort_r_fcn}' "dont.use" '${DONT_USE}
if [ -n ${SUBJECT} ]; then
  dcmsort_r_fcn=${dcmsort_r_fcn}' "subject" '${SUBJECT}
fi
if [ -n ${SESSION} ]; then
  dcmsort_r_fcn=${dcmsort_r_fcn}' "session" '${SESSION}
fi
eval ${dcmsort_r_fcn}

#if [[ ${FILE_TYPE} == 0 ]]; then 
#  Rscript ${DIR_CODE}/dicom/dicom_sort.R \
#    ${DIR_PROJECT} \
#    ${DIR_SCRATCH}/rawdata \
#    ${DICOM_ZIP} \
#    "dir.inc.root" ${DIR_CODE} \
#    "dont.use" ${DONT_USE} \
#    "dry.run" "FALSE"
#elif [[ ${FILE_TYPE} == 1 ]]; then
#  Rscript ${DIR_CODE}/dicom/dicom_sort.R \
#    ${DIR_PROJECT} \
#    ${DIR_SCRATCH}/rawdata \
#    ${DIR_SCRATCH}/dicoms.zip \
#    "dir.inc.root" ${DIR_CODE} \
#    "dont.use" ${DONT_USE} \
#    "dry.run" "FALSE"
#fi
# Extract all temporary nii.gz files -------------------------------------------
gunzip ${DIR_SCRATCH}/rawdata/sub*.gz

# Generate scan text descriptions ----------------------------------------------
NII_LS=(`ls ${DIR_SCRATCH}/rawdata/sub*.nii`)
JSON_LS=(`ls ${DIR_SCRATCH}/rawdata/sub*.json`)
N_SCANS=${#NII_LS[@]}
for (( i=0; i<${N_SCANS}; i++ )); do
  DESC_NAME=(${NII_LS[${i}]})
  DESC_NAME=(${DESC_NAME%.nii})
  echo ${DESC_NAME}
  DESC_TEMP=`Rscript ${DIR_CODE}/dicom/scan_description.R ${NII_LS[${i}]} ${JSON_LS[${i}]}`
  echo ${DESC_TEMP} > ${DESC_NAME}_scanDescription.txt
done

# Generate DICOM Conversion QC Report ------------------------------------------
Rscript ${DIR_CODE}/qc/qc_dicom_conversion.R ${DIR_PROJECT} ${DIR_SCRATCH}/rawdata

# send email -------------------------------------------------------------------
# Gather subject info for email text
info_tsv=`ls ${DIR_SCRATCH}/rawdata/*subject-info.tsv`
while IFS=$'\t\r' read -r a b c d;
do
  subject+=(${a})
  session+=(${b})
  site+=(${c})
  dot+=(${d})
done < ${info_tsv}
prefix=sub-${subject[1]}_ses-${session[1]}
DIR_TEXT=${DIR_PROJECT}/rawdata/sub-${subject[1]}/ses-${session[1]}/txt
mkdir -p ${DIR_TEXT}
cp ${DIR_SCRATCH}/rawdata/*_scanDescription.txt ${DIR_TEXT}/

ATTACHMENT=`ls ${DIR_SCRATCH}/rawdata/*dcmConversion.html`
NSS_CFG_DIR=`ls -d ~/.mozilla/firefox/*default`

echo "INPC DICOM Conversion Report

Subject: ${subject[1]}
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
-S smtp-auth-password="brains brains brains" \
-S ssl-verify=ignore \
-S nss-config-dir=${NSS_CFG_DIR} \
-a ${ATTACHMENT} \
${EMAIL}

# Move QC report output --------------------------------------------------------
mkdir -p ${DIR_PROJECT}/qc/dcmConversion
mv ${DIR_SCRATCH}/rawdata/*dcmConversion.html ${DIR_PROJECT}/qc/dcmConversion/

# Change ownership and permissions ---------------------------------------------
chgrp ${GROUP} ${DIR_PROJECT}/sourcedata/${prefix}_DICOM.zip > /dev/null 2>&1
chgrp ${GROUP} ${DIR_PROJECT}/qc/dicom_conversion/${prefix}_qc-dicomConversion.html > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_PROJECT}/rawdata/sub-${subject[1]}/ses-${session[1]} > /dev/null 2>&1

chmod g+rw ${DIR_PROJECT}/sourcedata/${prefix}_DICOM.zip > /dev/null 2>&1
chmod g+rw ${DIR_PROJECT}/qc/dicom_conversion/${prefix}_qc-dicomConversion.html  > /dev/null 2>&1
chmod -R g+rw ${DIR_PROJECT}/rawdata/sub-${subject[1]}/ses-${session[1]} > /dev/null 2>&1

# Clean up temporary files -----------------------------------------------------
if [ "${KEEP}" == "false" ]; then
  rm -rd ${DIR_SCRATCH}
fi

exit 0

