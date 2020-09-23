#!/bin/bash
#===============================================================================
# Calculate Myelin Map
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-12
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
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
OPTS=`getopt -o hvl --long prefix:,\
t1:,t2:,\
dir-save:,dir-scratch:,dir-code:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
T1=
T2=
ROI=NULL
ROI_VAL=1,2
N_BINS=100
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --t1) T1="$2" ; shift 2 ;;
    --t2) T2="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --t1 <value>             T1-weighted image'
  echo '  --t2 <value>             T2-weighted image'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${DIR_PROJECT}/derivatives/anat/myelin_${SPACE}'
  echo '                           Space will be drawn from folder name,'
  echo '                           e.g., native = native'
  echo '                                 reg_${TEMPLATE}_${SPACE}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo ''
  NO_LOG=true
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_CODE}/bids/get_dir.sh -i ${T1})
SUBJECT=$(${DIR_CODE}/bids/get_field.sh -i ${T1} -f "sub")
SESSION=$(${DIR_CODE}/bids/get_field.sh -i ${T1} -f "ses")
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

# Check that images are coregistered, i.e., contain same "reg" flag
T1_SPACE=$(${DIR_CODE}/bids/get_space_label.sh -i ${T1})
T2_SPACE=$(${DIR_CODE}/bids/get_space_label.sh -i ${T2})
if [[ "${T1_SPACE}" != "${T2_SPACE}" ]]; then
  echo "T1w and T2w not in same space, aborting"
  exit 1
fi
TEMP=(${T1_SPACE//,/ })
TEMPLATE=${TEMP[0]}
SPACE=${TEMP[1]}

# Check if ROI map exists
if [[ "${ROI}" == "NULL" ]]; then
  ROI=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_label-normMyelin.nii.gz
  ROI_VAL=(${ROI_VAL//,/ })
  if [[ ! -f ${ROI} ]]; then
    echo "ROI file does not exist, please create appropriate ROI labels"
    exit 1
  fi
fi

# create save directory
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/myelin_${TEMPLATE}+${SPACE}
fi
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_SCRATCH}

# Copy images to scratch, for manipulation
cp ${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T1w.nii.gz \
  ${DIR_SCRATCH}/norm_T1w.nii.gz
cp ${DIR_TEMPLATE}/${TEMPLATE}/${SPACE}/${TEMPLATE}_${SPACE}_T2w.nii.gz \
  ${DIR_SCRATCH}/norm_T2w.nii.gz
cp ${T1} ${DIR_SCRATCH}/sub_T1w.nii.gz
cp ${T2} ${DIR_SCRATCH}/sub_T2w.nii.gz

# Truncate image intensity to 98%
ImageMath 3 ${DIR_SCRATCH}/norm_T1w.nii.gz TruncateImageIntensity ${DIR_SCRATCH}/norm_T1w.nii.gz 0 0.98 100
ImageMath 3 ${DIR_SCRATCH}/norm_T2w.nii.gz TruncateImageIntensity ${DIR_SCRATCH}/norm_T2w.nii.gz 0 0.98 100
ImageMath 3 ${DIR_SCRATCH}/sub_T1w.nii.gz TruncateImageIntensity ${DIR_SCRATCH}/sub_T1w.nii.gz 0 0.98 100
ImageMath 3 ${DIR_SCRATCH}/sub_T2w.nii.gz TruncateImageIntensity ${DIR_SCRATCH}/sub_T2w.nii.gz 0 0.98 100

# remove negative values
fslmaths ${DIR_SCRATCH}/norm_T1w.nii.gz -thr 0 ${DIR_SCRATCH}/norm_T1w.nii.gz
fslmaths ${DIR_SCRATCH}/norm_T2w.nii.gz -thr 0 ${DIR_SCRATCH}/norm_T2w.nii.gz
fslmaths ${DIR_SCRATCH}/sub_T1w.nii.gz -thr 0 ${DIR_SCRATCH}/sub_T1w.nii.gz
fslmaths ${DIR_SCRATCH}/sub_T2w.nii.gz -thr 0 ${DIR_SCRATCH}/sub_T2w.nii.gz

# convert to unsigned short (UINT16), and stretch range of data to fill dynamic range of numeric type
ConvertImagePixelType ${DIR_SCRATCH}/norm_T1w.nii.gz ${DIR_SCRATCH}/norm_T1w.nii.gz 3
ConvertImagePixelType ${DIR_SCRATCH}/norm_T2w.nii.gz ${DIR_SCRATCH}/norm_T2w.nii.gz 3
ConvertImagePixelType ${DIR_SCRATCH}/sub_T1w.nii.gz ${DIR_SCRATCH}/sub_T1w.nii.gz 3
ConvertImagePixelType ${DIR_SCRATCH}/sub_T2w.nii.gz ${DIR_SCRATCH}/sub_T2w.nii.gz 3

# Convert back to float for math
ConvertImage 3 ${DIR_SCRATCH}/norm_T1w.nii.gz ${DIR_SCRATCH}/norm_T1w.nii.gz 0
ConvertImage 3 ${DIR_SCRATCH}/norm_T2w.nii.gz ${DIR_SCRATCH}/norm_T2w.nii.gz 0
ConvertImage 3 ${DIR_SCRATCH}/sub_T1w.nii.gz ${DIR_SCRATCH}/sub_T1w.nii.gz 0
ConvertImage 3 ${DIR_SCRATCH}/sub_T2w.nii.gz ${DIR_SCRATCH}/sub_T2w.nii.gz 0

# normalize intensity values
NORM_MINMAX=($(fslstats -K ${ROI} ${DIR_SCRATCH}/norm_T1w.nii.gz -R))
TEMP_HIST=($(fslstats -K ${ROI} ${DIR_SCRATCH}/norm_T1w.nii.gz -h ${N_BINS}))
NORM_HIST=(${TEMP_HIST[@]//.000000/})
NORM_X=(${NORM_HIST[@]:0:100})
STEP_SIZE=$(echo ${NORM_MINMAX[1]} - ${NORM_MINMAX[0]} | bc -l)
STEP_SIZE=$(echo ${STEP_SIZE} / ${N_BINS} | bc -l)
T1_NORM_MODE_X=${STEP_SIZE}
TEMP_MAX=${NORM_X[0]}
for (( i=1; i<${#NORM_X[@]}; i++ )); do
  if [[ ${NORM_X[${i}]} -gt ${TEMP_MAX} ]]; then
    T1_NORM_MODE_X=$(echo ${STEP_SIZE} \* ${i} | bc -l)
    TEMP_MAX=${NORM_X[${i}]}
  fi
done
NORM_Y=(${NORM_HIST[@]:100:100})
STEP_SIZE=$(echo ${NORM_MINMAX[3]} - ${NORM_MINMAX[2]} | bc -l)
STEP_SIZE=$(echo ${STEP_SIZE} / ${N_BINS} | bc -l)
T1_NORM_MODE_Y=${STEP_SIZE}
TEMP_MAX=${NORM_Y[0]}
for (( i=1; i<${#NORM_Y[@]}; i++ )); do
  if [[ ${NORM_Y[${i}]} -gt ${TEMP_MAX} ]]; then
    T1_NORM_MODE_Y=$(echo ${STEP_SIZE} \* ${i} | bc -l)
    TEMP_MAX=${NORM_Y[${i}]}
  fi
done

NORM_MINMAX=($(fslstats -K ${ROI} ${DIR_SCRATCH}/norm_T2w.nii.gz -R))
TEMP_HIST=($(fslstats -K ${ROI} ${DIR_SCRATCH}/norm_T2w.nii.gz -h ${N_BINS}))
NORM_HIST=(${TEMP_HIST[@]//.000000/})
NORM_X=(${NORM_HIST[@]:0:100})
STEP_SIZE=$(echo ${NORM_MINMAX[1]} - ${NORM_MINMAX[0]} | bc -l)
STEP_SIZE=$(echo ${STEP_SIZE} / ${N_BINS} | bc -l)
T2_NORM_MODE_X=${STEP_SIZE}
TEMP_MAX=${NORM_X[0]}
for (( i=1; i<${#NORM_X[@]}; i++ )); do
  if [[ ${NORM_X[${i}]} -gt ${TEMP_MAX} ]]; then
    T2_NORM_MODE_X=$(echo ${STEP_SIZE} \* ${i} | bc -l)
    TEMP_MAX=${NORM_X[${i}]}
  fi
done
NORM_Y=(${NORM_HIST[@]:100:100})
STEP_SIZE=$(echo ${NORM_MINMAX[3]} - ${NORM_MINMAX[2]} | bc -l)
STEP_SIZE=$(echo ${STEP_SIZE} / ${N_BINS} | bc -l)
T2_NORM_MODE_Y=${STEP_SIZE}
TEMP_MAX=${NORM_Y[0]}
for (( i=1; i<${#NORM_Y[@]}; i++ )); do
  if [[ ${NORM_Y[${i}]} -gt ${TEMP_MAX} ]]; then
    T2_NORM_MODE_Y=$(echo ${STEP_SIZE} \* ${i} | bc -l)
    TEMP_MAX=${NORM_Y[${i}]}
  fi
done

SUB_MINMAX=($(fslstats -K ${ROI} ${DIR_SCRATCH}/sub_T1w.nii.gz -R))
TEMP_HIST=($(fslstats -K ${ROI} ${DIR_SCRATCH}/sub_T1w.nii.gz -h ${N_BINS}))
SUB_HIST=(${TEMP_HIST[@]//.000000/})
SUB_X=(${SUB_HIST[@]:0:100})
STEP_SIZE=$(echo ${SUB_MINMAX[1]} - ${SUB_MINMAX[0]} | bc -l)
STEP_SIZE=$(echo ${STEP_SIZE} / ${N_BINS} | bc -l)
T1_SUB_MODE_X=${STEP_SIZE}
TEMP_MAX=${SUB_X[0]}
for (( i=1; i<${#SUB_X[@]}; i++ )); do
  if [[ ${SUB_X[${i}]} -gt ${TEMP_MAX} ]]; then
    T1_SUB_MODE_X=$(echo ${STEP_SIZE} \* ${i} | bc -l)
    TEMP_MAX=${SUB_X[${i}]}
  fi
done
SUB_Y=(${SUB_HIST[@]:100:100})
STEP_SIZE=$(echo ${SUB_MINMAX[3]} - ${SUB_MINMAX[2]} | bc -l)
STEP_SIZE=$(echo ${STEP_SIZE} / ${N_BINS} | bc -l)
T1_SUB_MODE_Y=${STEP_SIZE}
TEMP_MAX=${SUB_Y[0]}
for (( i=1; i<${#SUB_Y[@]}; i++ )); do
  if [[ ${SUB_Y[${i}]} -gt ${TEMP_MAX} ]]; then
    T1_SUB_MODE_Y=$(echo ${STEP_SIZE} \* ${i} | bc -l)
    TEMP_MAX=${SUB_Y[${i}]}
  fi
done

SUB_MINMAX=($(fslstats -K ${ROI} ${DIR_SCRATCH}/sub_T2w.nii.gz -R))
TEMP_HIST=($(fslstats -K ${ROI} ${DIR_SCRATCH}/sub_T2w.nii.gz -h ${N_BINS}))
SUB_HIST=(${TEMP_HIST[@]//.000000/})
SUB_X=(${SUB_HIST[@]:0:100})
STEP_SIZE=$(echo ${SUB_MINMAX[1]} - ${SUB_MINMAX[0]} | bc -l)
STEP_SIZE=$(echo ${STEP_SIZE} / ${N_BINS} | bc -l)
T2_SUB_MODE_X=${STEP_SIZE}
TEMP_MAX=${SUB_X[0]}
for (( i=1; i<${#SUB_X[@]}; i++ )); do
  if [[ ${SUB_X[${i}]} -gt ${TEMP_MAX} ]]; then
    T2_SUB_MODE_X=$(echo ${STEP_SIZE} \* ${i} | bc -l)
    TEMP_MAX=${SUB_X[${i}]}
  fi
done
SUB_Y=(${SUB_HIST[@]:100:100})
STEP_SIZE=$(echo ${SUB_MINMAX[3]} - ${SUB_MINMAX[2]} | bc -l)
STEP_SIZE=$(echo ${STEP_SIZE} / ${N_BINS} | bc -l)
T2_SUB_MODE_Y=${STEP_SIZE}
TEMP_MAX=${SUB_Y[0]}
for (( i=1; i<${#SUB_Y[@]}; i++ )); do
  if [[ ${SUB_Y[${i}]} -gt ${TEMP_MAX} ]]; then
    T2_SUB_MODE_Y=$(echo ${STEP_SIZE} \* ${i} | bc -l)
    TEMP_MAX=${SUB_Y[${i}]}
  fi
done

## scale T1
M1=$(echo ${T1_NORM_MODE_X} - ${T1_NORM_MODE_Y} |bc -l)
M2=$(echo ${T1_SUB_MODE_X} - ${T1_SUB_MODE_Y} |bc -l)
M=$(echo ${M1} / ${M2} | bc -l)
B1=$(echo ${T1_SUB_MODE_X} \* ${T1_NORM_MODE_Y} | bc -l)
B2=$(echo ${T1_NORM_MODE_X} \* ${T1_SUB_MODE_Y} | bc -l)
B3=$(echo ${B1} - ${B2} | bc -l)
B4=$(echo ${T1_SUB_MODE_X} - ${T1_SUB_MODE_Y} | bc -l)
B=$(echo ${B3} / ${B4} | bc -l)
fslmaths ${DIR_SCRATCH}/sub_T1w.nii.gz -mul ${M} -add ${B} -thr 0 -range ${DIR_SCRATCH}/sub_T1w.nii.gz

## scale T2
M1=$(echo ${T2_NORM_MODE_X} - ${T2_NORM_MODE_Y} |bc -l)
M2=$(echo ${T2_SUB_MODE_X} - ${T2_SUB_MODE_Y} |bc -l)
M=$(echo ${M1} / ${M2} | bc -l)
B1=$(echo ${T2_SUB_MODE_X} \* ${T2_NORM_MODE_Y} | bc -l)
B2=$(echo ${T2_NORM_MODE_X} \* ${T2_SUB_MODE_Y} | bc -l)
B3=$(echo ${B1} - ${B2} | bc -l)
B4=$(echo ${T2_SUB_MODE_X} - ${T2_SUB_MODE_Y} | bc -l)
B=$(echo ${B3} / ${B4} | bc -l)
fslmaths ${DIR_SCRATCH}/sub_T2w.nii.gz -mul ${M} -add ${B} -thr 0 -range ${DIR_SCRATCH}/sub_T2w.nii.gz

fslmaths -dt float ${DIR_SCRATCH}/sub_T1w.nii.gz -div ${DIR_SCRATCH}/sub_T2w.nii.gz ${DIR_SCRATCH}/myelin.nii.gz -odt float

ImageMath 3 ${DIR_SCRATCH}/T2inv.nii.gz ^ ${T2} -1
ImageMath 3 ${DIR_SAVE}/${PREFIX}_reg-${TEMPLATE}+${SPACE}_myelin.nii.gz m ${T1} ${DIR_SCRATCH}/T2inv.nii.gz

#==============================================================================
# End of function
#==============================================================================
exit 0

