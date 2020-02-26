#! /bin/bash
# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvk --long researcher:,project:,group:,email:,dicom-zip:,dicom-depth:,dont-use:,dir-scratch:,dir-nimgcore:,dir-pincsource:,dir-dicomsource:,help,verbose,keep -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%z)
RESEARCHER=
PROJECT=
GROUP=
EMAIL=steven-j-cochran@uiowa.edu
DICOM_ZIP=
DICOM_DEPTH=5
DONT_USE=loc,cal,orig
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps
DIR_DICOMSOURCE=/Shared/pinc/sharedopt/apps/dcm2niix/Linux/x86_64/1.0.20180622
HELP=false
VERBOSE=false
KEEP=false
#DEIDENTIFY=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=true ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --email) EMAIL="$2" ; shift 2 ;;
    --dicom-zip) DICOM_ZIP="$2" ; shift 2 ;;
    --dicom-depth) DICOM_DEPTH="$2" ; shift 2 ;;
    --dont-use) DONT_USE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    --dir-dicomsource) DIR_DICOMSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '--------------------------------------------------------------------------------'
  echo 'Iowa Neuroimage Processing Core: DICOM Conversion and BIDS-ification'
  echo 'Author: Timothy R. Koscik'
  echo 'Date:   2019-10-21'
  echo '--------------------------------------------------------------------------------'
  echo 'Usage: inc_jlf.sh \'
  echo '  -h | --help               display command help'
  echo '  -v | --verbose            add verbose output to log file'
  echo '  -k | --keep               keep intermediates'
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
fi

proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

# Unzip DICOM to scratch -------------------------------------------------------
mkdir -p ${DIR_SCRATCH}/dicom
mkdir -p ${DIR_SCRATCH}/nifti

if [[ "${VERBOSE}" == "true" ]]; then
  unzip ${DICOM_ZIP} -d ${DIR_SCRATCH}/dicom/
else
  unzip -q ${DICOM_ZIP} -d ${DIR_SCRATCH}/dicom/
fi

# Dump DICOM header info into folder -------------------------------------------
source ${DIR_PINCSOURCE}/sourcefiles/gdcm_source.sh
count=0
find "${DIR_SCRATCH}/dicom" -type d | sort -t '\0' -n |
while read d; do
  unset files file1
  files=(`ls "$d"`)
  file1=${d}/${files[0]}
  if [[ ! -d ${file1} ]]; then
    if [[ ${file1} == *.dcm ]]; then
      ((count=count+1))
      gdcmdump ${file1} > ${DIR_SCRATCH}/nifti/dcmdump_${count}.txt
    fi
  fi
done

# Convert DICOM to NIFTI -------------------------------------------------------
${DIR_DICOMSOURCE}/dcm2niix \
  -b y -d ${DICOM_DEPTH} -z i -t y \
  -f '%x_%n_%t_%s_%d' \
  -o ${DIR_SCRATCH}/nifti \
  ${DIR_SCRATCH}/dicom

# Sort NIFTI files, giving them appropriate names ------------------------------
Rscript ${DIR_NIMGCORE}/inc_dcmSort.R \
  ${RESEARCHER} \
  ${PROJECT} \
  ${DIR_SCRATCH}/nifti \
  ${DICOM_ZIP} \
  "dir.inc.root" ${DIR_NIMGCORE} \
  "dont.use" ${DONT_USE} \
  "dry.run" "FALSE"

# Extract all temporary nii.gz files -------------------------------------------
gunzip ${DIR_SCRATCH}/nifti/sub*.gz

