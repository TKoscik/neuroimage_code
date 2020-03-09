#!/bin/bash -e

#===============================================================================
# Summarize 3-dimensional images based on labelled ROIs
# Authors: Timothy R. Koscik. PhD
# Date: 2020-03-09
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvln --long group:,prefix:,\
label:,value:,which-stats:,normal-label,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,dry-run,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S)
GROUP=
LABEL=
VALUE=
STATS=("volume" "mean" "std" "cog" "5%" "95%" "min" "max" "entropy")
NORMAL=false
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
    --group) GROUP="$2" ; shift 2 ;;
    --label) LABEL="$2" ; shift 2 ;;
    --value) VALUE+="$2" ; shift 2 ;;
    --stats) STATS+="$2" ; shift 2 ;;
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
  echo 'Author: <<author names>>'
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
  echo '  --other-inputs <value>   other inputs necessary for function'
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

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${LABEL[0]}`
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/summary
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#===============================================================================
# Start of Function
#===============================================================================
if [[ -z ${VALUE} ]]; then
  STATS=("volume")
fi
NUM_VALUE=${#VALUE[@]}
NUM_STATS=${#STATS[@]}

# Load lookup table for labels
LABEL_NAME=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${LABEL} -f "label"`)
LUT=${DIR_NIMGCORE}/code/lut/lut-${LABEL_NAME}.csv
while IFS=$',\r' read -r a b c;
do
  LABEL_VALUE+=(${a})
  LABEL_TEXT+=(${b})
  LABEL_ACRONYM+=(${c})
done < ${LUT}
NUM_LABEL=${#LABEL_VALUE[@]}

LABEL_ORIG=${LABEL}
for (( i=0; i<${NUM_VALUE}; i++ )); do
  if [[ -z ${VALUE} ]]; do
    # Assuming subject specific labels
    SUBJECT=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${LABEL} -f "sub"`)
    SESSION=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${LABEL} -f "ses"`)
    IFS=x read -r -a pixdim <<< $(PrintHeader ${LABEL} 1)
  else
    # Assuming labels apply to all inputs,
    # inputs must be coregistered, but not necessarily the same spacing
    SUBJECT=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${VALUE[${i}]} -f "sub"`)
    SESSION=(`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${VALUE[${i}]} -f "ses"`)
    IFS=x read -r -a pixdim <<< $(PrintHeader ${VALUE[${i}]} 1)
        
    # Resample label to match value file
    IFS=x read -r -a pixdim_label <<< $(PrintHeader ${LABEL_ORIG} 1)
    if [[ "${pixdim[0]}" -ne "${pixdim_label[0]}" ]] || [[ "${pixdim[1]}" -ne "${pixdim_label[1]}" ]] || [[ "${pixdim[2]}" -ne "${pixdim_label[2]}" ]]; then
      LABEL=${DIR_SCRATCH}/sub-${SUBJECT}_ses-${SESSION}_label-${LABEL_NAME}.nii.gz
      antsApplyTransforms -d 3 -n NearestNeighbor \
        -i ${LABEL_ORIG} -o ${LABEL} -r ${VALUE[${i}]}
    else
      LABEL=${LABEL_ORIG}
    fi
  fi
  
  # initialize temporary file for output
  OUTPUT=${DIR_SCRATCH}/output.txt
  if [[ -f ${OUTPUT} ]]; then rm ${OUTPUT}; fi
  for (( k=0; k<${NUM_STATS}; k ++ )); do echo ${SUBJECT} >> ${OUTPUT}; done

  for (( k=0; k<${NUM_STATS}; k ++ )); do echo ${SESSION} >> temp.txt; done
  paste -d , ${OUTPUT} ${DIR_SCRATCH}/temp.txt > ${DIR_SCRATCH}/temp_cat.txt
  mv ${DIR_SCRATCH}/temp_cat.txt ${OUTPUT}
  rm ${DIR_SCRATCH}/temp.txt

  DATE_WRITE=$(date +%Y-%m-%dT%H:%M:%S)
  for (( k=0; k<${NUM_STATS}; k ++ )); do echo ${DATE_WRITE} >> temp.txt; done
  paste -d , ${OUTPUT} ${DIR_SCRATCH}/temp.txt > ${DIR_SCRATCH}/temp_cat.txt
  mv ${DIR_SCRATCH}/temp_cat.txt ${OUTPUT}
  rm ${DIR_SCRATCH}/temp.txt

  for (( k=0; k<${NUM_STATS}; k ++ )); do echo ${STATS[${k}]} >> temp.txt; done
  paste -d , ${OUTPUT} ${DIR_SCRATCH}/temp.txt > ${DIR_SCRATCH}/temp_cat.txt
  mv ${DIR_SCRATCH}/temp_cat.txt ${OUTPUT}
  rm ${DIR_SCRATCH}/temp.txt

  # get stats
  for (( j=1; j<=${NUM_LABEL}; j++ )); do
    temp_mask=${DIR_SCRATCH}/roi_temp.nii.gz
    fslmaths ${LABEL} -thr ${LABEL_VALUE[${j}]} -uthr ${LABEL_VALUE[${j}]} -bin ${temp_mask}
    for (( k=0; k<${NUM_STATS}; k++ )); do
      if [[ "${STATS[${k}]},," == "volume" ]]; then
        volume=`fslstats ${VALUE[${i}]} -k ${temp_mask} -v`
        volume=`echo "${volume}*${pixdim[0]}*${pixdim[1]}*${pixdim[2]}" | bc -l`
        echo ${volume} >> ${DIR_SCRATCH}/temp.txt
      fi
      ### Restart here
      if [[ "${STATS[${k}]},," == "" ]]; then
        temp=`fslstats ${VALUE[${i}]} -k ${temp_mask} -`
        echo ${temp} >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}]},," == "" ]]; then
        temp=`fslstats ${VALUE[${i}]} -k ${temp_mask} -`
        echo ${temp} >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}]},," == "" ]]; then
        temp=`fslstats ${VALUE[${i}]} -k ${temp_mask} -`
        echo ${temp} >> ${DIR_SCRATCH}/temp.txt
      fi
      if [[ "${STATS[${k}]},," == "" ]]; then
        temp=`fslstats ${VALUE[${i}]} -k ${temp_mask} -`
        echo ${temp} >> ${DIR_SCRATCH}/temp.txt
      fi
    done
  done
done

  ## get just volumes--------------
  # get subject and session identifiers
  # get label identifier, identify target file (if does not exist initialize with lookup table headers)
  # get voxel dimensions
  # loop over label files
  ## split labels into volumes
  ## fslstats input -k label_mask -v



#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}/
  rmdir ${DIR_SCRATCH}
else
  rm ${DIR_SCRATCH}/*
  rmdir ${DIR_SCRATCH}
fi

# Write log entry on conclusion ------------------------------------------------
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

