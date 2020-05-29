#!/bin/bash -e

#===============================================================================
# Summarize 3-dimensional images based on labelled ROIs
# Authors: Timothy R. Koscik. PhD
# Date: 2020-03-09
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
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
    if [[ -v DIR_PROJECT ]]; then
      PROJECT_LOG=${DIR_PROJECT}/log/${PREFIX}.log
      if [[ ! -f ${PROJECT_LOG} ]]; then
        echo -e 'operator\tfunction\tstart\tend\texit_status' > ${PROJECT_LOG}
      fi
      echo -e ${LOG_STRING} >> ${PROJECT_LOG}
    fi
  fi
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvlsa --long group:,prefix:,\
label:,value:,stats:,do-sum,no-append,\
dir-save:,dir-scratch:,dir-code:,dir-pincsource:,\
help,dry-run,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
GROUP=
LABEL=
VALUE=NULL
STATS=
DO_SUM=false
NO_APPEND=false
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

IFS=$' \t\n'
while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -s | --do-sum) DO_SUM=true ; shift ;;
    -a | --no-append) NO_APPEND=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --label) LABEL+="$2" ; shift 2 ;;
    --value) VALUE="$2" ; shift 2 ;;
    --stats) STATS="$2" ; shift 2 ;;
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
  echo '                           Multiple inputs should be a comma separated'
  echo '                           string. Secondary inputs will be used as'
  echo '                           subset masks for each ROI, e.g., fontal left wm'
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
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo "                           default: ${DIR_PINCSOURCE}"
  echo ''
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)
mkdir -p ${DIR_SCRATCH}

