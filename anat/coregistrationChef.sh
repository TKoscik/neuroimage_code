#!/bin/bash -e
#===============================================================================
# Image coregistration, using coregistration_recipes.json for specification of
#    registration parameters
# Authors: Timothy R. Koscik
# Date: 2021-02-25
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=($(basename "$0"))
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
KERNEL="$(uname -s)"
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
    logBenchmark --operator ${OPERATOR} \
    --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
    --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
    if [[ -n "${DIR_PROJECT}" ]]; then
      logProject --operator ${OPERATOR} \
      --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
      --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
      --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      if [[ -n "${SID}" ]]; then
        logSession --operator ${OPERATOR} \
        --dir-project ${DIR_PROJECT} --pid ${PID} --sid ${SID} \
        --hardware ${HARDWARE} --kernel ${KERNEL} --hpc-q ${HPC_Q} --hpc-slots ${HPC_SLOTS} \
        --fcn-name ${FCN_NAME} --proc-start ${PROC_START} --proc-stop ${PROC_STOP} --exit-code ${EXIT_CODE}
      fi
    fi
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvld --long recipe-json:,recipe-name:,\
fixed,fixed-mask,fixed-mask-dilation,\
moving,moving-mask,moving-mask-dilation,\
dir-template,template,space-source,space-target,\
\
dimensonality,save-state,restore-state,write-composite-transform,\
print-similarity-measure-interval,write-internal-volumes,\
collapse-output-transforms,initialize-transforms-per-stage,interpolation,\
restrict-deformation,initial-fixed-transform,initial-moving-transform,metric,\
transform,convergence,smoothing-sigmas,shrink-factors,use-histogram-matching,\
use-estimate-learning-rate-once,winsorize-image-intensities,float,random-seed,\
\
prefix,xfm-label,apply-to,make-png,keep-fwd-xfm,keep-inv-xfm,\
dir-save,dir-xfm,dir-png,dir-scratch,\
verbose,help,no-log,dry-run -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
VERBOSE=0
HELP=false
DRY_RUN=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -d | --dry-run) DRY_RUN=true ; shift ;;
    --recipe-json) RECIPE_JSON="$2" ; shift 2 ;;
    --recipe-name) RECIPE_NAME="$2" ; shift 2 ;;
    --fixed) FIXED="$2" ; shift 2 ;;
    --fixed-mask) FIXED_MASK="$2" ; shift 2 ;;
    --fixed-mask-dilation) FIXED_MASK="$2" ; shift 2 ;;
    --moving) MOVING="$2" ; shift 2 ;;
    --moving-mask) MOVING_MASK_DILATION="$2" ; shift 2 ;;
    --moving-mask-dilation) MOVING_MASK_DILATION="$2" ; shift 2 ;;
    --dir-template) DIR_TEMPLATE="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space-source) SPACE_SOURCE="$2" ; shift 2 ;;
    --space-target) SPACE_TARGET="$2" ; shift 2 ;;
    --dimensonality) DIMENSIONALITY="$2" ; shift 2 ;;
    --save-state) SAVE_STATE="$2" ; shift 2 ;;
    --restore-state) RESTORE_STATE="$2" ; shift 2 ;;
    --write-composite-transform) WRITE_COMPOSITE_TRANSFORM="$2" ; shift 2 ;;
    --print-similarity-measure-interval) PRINT_SIMILARITY_MEASURE_INTERVAL="$2" ; shift 2 ;;
    --write-internal-volumes) WRITE_INTERNAL_VOLUMES="$2" ; shift 2 ;;
    --collapse-output-transforms) COLLAPSE_OUTPUT_TRANSFORMS="$2" ; shift 2 ;;
    --initialize-transforms-per-stage) INITIALIZE_TRANSFORMS_PER_STAGE="$2" ; shift 2 ;;
    --interpolation) INTERPOLATION="$2" ; shift 2 ;;
    --restrict-deformation) RESTRICT_DEFORMATION="$2" ; shift 2 ;;
    --initial-fixed-transform) INITIAL_FIXED_TRANSFORM="$2" ; shift 2 ;;
    --initial-moving-transform) INITIAL_MOVING_TRANSFORM="$2" ; shift 2 ;;
    --metric) METRIC="$2" ; shift 2 ;;
    --transform) TRANSFORM="$2" ; shift 2 ;;
    --convergence) CONVERGENCE="$2" ; shift 2 ;;
    --smoothing-sigmas) SMOOTHING_SIGMAS="$2" ; shift 2 ;;
    --shrink-factors) SHRINK_FACTORS="$2" ; shift 2 ;;
    --use-histogram-matching) USE_HISTOGRAM_MATCHING="$2" ; shift 2 ;;
    --use-estimate-learning-rate-once) USE_ESTIMATE_LERANING_RATE_ONCE="$2" ; shift 2 ;;
    --winsorize-image-intensities) WINSORIZE_IMAGE_INTENSITIES="$2" ; shift 2 ;;
    --float) FLOAT="$2" ; shift 2 ;;
    --random-seed) RANDOM_SEED="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --xfm-label) XFM_LABEL="$2" ; shift 2 ;;
    --roi-label) ROI_LABEL="$2" ; shift 2 ;;
    --apply-to) APPLY_TO="$2" ; shift 2 ;;
    --make-png) MAKE_PNG="true" ; shift ;;
    --keep-fwd-xfm) KEEP_FWD_XFM="true" ; shift ;;
    --keep-inv-xfm) KEEP_INV_XFM="true" ; shift ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-xfm) DIR_XFM="$2" ; shift 2 ;;
    --dir-png) DIR_PNG="$2" ; shift 2 ;;
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
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
RECIPE_DEFAULT=${INC_LUT}/coregistration_recipes.json
PARAMS_DEFAULT=($(jq -r '.coregistration_parameters | keys_unsorted[]?' < ${RECIPE_DEFAULT}))

