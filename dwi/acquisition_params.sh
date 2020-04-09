


#!/bin/bash -e

#===============================================================================
# Find acquisition parameters for DWI files
# Authors: Josh Cochran
# Date: 3/30/2020
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvl --long group:,prefix:,template:,space:,\
dir-raw:,dir-scratch:,dir-nimgcore:,dir-pincsource:,dir-save:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
TEMPLATE=HCPICBM
SPACE=1mm
DIR_RAW=
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
VERBOSE=0
HELP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --dir-raw) DIR_RAW="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo 'Author: Josh Cochran'
  echo 'Date:   3/30/2020'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --dir-raw <value>        location of the raw DWI data'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_NIMGCORE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

anyfile=(`ls ${DIR_RAW}/*.nii.gz`)
DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${anyfile[0]}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${anyfile[0]} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${anyfile[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}


#==============================================================================
# AcqParams + All bvec, bval, index + Merge files for All_B0 and All_dwi
#==============================================================================

#remove old files
rm ${DIR_SAVE}/All_dwisAcqParams.txt  > /dev/null 2>&1
rm ${DIR_SAVE}/All.bvec  > /dev/null 2>&1
rm ${DIR_SAVE}/All.bval  > /dev/null 2>&1
rm ${DIR_SAVE}/All_index.txt  > /dev/null 2>&1

unset ACQ_LINE INDX TOTAL_BVALS TOTAL_XVALS TOTAL_YVALS TOTAL_ZVALS ALL_DWI_NAMES B0s
#set up variables
declare -a ALL_DWI_NAMES
declare -a ALL_HOME_DWI_NAMES
declare -a ALL_SCRATCH_NAMES
declare -a B0s
ACQ_LINE=1
INDX=""
TOTAL_BVALS=""
TOTAL_XVALS=""
TOTAL_YVALS=""
TOTAL_ZVALS=""

touch ${DIR_SAVE}/All_dwisAcqParams.txt

FLS_DWI=(`ls ${DIR_RAW}/*_dwi.nii.gz`)
FLS_JSON=(`ls ${DIR_RAW}/*_dwi.json`)
FLS_BVEC=(`ls ${DIR_RAW}/*_dwi.bvec`)
FLS_BVAL=(`ls ${DIR_RAW}/*_dwi.bval`)
# Gather information from all DWI files
for (( i=0; i<${#FLS_DWI[@]}; i++)); do
  unset NAME_BASE DTI_NAME
  unset B0s NUM_B0s
  unset PED_STRING PED
  unset EES_STRING EES
  unset ACQ_MPE_STRING ACQ_MPE
  unset READOUT_TIME
  unset BVALS XVALS YVALS ZVALS
  
  # Get file basename, without extension and modality
  NAME_BASE=(`basename ${DWI_LS[${i}]}`)
  NAME_BASE=${NAME_BASE::-11}
  
  B0s=($(cat ${FLS_BVAL[${i}]}))
  NUM_B0s=0

  BVALS=($(cat ${FLS_BVAL[${i}]}))
  for (( j=0; j<${#BVALS[@]}; j++ )); do
    INDX="${INDX} ${ACQ_LINE}"
  done
  XVALS=($(sed "1q;d" ${FLS_BVEC[${i}]}))
  YVALS=($(sed "2q;d" ${FLS_BVEC[${i}]}))
  ZVALS=($(sed "3q;d" ${FLS_BVEC[${i}]}))
  TOTAL_BVALS="${TOTAL_BVALS} ${BVALS[@]}"
  echo $TOTAL_BVALS
  TOTAL_XVALS="${TOTAL_XVALS} ${XVALS[@]}"
  TOTAL_YVALS="${TOTAL_YVALS} ${YVALS[@]}"
  TOTAL_ZVALS="${TOTAL_ZVALS} ${ZVALS[@]}"

  SCANNER_TYPE=$(grep '"Manufacturer"' ${FLS_JSON[${i}]} | awk '{print $2}')
  SCANNER_TYPE=${SCANNER_TYPE::-1}
  SCANNER_LOC=$(grep '"InstitutionName"' ${FLS_JSON[${i}]} | awk '{print $2}')
  SCANNER_LOC=${SCANNER_LOC::-1}

  PED_STRING=$(grep '"PhaseEncodingDirection"' ${FLS_JSON[${i}]} | awk '{print $2}')
  if [[ -z ${PED_STRING} ]]; then
    PED_STRING=$(grep '"PhaseEncodingAxis"' ${FLS_JSON[${i}]} | awk '{print $2}')
  fi
  PED_STRING=${PED_STRING::-4}
  if [[ -z ${PED_STRING} ]]; then
    PED=1
  else
    PED=-1
  fi

  EES_STRING=$(grep '"EffectiveEchoSpacing"' ${FLS_JSON[${i}]} | awk '{print $2}')
  if [[ ${SCANNER_TYPE} == '"Philips"' ]]; then
    EES_STRING=$(grep '"PhilipsScaleSlope"' ${FLS_JSON[${i}]} | awk '{print $2}')
  fi
  EES=${EES_STRING::-1}
  if [[ ${SCANNER_TYPE} == Philips ]]; then
    EES=$(echo "(${EES} / 10)" | bc -l)
  fi

  ACQ_MPE_STRING=$(grep '"AcquisitionMatrixPE"' ${FLS_JSON[${i}]} | awk '{print $2}')
  ACQ_MPE=${ACQ_MPE_STRING::-1}
  READOUT_TIME=$(echo "${EES} * ((${ACQ_MPE} / 2) - 1)" | bc -l)

  echo "0 ${PED} 0 ${READOUT_TIME}" >> ${DIR_SAVE}/All_dwisAcqParams.txt
  ACQ_LINE=$(echo "${ACQ_LINE} + 1" | bc -l)

  touch ${DIR_SAVE}/${NAME_BASE}_B0sAcqParams.txt
  for j in "${B0s[@]}"; do
    k=$(echo "($j+0.5)/1" | bc)
    if [ $k -eq 0 ]; then
      echo "0 ${PED} 0 ${READOUT_TIME}" >> ${DIR_SCRATCH}/${NAME_BASE}_B0sAcqParams.txt
    fi
  done
done

echo $INDX > ${DIR_SAVE}/All_index.txt
echo $TOTAL_BVALS > ${DIR_SAVE}/All.bval
echo $TOTAL_XVALS > ${DIR_SCRATCH}/XVals.txt
echo $TOTAL_YVALS > ${DIR_SCRATCH}/YVals.txt
echo $TOTAL_ZVALS > ${DIR_SCRATCH}/ZVals.txt
cat ${DIR_SCRATCH}/XVals.txt ${DIR_SCRATCH}/YVals.txt ${DIR_SCRATCH}/ZVals.txt >> ${DIR_SAVE}/All.bvec

unset TEMP_B0_FILES TEMP_B0_ACQ_FILES TEMP_DWI_FILES
FLS_B0=(`ls ${DIR_SAVE}/*b0.nii.gz`)
FLS_B0ACQ=(`ls ${DIR_SAVE}/*B0sACqParams.txt`)

fslmerge -t ${DIR_SAVE}/All_B0s.nii.gz ${FIRST_NAME}_b0.nii.gz ${FLS_B0[@]}
fslmerge -t ${DIR_SAVE}/All_dwis.nii.gz ${FIRST_NAME2}_dwi.nii.gz ${FLS_DWI[@]}

NAME_BASE=(`basename ${DWI_LS[0]}`)
NAME_BASE=${NAME_BASE::-11}
cat ${DIR_SCRATCH}/${NAME_BASE}_B0sAcqParams.txt ${FLS_B0ACQ[@]} >> ${DIR_SAVE}/All_B0sAcqParams.txt

#------------------------------------------------------------------------------
# End of Function
#------------------------------------------------------------------------------
# Change ownership and permissions
chgrp -R ${GROUP} ${DIR_SAVE} > /dev/null 2>&1
chmod -R g+rw ${DIR_SAVE} > /dev/null 2>&1

# Clean workspace --------------------------------------------------------------
rm ${DIR_SCRATCH}/*  > /dev/null 2>&1
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

