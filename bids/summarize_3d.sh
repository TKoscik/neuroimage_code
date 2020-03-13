#!/bin/bash -e

#===============================================================================
# Summarize 3-dimensional images based on labelled ROIs
# Authors: Timothy R. Koscik. PhD
# Date: 2020-03-09
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvla --long group:,prefix:,\
label:,value:,stats:,no-append,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,dry-run,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
LABEL=
VALUE=NULL
STATS=
NO_APPEND=false
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
DRY_RUN=false
VERBOSE=0
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -a | --no-append) NO_APPEND=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --label) LABEL="$2" ; shift 2 ;;
    --value) VALUE="$2" ; shift 2 ;;
    --stats) STATS="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
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
  echo 'Author: Timothy R. Koscik, PhD'
  echo 'Date:   <<date of authorship>>'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -c | --dry-run           test run of function'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --label <value>          file path to label to generate stats for.'
  echo '                           Only one label file per function call allowed.'
  echo '                           Label and Value files are assumed to be'
  echo '                           registered, however they do not have to have'
  echo '                           the same spacing. Label maps will be resampled'
  echo '                           to match the spacing of value maps as needed'
  echo '  --value <value>          file path to NIfTI file containing the values'
  echo '                           to summarize, omit if only volumes are desired.'
  echo '  --stats <value>          Image statistics to include in summary.'
  echo '                           If value file not given (or if value and'
  echo '                           label files are the same, only volumes will be given)'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: DIR_PROJECT/summary'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo "                           default: ${DIR_NIMGCORE}"
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo "                           default: ${DIR_PINCSOURCE}"
  echo ''
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/summary
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#===============================================================================
# Start of Function
#===============================================================================
if [ -z ${STATS} ]; then
  STATS="voxels,volume,mean,std,cog,5%,95%,min,max,entropy"
