#!/bin/bash -e
#===============================================================================
# Brain Extraction
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-27
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(unname -s)"
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
  if [[ "${NO_LOG}" == "false" ]]; then
    ${DIR_INC}/log/logBenchmark.sh --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    ${DIR_INC}/log/logProject.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    ${DIR_INC}/log/logSession.sh --operator ${OPERATOR} \
    --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvkl --long prefix:,\
image:,method:,suffix:,spatial-filter:,filter-radius:,\
dir-save:,dir-scratch:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@")
if [[ $? != 0 ]]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
METHOD=
SUFFIX=
SPATIAL_FILTER="NULL"
FILTER_RADIUS=1
TEMPLATE="OASIS"
DIR_SAVE=
DIR_SCRATCH=${DIR_TMP}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --method) METHOD="$2" ; shift 2 ;;
    --suffix) SUFFIX="$2" ; shift 2 ;;
    --spatial-filter) SPATIAL_FILTER="$2" ; shift 2 ;;
    --filter-radius) FILTER_RADIUS="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help -------------------------------------------------------------------
if [[ "${HELP}" == "true" ]]; then
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FCN_NAME}"
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FCN_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --image <value>          Images to use for brain extraction, multiple'
  echo '                           images allowed, T1w should be first input'
  echo '  --method <value>         One of AFNI, ANTs, FSL, multiple inputs'
  echo '                           allowed.  If multiple inputs given, a'
  echo '                           majority vote output will be given as well'
  echo '  --suffix <value>         an optional suffix to append to filenames,'
  echo '                           e.g., "0" or "prelim"'
  echo '  --spatial-filter <value> Add a spatial filter step after extracting'
  echo '                           brain mask using ImageMath, e.g., MD for'
  echo '                           dilation, filter radius must be specified'
  echo '                           as well. Options are: G, MD, ME, MO, MC,'
  echo '                           GD, GE, GO, GC)'
  echo '  --filter-radius <value>  Filter radius in voxels (unless filter is'
  echo '                           G for Gaussian then mm)'
  echo '  --template <value>       For ANTs method, which template to use,'
  echo '                           default=OASIS'
  echo '  --dir-save <value>       directory to save output, '
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/inc/anat/mask'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
IMAGE=(${IMAGE//,/ })
NUM_IMAGE=${#IMAGE[@]}
METHOD=(${METHOD//,/ })
NUM_METHOD=${#METHOD[@]}

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(${DIR_INC}/bids/get_dir.sh -i ${IMAGE[0]})
PID=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE[0]} -f sub)
SID=$(${DIR_INC}/bids/get_field.sh -i ${IMAGE[0]} -f ses)
if [[ -z "${PREFIX}" ]]; then 
  PREFIX=$(${DIR_INC}/bids/get_bidsbase.sh -s -i ${IMAGE[0]})
fi

if [[ -z "${DIR_SAVE}" ]]; then
  DIR_SAVE=${DIR_PROJECT}/inc/anat/mask
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}

# Brain extraction ------------------------------------------------------------
for (( i=0; i<${NUM_METHOD}; i++ )); do
  # run AFNI 3dSkullStrip -----------------------------------------------------
  if [[ "${METHOD[${i}],,}" == "afni" ]] || [[ "${METHOD[${i}],,}" == "3dskullstrip" ]]; then
    echo ">>>Running AFNI 3dSkullstrip"
    3dSkullStrip \
      -input ${IMAGE[0]} \
      -prefix ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz
    fslmaths ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz -bin ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz
    if [[ "${SPATIAL_FILTER}" != "NULL" ]]; then
      echo ">>>applying Spatial Filter ${SPATIAL_FILTER} ${FILTER_RADIUS}"
      sf_fcn="ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${SPATIAL_FILTER}"
      sf_fcn="${sf_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${FILTER_RADIUS}"
      eval ${sf_fcn}
      fslmaths ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz -bin ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz
    fi
  fi

  # run ANTs brain extraction -------------------------------------------------
  if [[ "${METHOD[${i}],,}" == "ants" ]]; then
    echo ">>>Running ANTs Brain Extraction"
    DIR_TEMPLATE=${DIR_TEMPLATE}/${TEMPLATE}
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
      echo ">>>applying Spatial Filter ${SPATIAL_FILTER} ${FILTER_RADIUS}"
      sf_fcn="ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${SPATIAL_FILTER}"
      sf_fcn="${sf_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${FILTER_RADIUS}"
      eval ${sf_fcn}
      fslmaths ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz -bin ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz
    fi
  fi

  # run FSL's BET -------------------------------------------------------------
  if [[ "${METHOD[${i}],,}" == "fsl" ]] || [[ "${METHOD[${i}],,}" == "bet" ]] || [[ "${METHOD[${i}],,}" == "bet2" ]]; then
    echo ">>>Running FSL's BET"
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
      echo ">>>applying Spatial Filter ${SPATIAL_FILTER} ${FILTER_RADIUS}"
      sf_fcn="ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${SPATIAL_FILTER}"
      sf_fcn="${sf_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${FILTER_RADIUS}"
      eval ${sf_fcn}
      fslmaths ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz -bin ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz
    fi
  fi

  if [[ "${METHOD[${i}],,}" == "fsurf" ]] || [[ "${METHOD[${i}],,}" == "freesurfer" ]] || [[ "${METHOD[${i}],,}" == "samseg" ]]; then
    echo ">>>Running Freesurfer's SAMSEG"
    mkdir -p ${DIR_SCRATCH}/samseg
    samseg_fcn="run_samseg --input"
    for (( j=0; j<${NUM_IMAGE}; j++ )); do
      mri_convert ${IMAGE[${j}]} ${DIR_SCRATCH}/image${j}.mgz
      samseg_fcn="${samseg_fcn} ${DIR_SCRATCH}/image${j}.mgz"
    done
    samseg_fcn="${samseg_fcn} --output ${DIR_SCRATCH}/samseg"
    eval ${samseg_fcn}
    mri_extract_label ${DIR_SCRATCH}/samseg/seg.mgz 0 4 24 43 165 258 259 ${DIR_SCRATCH}/samseg/nonbrain.mgz
    mri_convert ${DIR_SCRATCH}/samseg/nonbrain.mgz ${DIR_SCRATCH}/samseg/nonbrain.nii.gz
    mri_convert ${DIR_SCRATCH}/samseg/seg.mgz ${DIR_SCRATCH}/samseg/brain.nii.gz
    fslmaths ${DIR_SCRATCH}/samseg/nonbrain.nii.gz -binv ${DIR_SCRATCH}/samseg/nonbrain.nii.gz
    fslmaths ${DIR_SCRATCH}/samseg/brain.nii.gz -bin -mas ${DIR_SCRATCH}/samseg/nonbrain.nii.gz ${DIR_SCRATCH}/${PREFIX}_mask-brain+SAMSEG${SUFFIX}.nii.gz

    if [[ "${SPATIAL_FILTER}" != "NULL" ]]; then
      echo ">>>applying Spatial Filter ${SPATIAL_FILTER} ${FILTER_RADIUS}"
      sf_fcn="ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+SAMSEG${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${SPATIAL_FILTER}"
      sf_fcn="${sf_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+SAMSEG${SUFFIX}.nii.gz"
      sf_fcn="${sf_fcn} ${FILTER_RADIUS}"
      eval ${sf_fcn}
      fslmaths ${DIR_SCRATCH}/${PREFIX}_mask-brain+SAMSEG${SUFFIX}.nii.gz -bin ${DIR_SCRATCH}/${PREFIX}_mask-brain+SAMSEG${SUFFIX}.nii.gz
    fi
  fi
done

# do majority vote mask if multiple used
if [[ ${NUM_METHOD} > 1 ]]; then
  echo ">>>Running Majority Vote Function"
  majVote_fcn="ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask-brain+MALF${SUFFIX}.nii.gz"
  majVote_fcn="${majVote_fcn} MajorityVoting"
  for (( i=0; i<${NUM_METHOD}; i++ )); do
    if [[ "${METHOD[${i}],,}" == "afni" ]] || [[ "${METHOD[${i}],,}" == "3dskullstrip" ]]; then
      majVote_fcn="${majVote_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+AFNI${SUFFIX}.nii.gz"
    fi
    if [[ "${METHOD[${i}],,}" == "ants" ]]; then
      majVote_fcn="${majVote_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+ANTs${SUFFIX}.nii.gz"
    fi
    if [[ "${METHOD[${i}],,}" == "fsl" ]] || [[ "${METHOD[${i}],,}" == "bet" ]] || [[ "${METHOD[${i}],,}" == "bet2" ]]; then
      majVote_fcn="${majVote_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+FSL${SUFFIX}.nii.gz"
    fi
    if [[ "${METHOD[${i}],,}" == "fsurf" ]] || [[ "${METHOD[${i}],,}" == "freesurfer" ]] || [[ "${METHOD[${i}],,}" == "samseg" ]]; then
      majVote_fcn="${majVote_fcn} ${DIR_SCRATCH}/${PREFIX}_mask-brain+SAMSEG${SUFFIX}.nii.gz"
    fi
  done
  eval ${majVote_fcn}
fi

# move files to appropriate locations
mv ${DIR_SCRATCH}/${PREFIX}_mask-brain* ${DIR_SAVE}

#===============================================================================
# End of Function
#===============================================================================
exit 0

