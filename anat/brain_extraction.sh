#!/bin/bash -e

#===============================================================================
# Brain Extraction
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-27
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvkl --long group:,prefix:,\
image:,method:,suffix:,spatial-filter:,filter-radius:,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
IMAGE=
METHOD=
SUFFIX=
SPATIAL_FILTER="NULL"
FILTER_RADIUS=1
TEMPLATE="OASIS"
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
KEEP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -c | --dry-run) DRY-RUN=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE+="$2" ; shift 2 ;;
    --method) METHOD+="$2" ; shift 2 ;;
    --suffix) SUFFIX="$2" ; shift 2 ;;
    --spatial-filter) SPATIAL_FILTER="$2" ; shift 2 ;;
    --filter_radius) FILTER_RADIUS="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
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
  echo 'Date: 2020-02-25'
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
  echo '  --image <value>          Images to use for brain extraction, multiple'
  echo '                           images allowed, T1w should be first input'
  echo '  --method <value>         One of AFNI, ANTs, FSL, multiple inputs allowed.'
  echo '                           If multiple inputs given, a majority vote'
  echo '                           output will be given as well'
  echo '  --suffix <value>         an optional suffix to append to filenames,'
  echo '                           e.g., "0" or "prelim"'
  echo '  --dir-save <value>       directory to save output, '
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/anat/mask'
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

DIR_PROJECT=`${DIR_NIMGCORE}/code/bids/get_dir.sh -i ${IMAGE}`
SUBJECT=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${IMAGE} -f "sub"`
SESSION=`${DIR_NIMGCORE}/code/bids/get_field.sh -i ${IMAGE} -f "ses"`
if [ -z "${PREFIX}" ]; then 
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/mask
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

#===============================================================================
# Start of Function
#===============================================================================
NUM_METHOD=${#METHOD[@]}
NUM_IMAGE=${#IMAGE[@]}
for (( i=0; i<${NUM_METHOD}; i++ )); do
  # run AFNI 3dSkullStrip
  if [[ "${METHOD[${i}],,}" == "afni" ]] || [[ "${METHOD[${i}],,}" == "3dskullstrip" ]]; then
    3dSkullStrip \
      -input ${IMAGE[0]} \
      -prefix ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz
    fslmaths ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz -bin ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz
    if [[ "${SPATIAL_FILTER}" != "NULL" ]]; then
      sf_fcn="ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${SPATIAL_FILTER}"
      sf_fcn="${sf_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${FILTER_RADIUS}"
      eval ${sf_fcn}
      fslmaths ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz -bin ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz
    fi
  fi

  # run ANTs brain extraction
  if [[ "${METHOD[${i}],,}" == "ants" ]]; then
    DIR_TEMPLATE=${DIR_NIMGCORE}/templates_human/${TEMPLATE}
    ants_fcn="antsBrainExtraction.sh"
    ants_fcn="${ants_fcn} -d 3"
    for (( j=0; j<${NUM_IMAGE}; j++ )); do
      ants_fcn="${ants_fcn} -a ${IMAGE[${j}]}"
    done
    ants_fcn="${ants_fcn} -e ${DIR_TEMPLATE}/T_template0.nii.gz"
    ants_fcn="${ants_fcn} -m ${DIR_TEMPLATE}/T_template0_BrainCerebellumProbabilityMask.nii.gz"
    ants_fcn="${ants_fcn} -f ${DIR_TEMPLATE}/T_template0_BrainCerebellumRegistrationMask.nii.gz"
    ants_fcn="${ants_fcn} -o ${DIR_SCRATCH}/ants-bex_"
    eval ${ants_fcn}
    
    CopyImageHeaderInformation ${IMAGE[${j}]} \
      ${DIR_SCRATCH}/ants-bex_BrainExtractionMask.nii.gz \
      ${DIR_SCRATCH}/ants-bex_BrainExtractionMask.nii.gz 1 1 1
    mv ${DIR_SCRATCH}/ants-bex_BrainExtractionMask.nii.gz \
      ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz
    rm ${DIR_SCRATCH}/ants-bex_BrainExtraction*

    if [[ "${SPATIAL_FILTER}" != "NULL" ]]; then
      sf_fcn="ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${SPATIAL_FILTER}"
      sf_fcn="${sf_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${FILTER_RADIUS}"
      eval ${sf_fcn}
      fslmaths ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz -bin ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz
    fi
  fi

  # run FSL's BET
  if [[ "${METHOD[${i}],,}" == "fsl" ]] || [[ "${METHOD[${i}],,}" == "bet" ]] || [[ "${METHOD[${i}],,}" == "bet2" ]]; then
    fsl_fcn="bet ${IMAGE[0]}"
    fsl_fcn="${fsl_fcn} ${DIR_SCRATCH}/fsl_bet.nii.gz"
    if [[ ${NUM_IMAGE} > 1 ]]; then
      fsl_fcn="${fsl_fcn} -A2 ${IMAGE[0]}"
    fi
    fsl_fcn="${fsl_fcn} -m -R"
    eval ${fsl_fcn}
    mv ${DIR_SCRATCH}/fsl_bet_mask.nii.gz \
      ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz
    rm ${DIR_SCRATCH}/fsl*
    
    if [[ "${SPATIAL_FILTER}" != "NULL" ]]; then
      sf_fcn="ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL`${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${SPATIAL_FILTER}"
      sf_fcn="${sf_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${FILTER_RADIUS}"
      eval ${sf_fcn}
      fslmaths ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz -bin ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz
    fi
  fi
done

# do majority vote mask if multiple used
if [[ ${NUM_METHOD} > 1 ]]; then
  majVote_fcn="ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+MALF${SUFFIX}.nii.gz"
  majVote_fcn="${majVote_fcn} MajorityVoting"
  if [[ "${METHOD[${i}],,}" == "afni" ]] || [[ "${METHOD[${i}],,}" == "3dskullstrip" ]]; then
    majVote_fcn="${majVote_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz"
  fi
  if [[ "${METHOD[${i}],,}" == "ants" ]]; then
    majVote_fcn="${majVote_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz"
  fi
  if [[ "${METHOD[${i}],,}" == "fsl" ]] || [[ "${METHOD[${i}],,}" == "bet" ]] || [[ "${METHOD[${i}],,}" == "bet2" ]]; then
    majVote_fcn="${majVote_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz"
  fi
  eval ${majVote_fcn}
fi

# move files to appropriate locations
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain* ${DIR_SAVE}

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