fi
STATS=(${STATS//,/ })
NUM_STATS=${#STATS[@]}

if [[ "${VALUE}" == "NULL" ]]; then
  VALUE=${LABEL}
  STATS=("volume")
fi
DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${VALUE[0]}`

# Load lookup table for labels
LABEL_NAME=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${LABEL} -f "label"`)
LUT=${DIR_NIMGCORE}/code/lut/lut-${LABEL_NAME}.csv
while IFS=$',\r' read -r a b c;
do
  LABEL_VALUE+=(${a})
  LABEL_ACRONYM+=(${b})
  LABEL_TEXT+=(${c})
done < ${LUT}
NUM_LABEL=${#LABEL_VALUE[@]}

if [[ "${VALUE}" == "${LABEL}" ]]; then
  # Assuming subject specific labels
  SUBJECT=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${LABEL} -f "sub"`)
  SESSION=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${LABEL} -f "ses"`)
  MOD="volume"
else
  # Assuming labels apply to all inputs,
  # inputs must be coregistered, but not necessarily the same spacing
  SUBJECT=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${VALUE} -f "sub"`)
  SESSION=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${VALUE} -f "ses"`)
  IFS=x read -r -a pixdim <<< $(PrintHeader ${VALUE} 1)

  # Resample label to match value file
  LABEL_ORIG=${LABEL}
  IFS=x read -r -a pixdim_label <<< $(PrintHeader ${LABEL_ORIG} 1)
  if [[ "${pixdim[0]}" != "${pixdim_label[0]}" ]] || [[ "${pixdim[1]}" != "${pixdim_label[1]}" ]] || [[ "${pixdim[2]}" != "${pixdim_label[2]}" ]]; then
    LABEL=${DIR_SCRATCH}/sub-${SUBJECT}_ses-${SESSION}_label-${LABEL_NAME}.nii.gz
    antsApplyTransforms -d 3 -n NearestNeighbor \
      -i ${LABEL_ORIG} -o ${LABEL} -r ${VALUE}
  else
    LABEL=${LABEL_ORIG}
  fi
  MOD=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${VALUE} -f "modality"`
fi
  
# initialize temporary file for output
OUTPUT=${DIR_SCRATCH}/output.txt
DATE_WRITE=$(date +%Y-%m-%dT%H:%M:%S)
for (( k=0; k<${NUM_STATS}; k ++ )); do
  echo ${SUBJECT} >> ${DIR_SCRATCH}/sub.txt
  echo ${SESSION} >> ${DIR_SCRATCH}/ses.txt
  echo ${DATE_WRITE} >> ${DIR_SCRATCH}/date.txt
  echo ${STATS[${k}]} >> ${DIR_SCRATCH}/stats.txt
done
paste -d , ${DIR_SCRATCH}/sub.txt ${DIR_SCRATCH}/ses.txt ${DIR_SCRATCH}/date.txt ${DIR_SCRATCH}/stats.txt > ${OUTPUT}

# get stats
for (( j=1; j<${NUM_LABEL}; j++ )); do
  temp_mask=${DIR_SCRATCH}/roi_temp.nii.gz
  fslmaths ${LABEL} -thr ${LABEL_VALUE[${j}]} -uthr ${LABEL_VALUE[${j}]} -bin ${temp_mask}
  for (( k=0; k<${NUM_STATS}; k++ )); do
    if [[ "${STATS[${k}],,}" == "voxels" ]]; then
      temp=(`fslstats ${VALUE} -k ${temp_mask} -v`)
      echo ${volume[0]} >> ${DIR_SCRATCH}/temp.txt
    fi
    if [[ "${STATS[${k}],,}" == "volume" ]]; then
      volume=(`fslstats ${VALUE} -k ${temp_mask} -v`)
      echo ${volume[1]} >> ${DIR_SCRATCH}/temp.txt
    fi
    if [[ "${STATS[${k}],,}" == "mean" ]]; then
      fslstats ${VALUE} -k ${temp_mask} -m >> ${DIR_SCRATCH}/temp.txt
    fi
    if [[ "${STATS[${k}],,}" == "std" ]]; then
      fslstats ${VALUE} -k ${temp_mask} -s >> ${DIR_SCRATCH}/temp.txt
    fi
    if [[ "${STATS[${k}],,}" == "cog" ]]; then
      temp=(`fslstats ${VALUE} -k ${temp_mask} -c`)
      echo "(${temp[0]} ${temp[1]} ${temp[2]})" >> ${DIR_SCRATCH}/temp.txt
    fi
    last_char=${STATS[${k}]: -1}
    if [[ "${STATS[${k}]: -1}" == "%"  ]]; then
      fslstats ${VALUE} -k ${temp_mask} -p ${STATS[${k}]::-1} >> ${DIR_SCRATCH}/temp.txt
    fi
    if [[ "${STATS[${k}],,}" == "min" ]]; then
      temp=(`fslstats ${VALUE} -k ${temp_mask} -R`)
      echo ${temp[0]} >> ${DIR_SCRATCH}/temp.txt
    fi
    if [[ "${STATS[${k}],,}" == "max" ]]; then
      temp=(`fslstats ${VALUE} -k ${temp_mask} -R`)
      echo ${temp[1]} >> ${DIR_SCRATCH}/temp.txt
    fi
    if [[ "${STATS[${k}],,}" == "entropy" ]]; then
      fslstats ${VALUE} -k ${temp_mask} -e >> ${DIR_SCRATCH}/temp.txt
    fi
  done
  paste -d , ${OUTPUT} ${DIR_SCRATCH}/temp.txt >> ${DIR_SCRATCH}/cat.txt
  mv ${DIR_SCRATCH}/cat.txt ${OUTPUT}
  rm ${DIR_SCRATCH}/temp.txt
done

# Check if summary file exists and create if not
mkdir -p ${DIR_PROJECT}/summary
PROJECT=`${DIR_NIMGCORE}/code/bids/get_project.sh -i ${VALUE}`
SUMMARY_FILE=${DIR_PROJECT}/summary/${PROJECT}_${MOD}_label-${LABEL_NAME}.csv
if [[ ! -f ${SUMMARY_FILE} ]]; then
  LABEL_TEMP="${LABEL_ACRONYM[@]:1}"
  HEADER=("participant_id" "session_id" "summary_date" "measure" "${LABEL_TEMP}")
  HEADER="${HEADER[@]}"
  echo ${HEADER// /,} >> ${SUMMARY_FILE}
fi

# append to summary file or save output .txt if not
if [[ "${NO_APPEND}" == "false" ]]; then
  cat ${OUTPUT} >> ${SUMMARY_FILE}
else
  DIR_SAVE=${DIR_PROJECT}/summary/${MOD}_label-${LABEL_NAME}
  mkdir -p ${DIR_SAVE}
  mv ${OUTPUT} ${DIR_SAVE}/sub-${SUBJECT}_${SESSION}_${MOD}_label-${LABEL_NAME}_${DATE_SUFFIX}.txt
fi

#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi
