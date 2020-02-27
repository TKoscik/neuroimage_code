#!/bin/bash -e

#===============================================================================
# Brain Extraction
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-27
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvk --long researcher:,project:,group:,subject:,session:,prefix:,\
image:,method:,suffix:, \
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose,keep -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

DATE_SUFFIX=$(date +%Y%m%dT%H%M%S)
RESEARCHER=
PROJECT=
GROUP=
SUBJECT=
SESSION=
PREFIX=
IMAGE=
METHOD=
SUFFIX=
TEMPLATE="OASIS"
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -c | --dry-run) DRY-RUN=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE+="$2" ; shift 2 ;;
    --method) METHOD+="$2" ; shift 2 ;;
    --suffix) SUFFIX="$2" ; shift 2 ;;
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
  echo '  --researcher <value>     directory containing the project,'
  echo '                           e.g. /Shared/koscikt'
  echo '  --project <value>        name of the project folder, e.g., iowa_black'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --subject <value>        subject identifer, e.g., 123'
  echo '  --session <value>        session identifier, e.g., 1234abcd'
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

# Get time stamp for log -------------------------------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

# Setup directories ------------------------------------------------------------
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${RESEARCHER}/${PROJECT}/derivatives/anat/mask
fi
mkdir -r ${DIR_SCRATCH}
mkdir -r ${DIR_SAVE}

# set output prefix if not provided --------------------------------------------
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

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
  fi

  # run FSL's BET
  if [[ "${METHOD[${i}],,}" == "FSL" ]] || [[ "${METHOD[${i}],,}" == "bet" ]] || [[ "${METHOD[${i}],,}" == "bet2" ]]; then
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
  if [[ "${METHOD[${i}],,}" == "FSL" ]] || [[ "${METHOD[${i}],,}" == "bet" ]] || [[ "${METHOD[${i}],,}" == "bet2" ]]; then
    majVote_fcn="${majVote_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz"
  fi
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
LOG_FILE=${RESEARCHER}/${PROJECT}/log/sub-${SUBJECT}_ses-${SESSION}.log
date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}


