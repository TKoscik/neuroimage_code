#!/bin/bash -e

#===============================================================================
# Find acquisition parameters for DWI files
# Authors: Josh Cochran
# Date: 3/30/2020
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
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
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
OPTS=`getopt -o hvl --long group:,prefix:,\
dir-dwi:,dir-code:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
DIR_DWI=
DIR_CODE=/Shared/inc_scratch/code
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
    --dir-dwi) DIR_DWI="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
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
  echo '  --dir-dwi <value>        location of the raw DWI data'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-code <value>       top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
anyfile=(`ls ${DIR_DWI}/sub*.nii.gz`)
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${anyfile[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

#==============================================================================
# AcqParams + All bvec, bval, index + Merge files for All_B0 and All_dwi
#==============================================================================

#remove old files
if [[ -f ${DIR_DWI}/${PREFIX}_dwisAcqParams.txt ]]; then
  rm ${DIR_DWI}/${PREFIX}_dwisAcqParams.txt
fi
if [[ -f ${DIR_DWI}/${PREFIX}_B0sAcqParams.txt ]]; then
  rm ${DIR_DWI}/${PREFIX}_B0sAcqParams.txt
fi
if [[ -f ${DIR_DWI}/${PREFIX}.bvec ]]; then
  rm ${DIR_DWI}/${PREFIX}.bvec
fi
if [[ -f ${DIR_DWI}/${PREFIX}.bval ]]; then
  rm ${DIR_DWI}/${PREFIX}.bval
fi
if [[ -f ${DIR_DWI}/${PREFIX}_index.txt ]]; then
  rm ${DIR_DWI}/${PREFIX}_index.txt
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

touch ${DIR_DWI}/${PREFIX}_dwisAcqParams.txt

#loop through DWI files to pull out info
for i in ${DIR_DWI}/*_dwi.nii.gz; do
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

  echo "0 ${PED} 0 ${READOUT_TIME}" >> ${DIR_DWI}/${PREFIX}_dwisAcqParams.txt
  ACQ_LINE=$(echo "${ACQ_LINE} + 1" | bc -l)

  touch ${DIR_DWI}/${NAME_BASE}_B0sAcqParams.txt
  for j in "${B0s[@]}"; do
    k=$(echo "($j+0.5)/1" | bc)
    if [ $k -eq 0 ]; then
      echo "0 ${PED} 0 ${READOUT_TIME}" >> ${DIR_DWI}/${NAME_BASE}_B0sAcqParams.txt
    fi
  done
  ALL_DWI_NAMES+=(${DIR_DWI}/${NAME_BASE})
  ALL_HOME_DWI_NAMES+=(${DTI_NAME})
  ALL_SCRATCH_NAMES+=(${DIR_DWI}/${NAME_BASE})
done

echo $INDX > ${DIR_DWI}/${PREFIX}_index.txt
echo $TOTAL_BVALS > ${DIR_DWI}/${PREFIX}.bval
echo $TOTAL_XVALS > ${DIR_DWI}/XVals.txt
echo $TOTAL_YVALS > ${DIR_DWI}/YVals.txt
echo $TOTAL_ZVALS > ${DIR_DWI}/ZVals.txt
cat ${DIR_DWI}/XVals.txt ${DIR_DWI}/YVals.txt ${DIR_DWI}/ZVals.txt >> ${DIR_DWI}/${PREFIX}.bvec

FIRST_NAME=${ALL_DWI_NAMES[0]}
FIRST_NAME2=${ALL_HOME_DWI_NAMES[0]}
FIRST_NAME3=${ALL_SCRATCH_NAMES[0]}

unset TEMP_B0_FILES TEMP_B0_ACQ_FILES TEMP_DWI_FILES
declare -a TEMP_B0_FILES
declare -a TEMP_B0_ACQ_FILES
declare -a TEMP_DWI_FILES

for j in ${ALL_DWI_NAMES[@]}; do
  if [ "${FIRST_NAME}" != "$j" ]; then
    TEMP_B0_FILES+=(${j}_dwi_B0+raw.nii.gz)
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

fslmerge -t ${DIR_DWI}/${PREFIX}_B0s+raw.nii.gz ${FIRST_NAME}_dwi_B0+raw.nii.gz ${TEMP_B0_FILES[@]}
fslmerge -t ${DIR_DWI}/${PREFIX}_dwis.nii.gz ${FIRST_NAME2}_dwi.nii.gz ${TEMP_DWI_FILES[@]}

cat ${FIRST_NAME3}_B0sAcqParams.txt ${TEMP_B0_ACQ_FILES[@]} >> ${DIR_DWI}/${PREFIX}_B0sAcqParams.txt


#------------------------------------------------------------------------------
# End of Function
#------------------------------------------------------------------------------

exit 0