#===============================================================================
# Start of Function
#===============================================================================
LABEL_TEMP=(${LABEL//,/ })
unset LABEL
LABEL=(${LABEL_TEMP[@]})
NUM_SET=${#LABEL[@]}

if [ -z ${STATS} ]; then
  STATS="voxels,volume,mean,std,cog,5%,95%,min,max,entropy"
fi
if [[ "${VALUE}" == "NULL" ]]; then
  unset STATS
  STATS=("volume")
fi
STATS=(${STATS//,/ })
NUM_STATS=${#STATS[@]}

# Load lookup table for labels
for (( i=0; i<${NUM_SET}; i++ )); do
  LABEL_NAME+=(`${DIR_CODE}/bids/get_field.sh -i ${LABEL[${i}]} -f "label"`)
  LUT=${DIR_CODE}/lut/lut-${LABEL_NAME[${i}]}.tsv
  unset temp_value temp_label
  temp_value=""
  temp_label=""
  while IFS=$',\r' read -r a b;
  do
    if [[ "${a}" != "value" ]]; then
      temp_value="${temp_value},${a}"
      temp_label="${temp_label},${b}"
    fi
  done < ${LUT}
  LABEL_VALUE+=(${temp_value:1})
  LABEL_LABEL+=(${temp_label:1})
done

if [[ "${VALUE}" == "NULL" ]]; then
  # Assuming subject specific labels
  SUBJECT=(`${DIR_CODE}/bids/get_field.sh -i ${LABEL[0]} -f "sub"`)
  SESSION=(`${DIR_CODE}/bids/get_field.sh -i ${LABEL[0]} -f "ses"`)
  MOD="volume"
else
  # Assuming labels apply to all inputs,
  # inputs must be coregistered, but not necessarily the same spacing
  SUBJECT=(`${DIR_CODE}/bids/get_field.sh -i ${VALUE} -f "sub"`)
  SESSION=(`${DIR_CODE}/bids/get_field.sh -i ${VALUE} -f "ses"`)
  IFS=x read -r -a pixdim <<< $(PrintHeader ${VALUE} 1)

  # Resample label to match value file
  LABEL_ORIG=(${LABEL[@]})
  for (( i=0; i<${NUM_SET}; i++ )); do
    IFS=x read -r -a pixdim_label <<< $(PrintHeader ${LABEL_ORIG[${i}]} 1)
    if [[ "${pixdim[0]}" != "${pixdim_label[0]}" ]] || [[ "${pixdim[1]}" != "${pixdim_label[1]}" ]] || [[ "${pixdim[2]}" != "${pixdim_label[2]}" ]]; then
      LABEL[${i}]=${DIR_SCRATCH}/sub-${SUBJECT}_ses-${SESSION}_label-${LABEL_NAME[${i}]}.nii.gz
      antsApplyTransforms -d 3 -n NearestNeighbor \
        -i ${LABEL_ORIG} -o ${LABEL[${i}]} -r ${VALUE}
    fi
  done
  MOD=`${DIR_CODE}/bids/get_field.sh -i ${VALUE} -f "modality"`
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
paste -d "," ${DIR_SCRATCH}/sub.txt ${DIR_SCRATCH}/ses.txt ${DIR_SCRATCH}/date.txt ${DIR_SCRATCH}/stats.txt > ${OUTPUT}

# sub-parcellate each roi by included additional labels
perm_fcn="echo "
for (( i=0; i<${NUM_SET}; i++ )); do
  temp=(${LABEL_VALUE[${i}]//,/ })
  if [[ "${i}" > "0" ]]; then
    perm_fcn="${perm_fcn},"
  fi
  if [[ "${DO_SUM}" == "true" ]]; then
    count_start=0
  else
    if [[ "${i}" == "0" ]]; then
      count_start=1
    else
      count_start=0
    fi
  fi
  perm_fcn="${perm_fcn}{${count_start}..${#temp[@]}}"
done
PERM=(`eval ${perm_fcn}`)
NUM_PERM=${#PERM[@]}

temp_mask=${DIR_SCRATCH}/temp_mask.nii.gz
roi_mask=${DIR_SCRATCH}/roi_mask.nii.gz
unset HEADER
HEADER=""
for (( i=0; i<${NUM_PERM}; i++ )); do
  WHICH_LABEL=(${PERM[${i}]//,/ })
  fslmaths ${LABEL[0]} -mul 0 -add 1 ${roi_mask}
  unset hdr_temp
  hdr_temp=""
  # load labels
  for (( j=0; j<${NUM_SET}; j++ )); do
    if [[ "${WHICH_LABEL[${j}]}" == 0 ]]; then
      # if value is zero use all labels in given mask
      # (will exclude non-overlapping portions betwen masks)
      fslmaths ${LABEL[${j}]} -bin ${temp_mask}
      fslmaths ${roi_mask} -mas ${temp_mask} ${roi_mask}

      # write header value for output, only out put header
      # label for base label set
      if [[ "${j}" == "0" ]]; then 
        temp="${LABEL[${j}]##*+}"
        temp=$(echo "${temp}" | cut -f 1 -d '.')
        hdr_temp="${hdr_temp}${temp}"
      fi
    else
      # create and use ROI mask
      unset temp_value
      temp_value=NULL
      temp_value+=(${LABEL_VALUE[${j}]//,/ })
      fslmaths ${LABEL[${j}]} -thr ${temp_value[${WHICH_LABEL[${j}]}]} -uthr ${temp_value[${WHICH_LABEL[${j}]}]} -bin ${temp_mask}
      fslmaths ${roi_mask} -mas ${temp_mask} ${roi_mask}
      
      # append to header label
      if [[ "${j}" > "0" ]]; then
        hdr_temp="${hdr_temp}_"
      fi
      unset temp_label
      temp_label=NULL
      temp_label+=(${LABEL_LABEL[${j}]//,/ })
      hdr_temp="${hdr_temp}${temp_label[${WHICH_LABEL[${j}]}]}"
    fi
  done
  HEADER="${HEADER},${hdr_temp}"
  
  # Check ROI for all zero
  MINMAX=(`fslstats ${roi_mask} -R`)
  if [[ "${MINMAX[1]}" == "0.000000" ]]; then
    for (( k=0; k<${NUM_STATS}; k++ )); do
      echo "NA" >> ${DIR_SCRATCH}/temp.txt
    done
  else
    # use mask to calculate stats for label set
    for (( k=0; k<${NUM_STATS}; k++ )); do
      if [[ "${STATS[${k}],,}" == "voxels" ]]; then
        temp=(`fslstats ${roi_mask} -k ${roi_mask} -v`)
        echo ${volume[0]} >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}],,}" == "volume" ]]; then
        volume=(`fslstats ${roi_mask} -k ${roi_mask} -v`)
        echo ${volume[1]} >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}],,}" == "mean" ]]; then
        fslstats ${VALUE} -k ${roi_mask} -m >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}],,}" == "std" ]]; then
        fslstats ${VALUE} -k ${roi_mask} -s >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}],,}" == "cog" ]]; then
        temp=(`fslstats ${VALUE} -k ${roi_mask} -c`)
        echo "(${temp[0]} ${temp[1]} ${temp[2]})" >> ${DIR_SCRATCH}/temp.txt
      fi
      last_char=${STATS[${k}]: -1}
      if [[ "${STATS[${k}]: -1}" == "%"  ]]; then
        fslstats ${VALUE} -k ${roi_mask} -p ${STATS[${k}]::-1} >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}],,}" == "min" ]]; then
        temp=(`fslstats ${VALUE} -k ${roi_mask} -R`)
        echo ${temp[0]} >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}],,}" == "max" ]]; then
        temp=(`fslstats ${VALUE} -k ${roi_mask} -R`)
        echo ${temp[1]} >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}],,}" == "entropy" ]]; then
        fslstats ${VALUE} -k ${roi_mask} -e >> ${DIR_SCRATCH}/temp.txt
      fi
    done
  fi
  paste -d "," ${OUTPUT} ${DIR_SCRATCH}/temp.txt >> ${DIR_SCRATCH}/cat.txt
  mv ${DIR_SCRATCH}/cat.txt ${OUTPUT}
  rm ${DIR_SCRATCH}/temp.txt
  rm ${roi_mask}
  rm ${temp_mask}
