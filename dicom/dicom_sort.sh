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
LUT_JSON=${DIR_INC}/lut/series_description.json
DCM_VERSION=1.0.20200331
DIR_SCRATCH=${DIR_TMP}/dicomConversion_${DATE_SUFFIX}
DIR_SAVE=${DIR_QC}
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --input-zip) INPUT_ZIP="$2" ; shift 2 ;;
    --lut-json) LUT_JSON="$2" ; shift 2 ;;
    --dcm-version) DCM_VERSION="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --input-zip <value>      <optional> directory listing for a zipped set'
  echo '                           of DICOM files. Will default to DIR_IMPORT'
  echo '  --lut-json <value>       directory listing for json look up table of '
  echo '                           series descriptions. Formatted such that'
  echo '                           objects specifying the BIDS-compliant rawdata'
  echo '                           sub-directory, contain arrays with names'
  echo '                           corresponding to the file suffix (e.g.,'
  echo '                           acq-ACQ_modality), which each contain strings'
  echo '                           stripped of non-alphanumeric characters that'
  echo '                           correspond to all known series descriptions.'
  echo '                           Default: DIR_INC/lut/series_description.json'
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

  FLS=($(ls ${DIR_SCRATCH}/*.nii.gz))
  N_FLS=${#FLS[@]}
  for (( j=0; j<${N_SCAN}; j++)) {
    unset FNAME BNAME SUBDIR SUFFIX TEMP
    unset TLS QC_TSV OUT_STR
    FNAME="${FLS[${j}]##*/}"
    BNAME="${FNAME[${j}]%%.*}"
    FNAME_ORIG+="${BNAME}"
    TEMP=(${BNAME//_x-x_/ })

    # get Participant ID
    if [[ -z "${PID}" ]]; then
      PID=${TEMP[1]}
    elif [[ "${TEMP[1]}" != ${PID} ]]; then
      echo "WARNING [INC:convert_dicom]--non-matching participant identifier detected: expected PID-${PID}, non-match PID-${TEMP[1]}"
    fi
    
    # check Session ID
    CHK_SID="${TEMP[2]:0:8}T${TEMP[2]:8}"
    if [[ "${CHK_SID}" != "${SID}" ]]; then
      echo "WARNING [INC:convert_dicom--non-matching session identifier detected: expected SID-${PID}, non-match SID-${CHK_SID}"
    fi    
    
    # look up file suffix
    CHK_DESC=$(echo "${TEMP[4]}" | sed 's/[^a-zA-Z0-9]//g')
    LUT_FCN='LUT_DESC=($(cat '${LUT_JSON}
    LUT_FCN="${LUT_FCN} | jq 'to_entries[]"
    LUT_FCN=${LUT_FCN}' | {"key1": .key, "key2": .value'
    LUT_FCN=${LUT_FCN}' | to_entries[] | select( .value | index("'${CHK_DESC}'")) '
    LUT_FCN="${LUT_FCN} | .key }"
    LUT_FCN="${LUT_FCN} | [.key1, .key2]'"
    LUT_FCN="${LUT_FCN} | tr -d ' [],"'"'"'))"
    eval ${LUT_FCN}
    if [[ -z ${LUT_DESC[@]} ]]; then
      SUBDIR=unk
      SUFFIX=unk
    else
      SUBDIR=${LUT_DESC[0]}
      SUFFIX=${LUT_DESC[1]}
    fi
    
    # Check for same name files and append a run flag
    TLS=($(ls ${DIR_SCRATCH}/sub-${PID}_ses-${SID}_${SUFFIX}*.nii.gz))
    if [[ "${TLS}" > "1" ]]; then
      unset PARTS
      PARTS=(${SUFFIX//_/ })
      for (( k=0; k<${#PARTS[@]}; k++ )); do
        if [[ "${PARTS[${k}]}" =~ "run-" ]]; then
          ${PARTS[${k}]}="run-${#TLS[@]}"
          break
        fi
      done
      SUFFIX=($(IFS=_ ; echo "${PARTS[*]}"))
    fi
        
    # rename output files
    rename "${BNAME}" "sub-${PID}_ses-${SID}_${SUFFIX}" ${DIR_SCRATCH}/*
    
    QC_TSV=${DIR_SCRATCH}/sub-${PID}_ses-${SID}_dicomConversion.tsv
    if [[ ! -f ${OC_TSV} ]]; then
      echo -ne "dir_dicom\t" > ${QC_TSV}
      echo -ne "series_description\t" >> ${QC_TSV}
      echo -ne "scan_date\t" >> ${QC_TSV}
      echo -ne "fname_orig\t" >> ${QC_TSV}
      echo -ne "fname_auto\t" >> ${QC_TSV}
      echo -ne "fname_manual\t" >> ${QC_TSV}
      echo -ne "subdir\t" >> ${QC_TSV}
      echo -ne "chk_view\t" >> ${QC_TSV}
      echo -ne "chk_orient\t" >> ${QC_TSV}
      echo -ne "rate_quality\t" >> ${QC_TSV}
      echo -ne "qc_action\t" >> ${QC_TSV}
      echo -ne "operator\t" >> ${QC_TSV}
      echo -ne "qc_date\t" >> ${QC_TSV}
      echo -ne "operator2\t" >> ${QC_TSV}
      echo -e "qc_date2" > ${QC_TSV}
    fi
    echo -ne "${DIR_DCM[${j}]}\t" >> ${QC_TSV}
    echo -ne "${CHK_DESC}\t" >> ${QC_TSV}
    echo -ne "${SCAN_DATE}\t" >> ${QC_TSV}
    echo -ne "${BNAME}\t" >> ${QC_TSV}
    echo -ne "sub-${PID}_ses-${SID}_${SUFFIX}\t" >> ${QC_TSV}
    echo -ne "NA\t" >> ${QC_TSV}
    echo -ne "${SUBDIR}\t" >> ${QC_TSV}
    echo -ne "false\t" >> ${QC_TSV}
    echo -ne "false\t" >> ${QC_TSV}
    echo -ne "NA\t" >> ${QC_TSV}
    echo -ne "NA\t" >> ${QC_TSV}
    echo -ne "NA\t" >> ${QC_TSV}
    echo -ne "NA\t" >> ${QC_TSV}
    echo -ne "NA\t" >> ${QC_TSV}
    echo -e "NA" >> ${QC_TSV}
  }
  # move and rename zipfile
  mv ${INPUT_ZIP[${i}]} \
    ${DIR_SCRATCH}/pi-${PI}_project-${PROJECT}_sub-${PID}_ses-${SID}_dicom.zip
  # move to DIR_QC
  mv ${DIR_SCRATCH} \
    ${DIR_SAVE}/pi-${PI}_project-${PROJECT}_sub-${PID}_ses-${SID}
  chgrp -R Research-INC_img_core ${DIR_SAVE}/pi-${PI}_project-${PROJECT}_sub-${PID}_ses-${SID}
  chmod -R 770 ${DIR_SAVE}/pi-${PI}_project-${PROJECT}_sub-${PID}_ses-${SID}
done

#===============================================================================
# End of Function
#===============================================================================
exit 0

