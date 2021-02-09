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
KERNEL="$(uname -s)"
HARDWARE="$(uname -m)"
HPC_Q=${QUEUE}
HPC_SLOTS=${NSLOTS}
KEEP=false
NO_LOG=false
umask 007

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  PROC_STOP=$(date +%Y-%m-%dT%H:%M:%S%z)
  if [[ "${NO_LOG}" == "false" ]]; then
    ${DIR_INC}/log/logBenchmark.sh --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvl --long dir-input:,lut-json:,dir-save:,dir-scratch:,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DIR_INPUT=
LUT_JSON=${DIR_INC}/lut/series_description.json
DIR_SCRATCH=${DIR_TMP}/dicomConversion_${DATE_SUFFIX}
DIR_SAVE=${DIR_QC}/dicomConversion
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --dir-input) DIR_INPUT="$2" ; shift 2 ;;
    --lut-json) LUT_JSON="$2" ; shift 2 ;;
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
  echo '  --dir-input <value>      directory containing converted dicoms'
  echo '  --lut-json <value>       directory listing for json look up table of '
  echo '                           series descriptions. Formatted such that'
  echo '                           objects specifying the BIDS-compliant rawdata'
  echo '                           sub-directory, contain arrays with names'
  echo '                           corresponding to the file suffix (e.g.,'
  echo '                           acq-ACQ_modality), which each contain strings'
  echo '                           stripped of non-alphanumeric characters that'
  echo '                           correspond to all known series descriptions.'
  echo '                           Default: DIR_INC/lut/series_description.json'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
DIR_DCM=($(find ${DIR_INPUT} -type f -name '*.dcm*' -printf '%h\n' | sort -u))
FLS=($(ls ${DIR_INPUT}/*.nii.gz))
N_FLS=${#FLS[@]}

PI=$(${DIR_INC}/bids/get_field.sh -i ${DIR_INPUT} -f pi)
PROJECT=$(${DIR_INC}/bids/get_field.sh -i ${DIR_INPUT} -f project)
PID=$(${DIR_INC}/bids/get_field.sh -i ${DIR_INPUT} -f sub)
FNAME="${FLS[0]##*/}"
BNAME="${FNAME[0]%%.*}"
TEMP=(${BNAME//_x-x_/ })
SID="${TEMP[2]:0:8}T${TEMP[2]:8}"

for (( i=0; i<${N_FLS}; i++)) {
  unset FNAME BNAME SUBDIR SUFFIX TEMP
  unset TLS QC_TSV OUT_STR
  FNAME="${FLS[${i}]##*/}"
  BNAME="${FNAME[${i}]%%.*}"
  FNAME_ORIG+="${BNAME}"
  TEMP=(${BNAME//_x-x_/ })

  # get/check Participant ID
  if [[ -z "${PID}" ]]; then
    PID=${TEMP[1]}
  elif [[ "${TEMP[1]}" != ${PID} ]]; then
    echo "WARNING [INC:${FCN_NAME}] non-matching participant identifier detected: expected PID-${PID}, non-match PID-${TEMP[1]}"
  fi
    
  # check Session ID
  CHK_SID="${TEMP[2]:0:8}T${TEMP[2]:8}"
  if [[ "${CHK_SID}" != "${SID}" ]]; then
    echo "WARNING [INC:${FCN_NAME}] non-matching session identifier detected: expected SID-${SID}, non-match SID-${CHK_SID}"
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
  TLS=($(ls ${DIR_INPUT}/sub-${PID}_ses-${SID}_${SUFFIX}*.nii.gz))
  if [[ "${TLS}" > "1" ]]; then
    unset PARTS
    PARTS=(${SUFFIX//_/ })
    for (( j=0; j<${#PARTS[@]}; j++ )); do
      if [[ "${PARTS[${j}]}" =~ "run-" ]]; then
        ${PARTS[${j}]}="run-${#TLS[@]}"
        break
      fi
    done
    SUFFIX=($(IFS=_ ; echo "${PARTS[*]}"))
  fi
        
  # rename output files
  rename "${BNAME}" "sub-${PID}_ses-${SID}_${SUFFIX}" ${DIR_INPUT}/*

  QC_TSV=${DIR_INPUT}/sub-${PID}_ses-${SID}_dicomConversion.tsv
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
    echo -e "qc_date2" >> ${QC_TSV}
  fi
  DIR_DCM_TEMP=${DIR_DCM[${i}]//${DIR_INPUT}\/}
  echo -ne "${DIR_DCM_TEMP}\t" >> ${QC_TSV}
  echo -ne "${CHK_DESC}\t" >> ${QC_TSV}
  echo -ne "${SCAN_DATE}\t" >> ${QC_TSV}
  echo -ne "${BNAME}\t" >> ${QC_TSV}
  echo -ne "sub-${PID}_ses-${SID}_${SUFFIX}\t" >> ${QC_TSV}
  echo -ne "-\t" >> ${QC_TSV}
  echo -ne "${SUBDIR}\t" >> ${QC_TSV}
  echo -ne "false\t" >> ${QC_TSV}
  echo -ne "false\t" >> ${QC_TSV}
  echo -ne "-\t" >> ${QC_TSV}
  echo -ne "-\t" >> ${QC_TSV}
  echo -ne "-\t" >> ${QC_TSV}
  echo -ne "-\t" >> ${QC_TSV}
  echo -ne "-\t" >> ${QC_TSV}
  echo -e "-" >> ${QC_TSV}

  mv ${DIR_INPUT} \
    ${DIR_SAVE}/pi-${PI}_project-${PROJECT}_sub-${PID}_ses-${SID}
  chgrp -R Research-INC_img_core ${DIR_SAVE}/pi-${PI}_project-${PROJECT}_sub-${PID}_ses-${SID}
  chmod -R 770 ${DIR_SAVE}/pi-${PI}_project-${PROJECT}_sub-${PID}_ses-${SID}
done

#===============================================================================
# End of Function
#===============================================================================
exit 0