done

# get label name, e.g., baw+basalGanglia+hemi+tissue
NAME_TEMP=""
for (( i=0; i<${NUM_SET}; i++ )); do
  if [[ "${i}" == "0" ]]; then
    NAME_TEMP="${NAME_TEMP}${LABEL_NAME[${i}]}"
  else
    NAME_TEMP="${NAME_TEMP}+${LABEL_NAME[${i}]##*+}"
  fi
done
LABEL_NAME=${NAME_TEMP}

# Setup save directories
if [[ "${VALUE}" == "NULL" ]]; then
  DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${LABEL[0]}`
  PROJECT=`${DIR_CODE}/bids/get_project.sh -i ${LABEL[0]}`
else
  DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${VALUE}`
  PROJECT=`${DIR_CODE}/bids/get_project.sh -i ${VALUE}`
fi
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/summary
fi
mkdir -p ${DIR_SAVE}
SUMMARY_FILE=${DIR_SAVE}/${PROJECT}_${MOD}_label-${LABEL_NAME}.csv

# Check if summary file exists and create if not
HEADER="participant_id,session_id,summary_date,measure${HEADER}"
if [[ ! -f ${SUMMARY_FILE} ]]; then
  echo ${HEADER} >> ${SUMMARY_FILE}
fi

# append to summary file or save output .txt if not
if [[ "${NO_APPEND}" == "false" ]]; then
  cat ${OUTPUT} >> ${SUMMARY_FILE}
else
  DIR_SAVE_SUB=${DIR_PROJECT}/summary/${MOD}_label-${LABEL_NAME}
  mkdir -p ${DIR_SAVE_SUB}
  echo ${HEADER} > ${DIR_SAVE_SUB}/sub-${SUBJECT}_${SESSION}_${MOD}_label-${LABEL_NAME}_${DATE_SUFFIX}.tsv
  echo ${OUTPUT} >> ${DIR_SAVE_SUB}/sub-${SUBJECT}_${SESSION}_${MOD}_label-${LABEL_NAME}_${DATE_SUFFIX}.tsv
fi 

#===============================================================================
# End of Function
#===============================================================================
exit 0