# locate recipe ----------------------------------------------------------------
if [[ -n ${RECIPE_NAME} ]]; then
  if [[ -z ${RECIPE_JSON} ]]; then
    RECIPE_JSON=${RECIPE_DEFAULT}
  else
    echo "WARNING [INC ${FCN_NAME}] Operating without a coregistration recipe, default values may be insufficient, all variables should be specified"
  fi
fi
if [[ ! -f ${RECIPE_JSON} ]]; then
  echo "ERROR [INC ${FCN_NAME}] Recipe JSON not found. Aborting."
  exit 1
fi

# read parameter names from recipe ---------------------------------------------
if [[ -n ${RECIPE_JSON} ]]; then
  RECIPES=($(jq -r '.coregistration_recipe | keys_unsorted[]?' < ${RECIPE_JSON}))
  if [[ " ${RECIPES[@]} " =~ " ${RECIPE_NAME} " ]]; then
    PARAMS_RECIPE=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}' | keys_unsorted[]?' < ${RECIPE_JSON}))
  else
    echo "ERROR [INC ${FCN_NAME}] Recipe not in JSON. Aborting."
    exit 2
  fi
fi

# parse inputs and recipe together ---------------------------------------------
## variable specification order of priority
## 1. direct input to function
## 2. specified recipe
## 3. default values
for (( i=0; i<${#PARAMS_DEFAULT[@]}; i++ )); do
  unset VAR_NAME PARAM_STATE JQ_STR CHK_VAR
  VAR_NAME=${PARAMS_DEFAULT[${i}]^^}
  VAR_NAME=${VAR_NAME//-/_}
  eval 'if [[ -n ${'${VAR_NAME}'} ]]; then PARAM_STATE="directInput"; else PARAM_STATE="lookup"; fi'
  if [[ "${PARAM_STATE}" == "lookup" ]] &&\
     [[ " ${PARAMS_RECIPE[@]} " =~ " ${PARAMS_DEFAULT[${i}]} " ]]; then
     JQ_STR="'.coregistration_recipe.${RECIPE_NAME}."'"'${PARAMS_DEFAULT[${i}]}'"'"[]?'"
     eval ${VAR_NAME}'=($(jq -r '${JQ_STR}' < '${RECIPE_JSON}'))'
  elif [[ "${PARAM_STATE}" == "lookup" ]]; then
     JQ_STR="'.coregistration_parameters."'"'${PARAMS_DEFAULT[${i}]}'"'"[]?'"
     eval ${VAR_NAME}'=($(jq -r '${JQ_STR}' < '${RECIPE_JSON}'))'
  fi
  eval 'if [[ "${'${VAR_NAME}'}" == "required" ]]; then CHK_VAR="missing"; fi'
  if [[ "${CHK_VAR}" == "missing" ]]; then
    echo "ERROR [INC ${FCN_NAME}] ${VAR_NAME} required with no default"
    exit 3
  fi
done

# parse basic required information about MOVING images -------------------------
MOVING=(${MOVING//,/ })
for (( i=0; i<${#MOVING[@]}; i++ )); do
  MOD+=($(getField -i ${MOVING[@]} -f modality))
done

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(getDir -i ${MOVING[0]})
PID=$(getField -i ${MOVING[0]} -f sub)
SID=$(getField -i ${MOVING[0]} -f ses)
DIRPID=sub-${PID}
if [[ -n ${SID} ]]; then DIRPID=${DIRPID}/ses-${SID}; fi

# set defaults as necessary ----------------------------------------------------
if [[ "${PREFIX,,}" == "default" ]]; then
  PREFIX=$(getBidsBase -s -i ${MOVING[0]})
  PREP=$(getField -i ${PREFIX} -f prep)
  if [[ -n ${PREP} ]]; then
    PREP="${PREP}+coreg"
    PREFIX=$(modField -i ${PREFIX} -r -f prep)
  fi
fi

# set directories --------------------------------------------------------------
if [[ "${DIR_SAVE,,}" == "default" ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/${DIRPID}
fi
if [[ "${DIR_XFM,,}" == "default" ]]; then
  DIR_XFM=${DIR_PROJECT}/derivatives/inc/xfm/${DIRPID}
fi
if [[ "${DIR_SCRATCH,,}" == "default" ]]; then
  DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
fi
mkdir -p ${DIR_SCRATCH}
if [[ "${DIR_TEMPLATE}" == "default" ]]; then
  DIR_TEMPLATE=${INC_TEMPLATE}/${TEMPLATE}/${SPACE_SOURCE}
fi

# parse fixed ------------------------------------------------------------------
if [[ "${FIXED}" == "optional" ]]; then
  unset FIXED
  for (( i=0; i<${MOVING_N}; i++ )); do
    if [[ -f ${DIR_TEMPLATE}/${TEMPLATE}_${SPACE_SOURCE}_${MOD[${i}]}.nii.gz ]]; then
      FIXED+=${DIR_TEMPLATE}/${TEMPLATE}_${SPACE_SOURCE}_${MOD[${i}]}.nii.gz
    else
      FIXED+=${DIR_TEMPLATE}/${TEMPLATE}_${SPACE_SOURCE}_T1w.nii.gz
    fi
  done
else
  FIXED=(${FIXED//,/ })
fi

# check spacing ----------------------------------------------------------------
FIX_SPACE="false"
if [[ "${SPACE_TARGET}" == "moving" ]]; then
  SPACE_MOVING=$(niiInfo -i ${MOVING[0]} -f spacing)
  SPACE_FIXED=$(niiInfo -i ${FIXED[0]} -f spacing)
  if [[ "${SPACE_MOVING}" != "${SPACE_FIXED}" ]]; then
    NEW_SPACE=${SPACE_MOVING// /x}
    FIX_SPACE="true"
  fi
elif [[ "${SPACE_TARGET}" != "${SPACE_SOURCE}"]]; then
  NEW_SPACE=$(convSpacing -i ${SPACE_TARGET})
  FIX_SPACE="true"
fi

if [[ "${FIX_SPACE}" == "true" ]]; then
  for (( i=0; i<${#FIXED[@]}; i++ )); do
    BNAME=$(basename ${FIXED[${i}]})
    ResampleImage 3 ${FIXED[${i}]} ${DIR_SCRATCH}/${BNAME} ${NEW_SPACE} 0
    FIXED[${i}]=${DIR_SCRATCH}/${BNAME}
  done
fi

# check for histogram matching -------------------------------------------------
if [[ "${USE_HISTOGRAM_MATCHING}" == "default" ]]; then
  USE_HISTOGRAM_MATCHING=1
  for (( i=0; i<${#MOVING[@]}; i++ )); do
    MOVING_MOD=$(getField -i ${MOVING[${i}]} -f modality)
    FIXED_MOD=$(getField -i ${FIXED[${i}]} -f modality)
    if [[ "${MOVING_MOD}" != "${FIXED_MOD}" ]]; then
      USE_HISTOGRAM_MATCHING=0
      break
    fi
  done
fi

# check masks ------------------------------------------------------------------
if [[ -n ${MOVING_MASK} ]]; then
  MOVING_MASK=(${MOVING_MASK//,/ })
  if [[ ${#MOVING_MASK[@]} -ne ${#TRANSFORM[@]} ]] &&
     [[ ${#MOVING_MASK[@]} -ne 1 ]]; then
    echo "ERROR [INC ${FCN_NAME}] number of moving masks must equal 1 or the number of transforms"
    exit 4
  fi
fi
if [[ -n ${FIXED_MASK} ]]; then
  FIXED_MASK=(${FIXED_MASK//,/ })
  if [[ ${#FIXED_MASK[@]} -ne ${#TRANSFORM[@]} ]] &&
     [[ ${#FIXED_MASK[@]} -ne 1 ]]; then
    echo "ERROR [INC ${FCN_NAME}] number of fixed masks must equal 1 or the number of transforms"
    exit 5
  fi
fi
if [[ ${#FIXED_MASK[@]} -ne ${#MOVING_MASK[@]} ]]; then
  echo "ERROR [INC ${FCN_NAME}] number of fixed and moving masks must match"
  exit 6
fi

# show outputs for dry run -----------------------------------------------------
if [[ "${DRY_RUN}" == "true" ]]; then
  for (( i=0; i<${#PARAMS_DEFAULT[@]}; i++ )); do
    VAR_NAME=${PARAMS_DEFAULT[${i}]^^}
    VAR_NAME=${VAR_NAME//-/_}
    eval "echo ${VAR_NAME}="'${'${VAR_NAME}'[@]}'
  done
  NO_LOG=TRUE
  exit 0
fi

### write ANTS registration function ===========================================
antsCoreg="antsRegistration"
antsCoreg="${antsCoreg} --dimensionality ${DIMENSIONALITY}"

antsCoreg="${antsCoreg} --output ${DIR_SCRATCH}/xfm_"
if [[ "${SAVE_STATE}" != "optional" ]]; then
  antsCoreg="${antsCoreg} --save-state ${SAVE_STATE}"
fi
if [[ "${RESTORE_STATE}" != "optional" ]]; then
  antsCoreg="${antsCoreg} --restore-state ${RESTORE_STATE}"
fi
if [[ ${WRITE_COMPOSITE_TRANSFORM} -eq 1 ]]; then
  antsCoreg="${antsCoreg} --write-composite-transform 1"
fi
if [[ ${PRINT_SIMILARITY_MEASURE_INTERVAL} -ne 0 ]]; then
  antsCoreg="${antsCoreg} --print-similarity-measure-interval ${PRINT_SIMILARITY_MEASURE_INTERVAL}"
fi
if [[ ${WRITE_INTERNAL_VOLUMES} -ne 0 ]]; then
  antsCoreg="${antsCoreg} --write-internal-voumes ${WRITE_INTERNAL_VOLUMES}"
fi
if [[ ${COLLAPSE_OUTPUT_TRANSFORMS} -eq 0 ]]; then
  antsCoreg="${antsCoreg} --collapse-output-transforms 0"
fi
if [[ ${INITIALIZE_TRANSFORMS_PER_STAGE} -eq 0 ]]; then
  antsCoreg="${antsCoreg} --initialize-transforms-per-stage 0"
fi
if [[ "${RESTRICT_DEFORMATION}" != "optional" ]]; then
  antsCoreg="${antsCoreg} --resrict-deformation ${RESTRICT_DEFORMATION}"
fi
if [[ "${INITIAL_FIXED_TRANSFORM}" != "optional" ]]; then
  INITIAL_FIXED_TRANSFORM=(${INITIAL_FIXED_TRANSFORM//;/ })
  for (( i=0; i<${#INITIAL_FIXED_TRANSFORM[@]}; i++ )); do
    antsCoreg="${antsCoreg} --initial-fixed-transform ${INITIAL_FIXED_TRANSFORM[${i}]}"
  done
fi
if [[ "${INITIAL_MOVING_TRANSFORM}" != "optional" ]]; then
  INITIAL_MOVING_TRANSFORM=(${INITIAL_MOVING_TRANSFORM//;/ })
  for (( i=0; i<${#INITIAL_MOVING_TRANSFORM[@]}; i++ )); do
    antsCoreg="${antsCoreg} --initial-moving-transform ${INITIAL_MOVING_TRANSFORM[${i}]}"
  done
fi
if [[ ${#FIXED_MASK[@]} -eq 1 ]]; then
  antsCoreg="${antsCoreg} --masks [${FIXED_MASK[0]},${MOVING_MASK[0]}]"
fi
for (( i=0; i<${#TRANSFORM[@]}; i++ )); do
  antsCoreg="${antsCoreg} --transform ${TRANSFORM[${i}]}"
  METRIC_STR=(${METRIC[${i}]//fixedImage,movingImage/ })
  for (( j=0; j<${#MOVING[@]}; j++ )); do
    antsCoreg="${antsCoreg} --metric ${METRIC_STR[0]}${FIXED[${j}]},${MOVING[${j}]}${METRIC_STR[1]}"
  done
  if [[ ${#FIXED_MASK[@]} -gt 1 ]]; then
    antsCoreg="${antsCoreg} --masks [${FIXED_MASK[${i}]},${MOVING_MASK[${i}]}]"
  fi
  antsCoreg="${antsCoreg} --convergence ${CONVERGENCE[${i}]}"
  antsCoreg="${antsCoreg} --smoothing-sigmas ${SMOOTHING_SIGMAS[${i}]}"
  antsCoreg="${antsCoreg} --shrink-factors ${SHRINK_FACTORS[${i}]}"
done
antsCoreg="${antsCoreg} --use-histogram-matching ${USE_HISTOGRAM_MATCHING}"
if [[ "${USE_ESTIMATE_LEARNING_RATE_ONCE}" != "optional" ]]; then
  antsCoreg="${antsCoreg} --use-estimate-learning-rate-once ${USE_ESTIMATE_LEARNING_RATE_ONCE}"
fi
if [[ "${WINSORIZE_IMAGE_INTENSITIES}" != "optional" ]]; then
  antsCoreg="${antsCoreg} --winsorize-image-intensities ${WINSORIZE_IMAGE_INTENSITIES}"
fi
antsCoreg="${antsCoreg} --float ${FLOAT}"
antsCoreg="${antsCoreg} --random-seed ${RANDOM_SEED}"

if [[ "${DRY_RUN}" == "true" ]]; then
  echo ${antsCoreg}
  exit 0
fi
eval ${antsCoreg}

# apply transforms =============================================================
mkdir -p ${DIR_SAVE}
FROM=$(getSpace -i ${MOVING[0]})
TO=$(getSpace -i ${FIXED[0]})
for (( i=0; i<${#MOVING[@]}; i++ )); do
  TNAME=${DIR_SAVE}/${PREFIX}
  if [[ -n ${PREP} ]]; then TNAME="${TNAME}_prep-${PREP}"; fi
  TNAME="${TNAME}_reg-${TO}_${TMOD}.nii.gz"
  TMOD=$(getField -i ${MOVING[${i}]} -f modality)
  apply_xfm="antsApplyTransforms -d 3"
  if [[ "${INTERPOLATION}" == "default" ]]; then
    apply_xfm="${apply_xfm} -n BSpline[3]"
  else
    apply_xfm="${apply_xfm} -n ${INTERPOLATION}"
  fi
  apply_xfm="${apply_xfm} -i ${FIXED}"
  apply_xfm="${apply_xfm} -o ${TNAME}"
  if [[ -f ${DIR_SCRATCH}/xfm_1Warp.nii.gz ]]; then
    apply_xfm="${apply_xfm} -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz"
  fi
  if [[ -f ${DIR_SCRATCH}/xfm_0GenericAffine.mat ]]; then
    apply_xfm="${apply_xfm} -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat"
  fi
  apply_xfm="${apply_xfm} -r ${FIXED[0]}"
  eval ${apply_xfm}
done

# apply to extra images --------------------------------------------------------
APPLY_TO=(${APPLY_TO//,/ })
for (( i=0; i<${#APPLY_TO[@]}; i++ )); do
  TNAME=$(getBidsBase -s -i ${APPLY_TO[${i}]})
  TMOD=$(getField -i ${APPLY_TO[${i}]} -f modality)
  apply_xfm="antsApplyTransforms -d 3"
  if [[ "${INTERPOLATION}" == "default" ]]; then
    if [[ "${TMOD}" == *"label"* ]]; then
      apply_xfm="${apply_xfm} -n MultiLabel"
    elif [[ "${TMOD}" == *"mask"* ]]; then
      apply_xfm="${apply_xfm} -n GenericLabel"
    else
      apply_xfm="${apply_xfm} -n BSpline[3]"
    fi
  else
    apply_xfm="${apply_xfm} -n ${INTERPOLATION}"
  fi
  apply_xfm="${apply_xfm} -i ${FIXED}"
  apply_xfm="${apply_xfm} -o ${DIR_SAVE}/${TNAME}_reg-${TO}_${TMOD}.nii.gz"
  if [[ -f ${DIR_SCRATCH}/xfm_1Warp.nii.gz ]]; then
    apply_xfm="${apply_xfm} -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz"
  fi
  if [[ -f ${DIR_SCRATCH}/xfm_0GenericAffine.mat ]]; then
    apply_xfm="${apply_xfm} -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat"
  fi
  apply_xfm="${apply_xfm} -r ${FIXED[0]}"
  eval ${apply_xfm}
done

# move results to desired destination ------------------------------------------
XFM_LABEL=(${XFM_LABEL//,/ })
if [[ "${KEEP_FWD_XFM}" == "true" ]] || [[ "${KEEP_INV_XFM}" == "true" ]]; then
  mkdir -p ${DIR_XFM}
  if [[ "${XFM_LABEL[0]}" == "default" ]]; then
    if [[ "${TRANSFORM[@],,}" == *"bsplineexponential"* ]]; then
      XFM_LABEL[0]="bsplineExp"
    elif [[ "${TRANSFORM[@],,}" == *"exponential"* ]]; then
      XFM_LABEL[0]="exp"
    elif [[ "${TRANSFORM[@],,}" == *"bsplinesyn"* ]]; then
      XFM_LABEL[0]="bsplineSyn"
    elif [[ "${TRANSFORM[@],,}" == *"syn"* ]]; then
      XFM_LABEL[0]="syn"
    elif [[ "${TRANSFORM[@],,}" == *"timevaryingbsplinevelocityfield"* ]]; then
      XFM_LABEL[0]="timeVaryingBspline"
    elif [[ "${TRANSFORM[@],,}" == *"timevaryingvelocityfield"* ]]; then
      XFM_LABEL[0]="timeVarying"
    elif [[ "${TRANSFORM[@],,}" == *"bsplinedisplacementfield"* ]]; then
      XFM_LABEL[0]="bsplineDisp"
    elif [[ "${TRANSFORM[@],,}" == *"gaussiandisplacementfield"* ]]; then
      XFM_LABEL[0]="displacement"
    elif [[ "${TRANSFORM[@],,}" == *"bspline"* ]]; then
      XFM_LABEL[0]="bspline"
    else
      XFM_LABEL[0]="nonlinear"
    fi
    if [[ "${TRANSFORM[@],,}" == *"compositeaffine"* ]]; then
      XFM_LABEL[1]="affineComposit"
    elif [[ "${TRANSFORM[@],,}" == *"affine"* ]]; then
      XFM_LABEL[1]="affine"
    elif [[ "${TRANSFORM[@],,}" == *"similarity"* ]]; then
      XFM_LABEL[1]="similarity"
    elif [[ "${TRANSFORM[@],,}" == *"rigid"* ]]; then
      XFM_LABEL[1]="rigid"
    elif [[ "${TRANSFORM[@],,}" == *"translation"* ]]; then
      XFM_LABEL[1]="translation"
    else
      XFM_LABEL[1]="unknown"
    fi
  fi
fi

if [[ "${KEEP_FWD_XFM}" == "true" ]] || [[ "${KEEP_INV_XFM}" == "true" ]]; then
  if [[ -f ${DIR_SCRATCH}/xfm_0GenericAffine.mat ]]; then
    mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
      ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-${XFM_LABEL[1]}.nii.gz
  fi
fi
if [[ "${KEEP_FWD_XFM}" == "true" ]]; then
  if [[ -f ${DIR_SCRATCH}/xfm_1Warp.nii.gz ]]; then
    mv ${DIR_SCRATCH}/xfm_1Warp.nii.gz \
      ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-${XFM_LABEL[0]}.nii.gz
  fi
fi
if [[ "${KEEP_INV_XFM}" == "true" ]]; then
  if [[ -f ${DIR_SCRATCH}/xfm_1InverseWarp.nii.gz ]]; then
    mv ${DIR_SCRATCH}/xfm_1InverseWarp.nii.gz \
      ${DIR_XFM}/${PREFIX}_from-${TO}_to-${FROM}_xfm-${XFM_LABEL[0]}.nii.gz
  fi
fi

# plot output for review -------------------------------------------------------
if [[ "${MAKE_PNG}" == "true" ]]; then
  mkdir -p ${DIR_PNG}
  DIMS=($(niiInfo -i ${FIXED[0]} -f voxels))
  if [[ ${DIMS[1]} -gt ${DIMS[0]} ]]; then
    NS=5
    NC=$(echo "scale=0; (${NS}*${DIMS[1]})/${DIMS[2]}" | bc -l) #"#'#
    NA=$(echo "scale=0; (${NS}*${DIMS[1]})/${DIMS[0]}" | bc -l) #"#'#
  else
    NA=5
    NC=$(echo "scale=0; (${NA}*${DIMS[0]})/${DIMS[2]}" | bc -l) #"#'#
    NS=$(echo "scale=0; (${NA}*${DIMS[0]})/${DIMS[1]}" | bc -l) #"#'#
  fi
  
  PNG_MOD=$(getField -i ${MOVING[0]} -f modality)
  make3Dpng \
    --bg ${FIXED[0]} --bg-color "#000000,#00FF00" --bg-thresh 2,98 \
    --fg ${MOVING[0]} --fg-color "#000000,#FF00FF" --fg-thresh 2,98 --fg-cbar \
    --layout "${NS}:x;${NC}:y;${NA}:z" --offset "0,0,0" \
    --filename ${PREFIX}_from-${FROM}_to-${TO}_img-${PNG_MOD} \
    --dir-save ${DIR_PLOT}
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0


