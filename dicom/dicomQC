#!/bin/bash -e
#===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
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
    logBenchmark --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    if [[ -n "${DIR_PROJECT}" ]]; then
      logProject --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
      --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      if [[ -n "${SID}" ]]; then
        logSession --operator ${OPERATOR} \
        --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
        --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
        --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      fi
    fi
    if [[ "${FCN_NAME}" == *"QC"* ]]; then
      logQC --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} --scan-date ${SCAN_DATE} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE} \
      --notes ${NOTES}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o h --long help, -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo "--This script will look in the ${DIR_QC}/dicom/ for folders containing"
  echo "  converted DICOMs"
  echo "--Users will be asked to visually examine and explore images to approve"
  echo "  them before they are saved to the appropriate project folder"
  echp "--The script will generate HTML reports displaying the results of DICOM"
  echo "  conversion, and will email these results to appropriate project team"
  echo "  members"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# find unused directory, trying to prevent multiple users entering the same
# directory at the same time
unset CWD DLS
DLS=($(ls -dtr ${DIR_QC}/dicomConversion/*))
while [[ -x ${CWD} ]]; do  
  # check if on IRB
  PI=$(getField -i ${DLS[0]} -f pi)
  PROJECT=$(getField -i ${DLS[0]} -f project)
  PI_LS=($(getField -i ${DIR_DB}/projects.tsv -f pi))
  PROJECT_LS=($(getColumn -i ${DIR_DB}/projects.tsv -f project_name))
  IRB_LS=($(getColumn -i ${DIR_DB}/projects.tsv -f irb_approval))
  IRB="false"
  LUT_MATCH=0
  for (( i=1; i<${#PI[@]}; i++ )); do
    if [[ "${PI_LS[${i}]}" == "${PI}" ]] &
       [[ "${PROJECT_LS[${i}]}" == "${PROJECT}" ]] &
       [[ "${IRB_LS[${i}]}" =~ "${OPERATOR}" ]]; then
      IRB="true"
      LUT_MATCH=${i}
      break
    fi
  done
  if [[ "${IRB}" == "false" ]]; then break; fi
  if [[ -f ${DLS[0]}/under_review.txt ]]; then
    DLS=("${DLS[@]:1}")
  else
    touch ${DLS[0]}/under_review.txt
    CWD=${DLS[0]}
  fi
done

# special characters & colors --------------------------------------------------
R='\033[1;31m'
G='\033[1;32m'
B='\033[1;34m'
C='\033[1;36m'
M='\033[1;35m'
Y='\033[1;33m'
NC='\033[0m'

# Check basic information ------------------------------------------------------
PI=$(getField -i ${CWD} -f pi)
PROJECT=$(getField -i ${CWD} -f project)
PID=$(getField -i ${CWD} -f sub)
SID=$(getField -i ${CWD} -f ses)

# look up project directory ----------------------------------------------------
PI_LS=($(getColumn -i ${DIR_INC}/inc_database/projects.tsv -f pi))
PROJECT_LS=($(getColumn -i ${DIR_INC}/inc_database/projects.tsv -f project_name))
DIR_LS=($(getColumn -i ${DIR_INC}/inc_database/projects.tsv -f project_directory))

if [[ "${LUT_MATCH}" == "0" ]]; then
  DIR_PROJECT=/Dedicated/inc_database/${PI}/${PROJECT}
else
  DIR_PROJECT=${DIR_LS[${i}]}
fi

unset NEXT
while [[ -z ${NEXT} ]]; do
  echo ''
  echo 'The following infomation has been identified:'
  echo -e '\t(1) PI =                  '${PI}
  echo -e '\t(2) PROJECT =             '${PROJECT}
  echo -e '\t(3) participant id, PID = '${PID}
  echo -e '\t(4) session id, SID =     '${SID}
  echo -e '\t(5) project directory, DIR_PROJECT = '${DIR_PROJECT}
  echo -e '\t(0) continue to next step'
  read -p "To change a value enter the number of the item to change, to continue enter 0: " SELECTION
  case "${SELECTION}" in
    0) NEXT="true"
       ;;
    1) unset NEW_PI
       read -p "enter the PI: " NEW_PI
       NEW_DIR=$(dirname ${CWD})
       NEW_DIR=${NEW_DIR}/pi-${NEW_PI}_project-${PROJECT}_sub-${PID}_ses-${SID}
       mv ${CWD} ${NEW_DIR}
       CWD=${NEW_DIR}
       rename "pi-${PI}" "pi-${NEW_PI}" ${CWD}/*
       PI=${NEW_PI}
       ;;
    2) unset NEW_PROJECT
       read -p "enter the PROJECT: " NEW_PROJECT
       NEW_DIR=$(dirname ${CWD})
       NEW_DIR=${NEW_DIR}/pi-${PI}_project-${NEW_PROJECT}_sub-${PID}_ses-${SID}
       mv ${CWD} ${NEW_DIR}
       CWD=${NEW_DIR}
       rename "project-${PROJECT}" "project-${NEW_PROJECT}" ${CWD}/*
       PROJECT=${NEW_PROJECT}
       ;;
    3) unset NEW_PID
       read -p "enter the participant id, PID: " NEW_PID
       NEW_DIR=$(dirname ${CWD})
       NEW_DIR=${NEW_DIR}/pi-${PI}_project-${PROJECT}_sub-${NEW_PID}_ses-${SID}
       mv ${CWD} ${NEW_DIR}
       CWD=${NEW_DIR}
       rename "sub-${PID}" "sub-${NEW_PID}" ${CWD}/*
       PID=${NEW_PID}
       ;;
    4) unset NEW_SID
       read -p "enter the session_id, SID: " NEW_SID
       NEW_DIR=$(dirname ${CWD})
       NEW_DIR=${NEW_DIR}/pi-${PI}_project-${PROJECT}_sub-${PID}_ses-${NEW_SID}
       mv ${CWD} ${NEW_DIR}
       CWD=${NEW_DIR}
       rename "ses-${SID}" "ses-${NEW_SID}" ${CWD}/*
       SID=${NEW_SID}
       ;;
    5) read -p "enter the project directory, DIR_PROJECT: " DIR_PROJECT
       ;;
  esac
done

# Check if SID should be used in filenames -------------------------------------
unset SELECTION
echo ""
read -p "keep session identifier in filenames and directory structure? (y/n): " SELECTION
case "${SELECTION,,}" in
  y) PREFIX=sub-${PID}_ses-${SID}
     DIR_PID=sub-${PID}/ses-${SID}
     ;;
  n) PREFIX=sub-${PID}
     DIR_PID=sub-${PID}
     ;;
esac

# Set up QC file ---------------------------------------------------------------
QC_LOG=sub-${PID}_ses-${SID}_dicomConversion.tsv
DIR_DICOM=($(getColumn -i ${QC_LOG} -f dir_dicom))
SERIES_DESC=($(getColumn -i ${QC_LOG} -f series_description))
SCAN_DATE=($(getColumn -i ${QC_LOG} -f scan_date))
FNAME_ORIG=($(getColumn -i ${QC_LOG} -f fname_orig))
FNAME_AUTO=($(getColumnh -i ${QC_LOG} -f fname_auto))
FNAME_MANUAL=($(getColumn -i ${QC_LOG} -f fname_manual))
SUBDIR=($(getColumn -i ${QC_LOG} -f subdir))
CHK_VIEW=($(getColumn -i ${QC_LOG} -f chk_view))
CHK_ORIENT=($(getColumn -i ${QC_LOG} -f chk_orient))
RATE_QUALITY=($(getColumn -i ${QC_LOG} -f rate_quality))
QC_ACTION=($(getColumn -i ${QC_LOG} -f qc_action))
QC_OPERATOR=($(getColumn -i ${QC_LOG} -f operator))
QC_DATE=($(getColumn -i ${QC_LOG} -f qc_date))
QC_OPERATOR2=($(getColumn -i ${QC_LOG} -f operator2))
QC_DATE2=($(getColumn -i ${QC_LOG} -f qc_date2))
N=${#FNAME_AUTO[@]}

# reset options for second opinion ---------------------------------------------
if [[ "${QC_ACTION[@],,}" =~ "second_opinion" ]]; then
  for (( i=1; i<${N}; i++)); do
    CHK_VIEW[${i}]="-"
    QC_ACTION[${i}]="-"
  done
fi

# loop over image qc -----------------------------------------------------------
while [[ "${QC_ACTION[@],,}" =~ "second_opinion" ]] |
      [[ "${QC_ACTION[@]}" =~ "-" ]] |
      [[ "${CHK_VIEW[@]}" =~ "-" ]] |
      [[ "${CHK_ORIENT[@]}" =~ "-" ]] |
      [[ "${RATE_QUALITY[@]}" =~ "-" ]]; do
  echo ""
  echo "IMAGE LIST ==================================================================="
  if [[ "${QC_ACTION[@],,}" =~ "second_opinion" ]]; then
    echo "***SECOND OPINION"
  fi
  echo "       Q"
  echo "    O  U  A"
  echo "    R  A  C"
  echo " V  I  L  T"
  echo " I  E  I  I"
  echo " E  N  T  O"
  echo " W  T  Y  N | Subdirectory/Filename"
  echo "--------------------------------------------------------------------------------"
  for (( i=1; i<${N}; i++)); do
    echo " ${CHK_VIEW[${i}]}  ${CHK_ORIENT[${i}]}  ${RATE_QUALITY[${i}]}  ${QC_ACTION[${i}]} | ${SUBDIR[${i}]}/${FNAME_AUTO}"
    if [[ "${QC_ACTION[${i}],,}" == "second_opinion"]]; then
      echo "            | ${SUBDIR[${i}]}/${FNAME_MANUAL}"
    fi
  done
  unset SELECT_IMAGE
  read -p ">>>>> select an image: " SELECT_IMAGE

  echo -e ""
  echo -e "DICOM to NIfTI Conversion QC: ${SUBDIR[${SELECT_IMAGE}]}/${FNAME_AUTO[${SELECT_IMAGE}]}"
  echo -e "  ${Y}(0)${NC} view image"
  echo -e "  ${Y}(1)${NC} edit directory"
  echo -e "  ${Y}(2)${NC} edit filename"
  echo -e "  ${Y}(3)${NC} edit image orientation"
  echo -e "  ${Y}(4)${NC} redo DICOM to NIfTI conversion"
  echo -e "  ${Y}(5)${NC} rank image quality: 0=good, 1=marginal, 2=poor"
  echo -e "  ${Y}(6)${NC} action: (a)pprove, (s)econd opinion, (d)elete"
  echo -ne " ${Y}(7)${NC} information: (N)IfTI header, (J)SON"
  if [[ -f ${CWD}/${FNAME_AUTO[${SELECT_IMAGE}]}.bval ]]; then echo -ne ", (b)val"; fi
  if [[ -f ${CWD}/${FNAME_AUTO[${SELECT_IMAGE}]}.bvec ]]; then echo -ne ", b(v)ec"; fi
  echo ""

  unset SELECT_ACTION
  read -p ">>>>> select an action: " SELECT_ACTION
  case "${SELECT_ACTION}" in
    0) ${SNAP} ${CWD}/${SUBDIR[${SELECT_IMAGE}]}/${FNAME_AUTO[${SELECT_IMAGE}]}.nii.gz &
       CHK_VIEW[${SELECT_IMAGE}]="X"
       ;;
    1) read -p ">>>>> edit directory name: " -i "${SUBDIR[${SELECT_IMAGE}]}" NEW_VALUE
       SUBDIR[${SELECT_IMAGE}]=${NEW_VALUE}
       ;;
    2) read -p ">>>>> edit file name (no extension): " -i "${FNAME_AUTO[${SELECT_IMAGE}]}" NEW_VALUE
       FNAME_MANUAL[${SELECT_IMAGE}]=${NEW_VALUE}
       ;;
    3) unset REORIENT
       read -p ">>>>> new orientation code (image WILL BE OVERWRITTEN, x=abort)" REORIENT
       if [[ "${REORIENT}" != "x" ]]; then
         if [[ "${REORIENT,,}" =~ "r" ]] | [[ "${REORIENT,,}" =~ "l" ]]; then
           if [[ "${REORIENT,,}" =~ "p" ]] | [[ "${REORIENT,,}" =~ "a" ]]; then
             if [[ "${REORIENT,,}" =~ "i" ]] | [[ "${REORIENT,,}" =~ "s" ]]; then
               TNAME=${CWD}/${SUBDIR[${SELECT_IMAGE}]}/${FNAME_AUTO[${SELECT_IMAGE}]}.nii.gz
               mv ${TNAME} ${CWD}/temp.nii.gz
               3dresample -orient ${REORIENT,,} -prefix ${TNAME} -input ${CWD}/temp.nii.gz
               CopyImageHeaderInformation ${CWD}/temp.nii.gz ${TNAME} ${TNAME} 1 1 0
               ${SNAP} ${CWD}/${SUBDIR[${SELECT_IMAGE}]}/${FNAME[${SELECT_IMAGE}]} &
               ORIENT[${SELECT_IMAGE}]=${REORIENT}
             fi
           fi
         fi      
       fi
       ;;
    4) HARDWARE="$(unname -s)"
       KERNEL="$(uname -m)"
       AVAIL_DCM2NIIX=($(ls -d ${DIR_PINC}/dcm2niix/${HARDWARE}/${KERNEL}))
       echo ""
       echo "Available DCM2NIIX versions:"
       for (( i=0; i<${#AVAIL_DCM2NIIX[@]}; i++ )); do
         echo -e "\t${Y}(${i})${NC} ${AVAIL_DCM2NIIX[${i}]}"
       done
       read -p ">>>>> Enter the desired version: " WHICH_VERSION
       dicomConvert \
         --dir-input ${DIR_DCM[${j}]} \
         --dir-save ${DIR_SCRATCH} \
         --dcm-version ${AVAIL_DCM2NIIX[${WHICH_VERSION}]} \
         --reorient rpi
       rename "${FNAME_ORIG[${SELECT_IMAGE}]}" "${FNAME_AUTO[${SELECT_IMAGE}]}" ${CWD}
       CHK_VIEW[${SELECT_IMAGE}]="-"
       CHK_ORIENT[${SELECT_IMAGE}]="-"
       RATE_QUALITY[${SELECT_IMAGE}]="-"
       QC_ACTION[${SELECT_IMAGE}]="-"
       ;;
    5) unset NEW_QUALITY
       read -p ">>>>> enter your quality ranking (0=good, 1=marginal, 2=poor): " NEW_QUALITY
       RATE_QUALITY[${SELECT_IMAGE}]=${NEW_QUALITY}
       ;;
    6) unset NEW_ACTION
       read -p ">>>>> enter the action to take on the image (a)pprove, (s)econd opinion, (d)elete]: " NEW_ACTION
       QC_ACTION[${SELECT_IMAGE}]=${NEW_ACTION}
       ;;
    7) unset WHICH_INFO
       read -p ">>>>> choose information to display: (n)ifti, (j)son, (b)val, b(vec)" WHICH_INFO
       case "${WHICH_INFO}" in
         n) PrintHeader ${CWD}/${SUBDIR[${SELECT_IMAGE}]}/${FNAME_AUTO[${SELECT_IMAGE}]}.nii.gz
            ;;
         j) jq '.'  ${CWD}/${SUBDIR[${SELECT_IMAGE}]}/${FNAME_AUTO[${SELECT_IMAGE}]}.json
            ;;
         b) cat ${CWD}/${SUBDIR[${SELECT_IMAGE}]}/${FNAME_AUTO[${SELECT_IMAGE}]}.bval
            ;;
         v) cat ${CWD}/${SUBDIR[${SELECT_IMAGE}]}/${FNAME_AUTO[${SELECT_IMAGE}]}.bvec
            ;;
       esac
       ;;
  esac
  if [[ "${QC_ACTION[@],,}" =~ "second_opinion" ]]; then
    QC_OPERATOR2[${SELECT_IMAGE}]=${OPERATOR}
    QC_DATE2[${SELECT_IMAGE}]="ADDTIMEHERE"
  else
    QC_OPERATOR[${SELECT_IMAGE}]=${OPERATOR}
    QC_DATE[${SELECT_IMAGE}]="ADDTIMEHERE"
  fi
done

# if QC complete
if [[ ! "${QC_ACTION[@],,}" =~ "-" ]] &
   [[ ! "${CHK_VIEW[@],,}" =~ "-" ]] &
   [[ ! "${CHK_ORIENT[@]}" =~ "-" ]] &
   [[ ! "${RATE_QUALITY[@]}" =~ "-" ]]; then
  # Perform all actions
  for (( i=0; i<${N}; i++ )); do
    # delete unwanted files
    if [[ "${QC_ACTION}" == "d" ]]; then
      rm ${CWD}/${FNAME_AUTO[${i}]}*
      break
    fi
    # Move files into sub directories
    if [[ "${FNAME_MANUAL[${i}]}" != "-" ]]; then
      rename "${FNAME_AUTO[${i}]}" "${FNAME_MANUAL[${i}]}" ${CWD}/*
      mkdir -p ${DIR_PROJECT}/rawdata/${SUBDIR[${i}]}
      mv ${CWD}/${FNAME_MANUAL[${i}]}* ${DIR_PROJECT}/rawdata/${SUBDIR[${i}]}/
    else
      mkdir -p ${DIR_PROJECT}/rawdata/${SUBDIR[${i}]}
      mv ${CWD}/${FNAME_AUTO[${i}]}* ${DIR_PROJECT}/rawdata/${SUBDIR[${i}]}/
    fi
  done
  # move dicom folder
  mv ${CWD}/pi-${PI}_project-${PROJECT}_sub-${PID}_ses-${SID}_dicom.zip \
    ${DIR_PROJECT}/sourcedata/
  # write data to log file
  END_TIME=$(date +%Y-%m-%dT%H:%M:%S)
  mkdir -p ${DIR_PROJECT}/log
  SUB_LOG=${DIR_PROJECT}/log/sub-${PID}_ses-${SID}_dicomConversion.log
  echo -e "scan_date\tfname_orig\tfname_auto\tfname_manual\tsubdir\tchk_view\tchk_orient\trate_quality\tqc_action\toperator\tqc_date\toperator2\tqc_date2" >> ${SUB_LOG}
  for (( i=0; i<${N}; i++ )); do
    echo -ne "${SCAN_DATE[${i}]}\t" >> ${SUB_LOG}
    echo -ne "${FNAME_ORIG[${i}]}\t" >> ${SUB_LOG}
    echo -ne "${FNAME_AUTO[${i}]}\t" >> ${SUB_LOG}
    echo -ne "${FNAME_MANUAL[${i}]}\t" >> ${SUB_LOG}
    echo -ne "${SUBDIR[${i}]}\t" >> ${SUB_LOG}
    echo -ne "${CHK_VIEW[${i}]}\t" >> ${SUB_LOG}
    echo -ne "${CHK_ORIENT[${i}]}\t" >> ${SUB_LOG}
    echo -ne "${RATE_QUALITY[${i}]}\t" >> ${SUB_LOG}
    echo -ne "${QC_ACTION[${i}]}\t" >> ${SUB_LOG}
    echo -ne "${QC_OPERATOR[${i}]}\t" >> ${SUB_LOG}
    if [[ "${QC_OPERATOR2[${i}],,}" == "-" ]]
      echo -ne "${END_TIME}\t" >> ${SUB_LOG}
    else
      echo -ne "${QC_DATE[${i}]}\t" >> ${SUB_LOG}
    fi
    echo -ne "${QC_OPERATOR2[${i}]}\t" >> ${SUB_LOG}
    if [[ "${QC_OPERATOR2[${i}],,}" != "-" ]]
      echo -e "${END_TIME}" >> ${SUB_LOG}
    else
      echo -e "${QC_DATE2[${i}]}" >> ${SUB_LOG}
    fi
  done
  
  LOG_STRING=$(date +"${OPERATOR}\t${FCN_NAME}\t${SCAN_DATE[${i}]}\t${PROC_START}\t${END_TIME}")
  QC_LOG=${DIR_DB}/log/${FCN_NAME}.log
  if [[ ! -f ${QC_LOG} ]]; then
    echo -e 'operator\tfunction\tscan_acq\start\tend' > ${QC_LOG}
  fi
  echo -e ${LOG_STRING} >> ${QC_LOG}
fi

# append novel acq fields to series_description.json
# generate images for html reports
# generate file tree for reports
# generate and knit reports
# send messages

#===============================================================================
# End of Function
#===============================================================================
exit 0


