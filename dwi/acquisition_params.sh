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
  exit 1
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
if [[ -f ${DIR_SAVE}/All_dwisAcqParams.txt ]]; then
  rm ${DIR_SAVE}/All_dwisAcqParams.txt
fi
if [[ -f ${DIR_SAVE}/All.bvec ]]; then
  rm ${DIR_SAVE}/All.bvec
fi
if [[ -f ${DIR_SAVE}/All.bval ]]; then
  rm ${DIR_SAVE}/All.bval
fi
if [[ -f ${DIR_SAVE}/All_index.txt ]]; then
  rm ${DIR_SAVE}/All_index.txt
fi

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

#loop through DWI files to pull out info
for i in ${DIR_RAW}/*_dwi.nii.gz; do
  unset DTI_NAME B0s NUM_B0s PED_STRING PED_STRING PED EES_STRING EES ACQ_MPE_STRING ACQ_MPE READOUT_TIME NAME_BASE BVALS XVALS YVALS ZVALS PED_STRING PED_STRING PED EES_STRING EES ACQ_MPE_STRING ACQ_MPE READOUT_TIME
#pull the file name with and without file path
  NAME_BASE=$( basename $i )
  NAME_BASE=${NAME_BASE::-11}
  DTI_NAME=${i::-11}

  B0s=($(cat ${DTI_NAME}_dwi.bval))
  NUM_B0s=0

  BVALS=($(cat ${DTI_NAME}_dwi.bval))
  for j in "${BVALS[@]}"; do
    INDX="${INDX} ${ACQ_LINE}"
  done
  XVALS=($(sed "1q;d" ${DTI_NAME}_dwi.bvec))
  YVALS=($(sed "2q;d" ${DTI_NAME}_dwi.bvec))
  ZVALS=($(sed "3q;d" ${DTI_NAME}_dwi.bvec))
  TOTAL_BVALS="${TOTAL_BVALS} ${BVALS[@]}"
  echo $TOTAL_BVALS
  TOTAL_XVALS="${TOTAL_XVALS} ${XVALS[@]}"
  TOTAL_YVALS="${TOTAL_YVALS} ${YVALS[@]}"
  TOTAL_ZVALS="${TOTAL_ZVALS} ${ZVALS[@]}"

  SCANNER_TYPE=$(grep '"Manufacturer"' ${DTI_NAME}_dwi.json | awk '{print $2}')
  SCANNER_TYPE=${SCANNER_TYPE::-1}
  SCANNER_LOC=$(grep '"InstitutionName"' ${DTI_NAME}_dwi.json | awk '{print $2}')
  SCANNER_LOC=${SCANNER_LOC::-1}

  PED_STRING=$(grep '"PhaseEncodingDirection"' ${DTI_NAME}_dwi.json | awk '{print $2}')
  if [[ -z ${PED_STRING} ]]; then
    PED_STRING=$(grep '"PhaseEncodingAxis"' ${DTI_NAME}_dwi.json | awk '{print $2}')
  fi
  PED_STRING=${PED_STRING::-4}
  if [ -z $PED_STRING ]; then
    PED=1
  else
    PED=-1
  fi

  EES_STRING=$(grep '"EffectiveEchoSpacing"' ${DTI_NAME}_dwi.json | awk '{print $2}')
  if [[ ${SCANNER_TYPE} == '"Philips"' ]]; then
    EES_STRING=$(grep '"PhilipsScaleSlope"' ${DTI_NAME}_dwi.json | awk '{print $2}')
  fi
  EES=${EES_STRING::-1}
  if [[ ${SCANNER_TYPE} == Philips ]]; then
    EES=$(echo "(${EES} / 10)" | bc -l)
  fi

  ACQ_MPE_STRING=$(grep '"AcquisitionMatrixPE"' ${DTI_NAME}_dwi.json | awk '{print $2}')
  ACQ_MPE=${ACQ_MPE_STRING::-1}
  READOUT_TIME=$(echo "${EES} * ((${ACQ_MPE} / 2) - 1)" | bc -l)

  echo "0 ${PED} 0 ${READOUT_TIME}" >> ${DIR_SAVE}/All_dwisAcqParams.txt
  ACQ_LINE=$(echo "${ACQ_LINE} + 1" | bc -l)

  touch ${DIR_SCRATCH}/${NAME_BASE}_B0sAcqParams.txt
  for j in "${B0s[@]}"; do
    k=$(echo "($j+0.5)/1" | bc)
    if [ $k -eq 0 ]; then
      echo "0 ${PED} 0 ${READOUT_TIME}" >> ${DIR_SCRATCH}/${NAME_BASE}_B0sAcqParams.txt
    fi
  done
  ALL_DWI_NAMES+=(${DIR_SAVE}/${NAME_BASE})
  ALL_HOME_DWI_NAMES+=(${DTI_NAME})
  ALL_SCRATCH_NAMES+=(${DIR_SCRATCH}/${NAME_BASE})
done

echo $INDX > ${DIR_SAVE}/All_index.txt
echo $TOTAL_BVALS > ${DIR_SAVE}/All.bval
echo $TOTAL_XVALS > ${DIR_SCRATCH}/XVals.txt
echo $TOTAL_YVALS > ${DIR_SCRATCH}/YVals.txt
echo $TOTAL_ZVALS > ${DIR_SCRATCH}/ZVals.txt
cat ${DIR_SCRATCH}/XVals.txt ${DIR_SCRATCH}/YVals.txt ${DIR_SCRATCH}/ZVals.txt >> ${DIR_SAVE}/All.bvec

FIRST_NAME=${ALL_DWI_NAMES[0]}
FIRST_NAME2=${ALL_HOME_DWI_NAMES[0]}
FIRST_NAME3=${ALL_SCRATCH_NAMES[0]}

unset TEMP_B0_FILES TEMP_B0_ACQ_FILES TEMP_DWI_FILES
declare -a TEMP_B0_FILES
declare -a TEMP_B0_ACQ_FILES
declare -a TEMP_DWI_FILES

for j in ${ALL_DWI_NAMES[@]}; do
  if [ "${FIRST_NAME}" != "$j" ]; then
    TEMP_B0_FILES+=(${j}_b0.nii.gz)
  fi
done
for j in ${ALL_HOME_DWI_NAMES[@]}; do
 if [ "${FIRST_NAME2}" != "$j" ]; then
    TEMP_DWI_FILES+=(${j}_dwi.nii.gz)
  fi
done
for j in ${ALL_SCRATCH_NAMES[@]}; do
 if [ "${FIRST_NAME3}" != "$j" ]; then
    TEMP_B0_ACQ_FILES+=(${j}_B0sAcqParams.txt)
  fi
done

fslmerge -t ${DIR_SAVE}/All_B0s.nii.gz ${FIRST_NAME}_b0.nii.gz ${TEMP_B0_FILES[@]}
fslmerge -t ${DIR_SAVE}/All_dwis.nii.gz ${FIRST_NAME2}_dwi.nii.gz ${TEMP_DWI_FILES[@]}

cat ${FIRST_NAME3}_B0sAcqParams.txt ${TEMP_B0_ACQ_FILES[@]} >> ${DIR_SAVE}/All_B0sAcqParams.txt

chgrp -R ${GROUP} ${DIR_SAVE} > /dev/null 2>&1
chmod -R g+rw ${DIR_SAVE} > /dev/null 2>&1

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