# Generate scan text descriptions ----------------------------------------------
NII_LS=(`ls ${DIR_SCRATCH}/nifti/sub*.nii`)
JSON_LS=(`ls ${DIR_SCRATCH}/nifti/sub*.json`)
DCMDUMP_LS=(`ls ${DIR_SCRATCH}/nifti/sub*_dcmdump.txt`)
N_SCANS=${#NII_LS[@]}
for (( i=0; i<${N_SCANS}; i++ )); do
  DESC_NAME=(${NII_LS[${i}]})
  DESC_NAME=(${DESC_NAME%.nii})
  echo ${DESC_NAME}
  DESC_TEMP=`Rscript ${DIR_NIMGCORE}/inc_scanDescription.R ${NII_LS[${i}]} ${JSON_LS[${i}]} ${DCMDUMP_LS[${i}]}`
  echo ${DESC_TEMP} > ${DESC_NAME}_scanDescription.txt
done

# Generate DICOM Conversion QC Report ------------------------------------------
Rscript ${DIR_NIMGCORE}/inc_qc-dcmConversion.R ${RESEARCHER} ${PROJECT} ${DIR_SCRATCH}/nifti

# send email -------------------------------------------------------------------
# Gather subject info for email text
info_tsv=`ls ${DIR_SCRATCH}/nifti/*subject-info.tsv`
while IFS=$'\t\r' read -r a b c d;
do
  subject+=(${a})
  session+=(${b})
  site+=(${c})
  dot+=(${d})
done < ${info_tsv}
prefix=sub-${subject[1]}_ses-${session[1]}_site-${site[1]}
DIR_TEXT=${RESEARCHER}/${PROJECT}/nifti/sub-${subject[1]}/ses-${session[1]}/txt
mkdir -p ${DIR_TEXT}
cp ${DIR_SCRATCH}/nifti/*_scanDescription.txt ${DIR_TEXT}/

ATTACHMENT=`ls ${DIR_SCRATCH}/nifti/*dcmConversion.html`
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
mkdir -p ${RESEARCHER}/${PROJECT}/qc/dcmConversion
mv ${DIR_SCRATCH}/nifti/*dcmConversion.html ${RESEARCHER}/${PROJECT}/qc/dcmConversion/

# Change ownership and permissions ---------------------------------------------
chgrp ${GROUP} ${RESEARCHER}/${PROJECT}/dicom/${prefix}_DICOM.zip > /dev/null 2>&1
chgrp ${GROUP} ${RESEARCHER}/${PROJECT}/qc/dcmConversion/${prefix}_qc-dcmConversion.html > /dev/null 2>&1
chgrp -R ${GROUP} ${RESEARCHER}/${PROJECT}/nifti/sub-${subject[1]}/ses-${session[1]} > /dev/null 2>&1

chmod g+rw ${RESEARCHER}/${PROJECT}/dicom/${prefix}_DICOM.zip > /dev/null 2>&1
chmod g+rw ${RESEARCHER}/${PROJECT}/qc/dcmConversion/${prefix}_qc-dcmConversion.html  > /dev/null 2>&1
chmod -R g+rw ${RESEARCHER}/${PROJECT}/nifti/sub-${subject[1]}/ses-${session[1]} > /dev/null 2>&1

# Clean up temporary files -----------------------------------------------------
if [ "${KEEP}" == "false" ]; then
  rm -rd ${DIR_SCRATCH}
fi

# Write log file ---------------------------------------------------------------
LOG=${RESEARCHER}/${PROJECT}/log/${prefix}_INPC.log
echo "#===============================================================================" >> ${LOG}
echo "# Iowa Neuroimaging Core Processing Log" >> ${LOG}
echo "Subject: "${subject[1]} >> ${LOG}
echo "Session: "${session[1]} >> ${LOG}
echo "Site: "${site[1]} >> ${LOG}
echo "Date of Scan: "${dot[1]} >> ${LOG}
echo "#===============================================================================" >> ${LOG}
echo "" >> ${LOG}
echo "#-------------------------------------------------------------------------------" >> ${LOG}
echo "task:dicom_conversion" >> ${LOG}
echo "software:dcm2niix,1.0.20180622" >> ${LOG}
echo "start_time:"${proc_start} >> ${LOG}
date +"end_time:%Y-%m-%dT%H:%M:%S%z" >> ${LOG}
echo "#-------------------------------------------------------------------------------" >> ${LOG}
echo "" >> ${LOG}

chgrp ${GROUP} ${LOG} > /dev/null 2>&1
chmod g+rw ${LOG} > /dev/null 2>&1


