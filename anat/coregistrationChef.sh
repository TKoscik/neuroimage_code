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
fixed:,fixed-mask:,fixed-mask-dilation:,\
moving:,moving-mask:,moving-mask-dilation:,\
mask-procedure:,apply-to:,\
dir-template:,template:,space-source:,space-target:,\
\
dimensonality:,save-state:,restore-state:,write-composite-transform,\
print-similarity-measure-interval:,write-internal-volumes:,\
collapse-output-transforms,initialize-transforms-per-stage,interpolation:,\
restrict-deformation:,initial-fixed-transform:,initial-moving-transform,metric:,\
transform:,convergence:,smoothing-sigmas:,shrink-factors:,use-histogram-matching:,\
use-estimate-learning-rate-once,winsorize-image-intensities:,float,random-seed:,\
ants-verbose,\
\
prefix:,label-xfm:,label-from:,label-to:,label-reg:,\
apply-to:,make-overlay-png,make-gradient-png,keep-fwd-xfm,keep-inv-xfm,\
dir-save:,dir-xfm:,dir-png:,dir-scratch:,\
verbose,help,no-log,dry-run -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
VERBOSE=false
HELP=false
DRY_RUN=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -d | --dry-run) DRY_RUN=true ; shift ;;
    --recipe-json) RECIPE_JSON="$2" ; shift 2 ;;
    --recipe-name) RECIPE_NAME="$2" ; shift 2 ;;
    --fixed) FIXED="$2" ; shift 2 ;;
    --fixed-mask) FIXED_MASK="$2" ; shift 2 ;;
    --fixed-mask-dilation) FIXED_MASK="$2" ; shift 2 ;;
    --moving) MOVING="$2" ; shift 2 ;;
    --moving-mask) MOVING_MASK="$2" ; shift 2 ;;
    --moving-mask-dilation) MOVING_MASK_DILATION="$2" ; shift 2 ;;
    --mask-procedure) MASK_PROCEDURE="$2" ; shift 2 ;;
    --dir-template) DIR_TEMPLATE="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space-source) SPACE_SOURCE="$2" ; shift 2 ;;
    --space-target) SPACE_TARGET="$2" ; shift 2 ;;
    --dimensonality) DIMENSIONALITY="$2" ; shift 2 ;;
    --save-state) SAVE_STATE="$2" ; shift 2 ;;
    --restore-state) RESTORE_STATE="$2" ; shift 2 ;;
    --write-composite-transform) WRITE_COMPOSITE_TRANSFORM=true ; shift ;;
    --print-similarity-measure-interval) PRINT_SIMILARITY_MEASURE_INTERVAL="$2" ; shift 2 ;;
    --write-internal-volumes) WRITE_INTERNAL_VOLUMES="$2" ; shift 2 ;;
    --collapse-output-transforms) COLLAPSE_OUTPUT_TRANSFORMS=true ; shift ;;
    --initialize-transforms-per-stage) INITIALIZE_TRANSFORMS_PER_STAGE="true" ; shift ;;
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
    --use-estimate-learning-rate-once) USE_ESTIMATE_LERANING_RATE_ONCE=true ; shift ;;
    --winsorize-image-intensities) WINSORIZE_IMAGE_INTENSITIES="$2" ; shift 2 ;;
    --float) FLOAT=true ; shift ;;
    --random-seed) RANDOM_SEED="$2" ; shift 2 ;;
    --ants-verbose) ANTS_VERBOSE=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --label-xfm) LABEL_XFM="$2" ; shift 2 ;;
    --label-from) LABEL_FROM="$2" ; shift 2 ;;
    --label-to) LABEL_TO="$2" ; shift 2 ;;
    --label-reg) LABEL_REG="$2" ; shift 2 ;;
    --label-roi) LABEL_ROI="$2" ; shift 2 ;;
    --apply-to) APPLY_TO="$2" ; shift 2 ;;
    --make-overlay-png) MAKE_OVERLAY_PNG="true" ; shift ;;
    --make-gradient-png) MAKE_GRADIENT_PNG="true" ; shift ;;
    --png-overlay-bg-color) PNG_OVERLAY_BG_COLOR="$2" ; shift 2 ;;
    --png-overlay-bg-alpha) PNG_OVERLAY_BG_ALPHA="$2" ; shift 2 ;;
    --png-overlay-bg-thresh) PNG_OVERLAY_BG_THRESH="$2" ; shift 2 ;;
    --png-overlay-fg-color) PNG_OVERLAY_FG_COLOR="$2" ; shift 2 ;;
    --png-overlay-fg-alpha) PNG_OVERLAY_FG_ALPHA="$2" ; shift 2 ;;
    --png-overlay-fg-thresh) PNG_OVERLAY_FG_THRESH="$2" ; shift 2 ;;
    --png-overlay-layout) PNG_OVERLAY_LAYOUT="$2" ; shift 2 ;;
    --png-overlay-offset) PNG_OVERLAY_OFFSET="$2" ; shift 2 ;;
    --png-overlay-filename) PNG_OVERLAY_FILENAME="$2" ; shift 2 ;;
    --png-grad-color) PNG_GRAD_COLOR="$2" ; shift 2 ;;
    --png-grad-layout) PNG_GRAD_LAYOUT="$2" ; shift 2 ;;
    --png-grad-offset) PNG_GRAD_OFFSET="$2" ; shift 2 ;;
    --png-grad-filename) PNG_GRAD_FILENAME="$2" ; shift 2 ;;
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
if [[ "${DRY_RUN}" == "true" ]]; then NO_LOG=true; fi
if [[ "${VERBOSE}" == "true" ]]; then echo "Running the INC coregistration chef"; fi

# locate recipe ----------------------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>locating coregistration recipe"; fi
RECIPE_DEFAULT=${INC_LUT}/coregistration_recipes.json
PARAMS_DEFAULT=($(jq -r '.coregistration_parameters | keys_unsorted[]?' < ${RECIPE_DEFAULT}))
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
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# read parameter names from recipe ---------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>reading coregistration parameters"; fi
if [[ -n ${RECIPE_JSON} ]]; then
  RECIPES=($(jq -r '.coregistration_recipe | keys_unsorted[]?' < ${RECIPE_JSON}))
  if [[ " ${RECIPES[@]} " =~ " ${RECIPE_NAME} " ]]; then
    PARAMS_RECIPE=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}' | keys_unsorted[]?' < ${RECIPE_JSON}))
  else
    echo "ERROR [INC ${FCN_NAME}] Recipe not in JSON. Aborting."
    exit 2
  fi
fi
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# parse inputs and recipe together ---------------------------------------------
## variable specification order of priority
## 1. direct input to function
## 2. specified recipe
## 3. default values
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>parsing coregistration recipe and loading defaults"; fi
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
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# parse basic required information about MOVING images -------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>parsing MOVING images"; fi
MOVING=(${MOVING//,/ })
for (( i=0; i<${#MOVING[@]}; i++ )); do
  MOD+=($(getField -i ${MOVING[@]} -f modality))
done
MOD_STR="${MOD[@]}"
MOD_STR=${MOD_STR// /+}
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# Set up BIDs compliant variables and workspace --------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>gathering project and participant information"; fi
DIR_PROJECT=$(getDir -i ${MOVING[0]})
PID=$(getField -i ${MOVING[0]} -f sub)
SID=$(getField -i ${MOVING[0]} -f ses)
DIRPID=sub-${PID}
if [[ -n ${SID} ]]; then DIRPID=${DIRPID}/ses-${SID}; fi
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# set defaults as necessary ----------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>setting default file prefixes"; fi
if [[ "${PREFIX,,}" == "default" ]]; then
  PREFIX=$(getBidsBase -s -i ${MOVING[0]})
  if [[ -n ${PREP} ]]; then
    PREP="${PREP}+coreg"
    PREFIX=$(modField -i ${PREFIX} -r -f prep)
  fi
fi
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# set directories --------------------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>setting output directories"; fi
if [[ "${DIR_SAVE,,}" == "default" ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/${DIRPID}
fi
if [[ "${DIR_XFM,,}" == "default" ]]; then
  DIR_XFM=${DIR_PROJECT}/derivatives/inc/xfm/${DIRPID}
fi
if [[ "${DIR_SCRATCH,,}" == "default" ]]; then
  DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
fi
if [[ "${DIR_TEMPLATE,,}" == "default" ]]; then
  DIR_TEMPLATE=${INC_TEMPLATE}/${TEMPLATE}/${SPACE_SOURCE}
fi
if [[ "${MAKE_PNG}" == "true" ]]; then
  if [[ "${DIR_PNG,,}" == "default" ]]; then
    DIR_PNG=${DIR_PROJECT}/derivatives/inc/png/${DIRPID}
  fi
fi

## make directories 
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
if [[ "${KEEP_FWD_XFM}" == "true" ]] || [[ "${KEEP_INV_XFM}" == "true" ]]; then mkdir -p ${DIR_XFM}; fi
if [[ "${MAKE_PNG}" == "true" ]]; then mkdir -p ${DIR_PNG}; fi
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# parse fixed ------------------------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>parsing fixed/template images"; fi
if [[ "${FIXED}" == "optional" ]]; then
  unset FIXED
  for (( i=0; i<${#MOVING[@]}; i++ )); do
    if [[ -f ${DIR_TEMPLATE}/${TEMPLATE}_${SPACE_SOURCE}_${MOD[${i}]}.nii.gz ]]; then
      FIXED+=(${DIR_TEMPLATE}/${TEMPLATE}_${SPACE_SOURCE}_${MOD[${i}]}.nii.gz)
    else
      FIXED+=(${DIR_TEMPLATE}/${TEMPLATE}_${SPACE_SOURCE}_T1w.nii.gz)
    fi
  done
else
  FIXED=(${FIXED//,/ })
fi
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# check spacing ----------------------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>checking image spacing for output"; fi
FIX_SPACE="false"
if [[ "${SPACE_TARGET}" == "moving" ]]; then
  echo ${MOVING[0]}
  SPACE_MOVING=$(niiInfo -i ${MOVING[0]} -f spacing)
  echo b
  SPACE_FIXED=$(niiInfo -i ${FIXED[0]} -f spacing)
  echo c
  if [[ "${SPACE_MOVING}" != "${SPACE_FIXED}" ]]; then
    NEW_SPACE=${SPACE_MOVING// /x}
    FIX_SPACE="true"
  fi
  echo ""
  echo ${NEW_SPACE}
elif [[ "${SPACE_TARGET}" != "fixed" ]] && [[ "${SPACE_TARGET}" != "${SPACE_SOURCE}" ]]; then
  NEW_SPACE=$(convSpacing -i ${SPACE_TARGET})
  FIX_SPACE="true"
fi
echo 1
if [[ "${FIX_SPACE}" == "true" ]]; then
  for (( i=0; i<${#FIXED[@]}; i++ )); do
    TMOD=$(getField -i ${FIXED[${i}]} -f modality)
    echo 2
    if [[ "${DRY_RUN}" == "false" ]]; then
      mkdir -p ${DIR_SCRATCH}
      ResampleImage 3 ${FIXED[${i}]} ${DIR_SCRATCH}/FIXED_${i}_${TMOD}.nii.gz ${NEW_SPACE} 0
    fi
    echo 3
    FIXED[${i}]=${DIR_SCRATCH}/FIXED_${i}_${TMOD}.nii.gz
  done
fi
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# check for histogram matching -------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>set histogram matching"; fi
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
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# check masks ------------------------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>check masks"; fi
if [[ "${MOVING_MASK[0]}" != "optional" ]]; then
  MOVING_MASK=(${MOVING_MASK//,/ })
  if [[ ${#MOVING_MASK[@]} -ne ${#TRANSFORM[@]} ]] &&
     [[ ${#MOVING_MASK[@]} -ne 1 ]]; then
    echo "ERROR [INC ${FCN_NAME}] number of moving masks must equal 1 or the number of transforms"
    exit 4
  fi
  if [[ ${MOVING_MASK_DILATION} -ne 0 ]]; then
    for (( i=0; i<${#MOVING_MASK[@]}; i++ )); do
      TMOD=$(getField -i ${MOVING_MASK[${i}]} -f modality)
      ImageMath 3 ${DIR_SCRATCH}/MOVING_MASK_${i}_${TMOD}.nii.gz \
        MD ${MOVING_MASK[${i}]} ${MOVING_MASK_DILATION}
      MOVING_MASK[${i}]=${DIR_SCRATCH}/MOVING_MASK_${i}_${TMOD}.nii.gz
    done
  fi
  if [[ ${#MOVING_MASK[@]} -eq 1 ]] && [[ ${#MOVING[@]} -gt 1 ]]; then
    for (( i=1; i<${#MOVING[@]}; i++ )); do
      MOVING_MASK+=(${MOVING_MASK[0]})
    done
  fi
  if [[ "${MASK_PROCEDURE,,}" == *"apply"* ]]; then
    for (( i=0; i<${#MOVING[@]}; i++ )); do
      TMOD=$(getField -i ${MOVING[${i}]} -f modality)
      fslmaths ${MOVING[${i}]} -mas ${MOVING_MASK[${i}]} ${DIR_SCRATCH}/MOVING_${i}_${TMOD}.nii.gz
      MOVING[${i}]=${DIR_SCRATCH}/MOVING_${i}_${TMOD}.nii.gz
    done
  fi
fi
if [[ "${FIXED_MASK[0]}" != "optional" ]]; then
  FIXED_MASK=(${FIXED_MASK//,/ })
  if [[ ${#FIXED_MASK[@]} -ne ${#TRANSFORM[@]} ]] &&
     [[ ${#FIXED_MASK[@]} -ne 1 ]]; then
    echo "ERROR [INC ${FCN_NAME}] number of fixed masks must equal 1 or the number of transforms"
    exit 5
  fi
  if [[ ${FIXED_MASK_DILATION} -ne 0 ]]; then
    for (( i=0; i<${#FIXED_MASK[@]}; i++ )); do
      TMOD=$(getField -i ${FIXED_MASK[${i}]} -f modality)
      ImageMath 3 ${DIR_SCRATCH}/FIXED_MASK_${i}_${TMOD}.nii.gz \
        MD ${FIXED_MASK[${i}]} ${FIXED_MASK_DILATION}
      FIXED_MASK[${i}]=${DIR_SCRATCH}/FIXED_MASK_${i}_${TMOD}.nii.gz
    done
  fi
  if [[ "${FIX_SPACE}" == "true" ]]; then
    for (( i=0; i<${#FIXED_MASK[@]}; i++ )); do
      TMOD=$(getField -i ${FIXED_MASK[${i}]} -f modality)
      if [[ "${DRY_RUN}" == "false" ]]; then
        mkdir -p ${DIR_SCRATCH}
        antsApplyTransforms -d 3 -n GenericLabel \
          -i ${FIXED_MASK[${i}]} \
          -o ${DIR_SCRATCH}/FIXED_MASK_${i}_${TMOD}.nii.gz \
          -r ${FIXED[0]}
      fi
      FIXED_MASK[${i}]=${DIR_SCRATCH}/FIXED_MASK_${i}_${TMOD}.nii.gz
    done
  fi
  if [[ ${#FIXED_MASK[@]} -eq 1 ]] && [[ ${#FIXED[@]} -gt 1 ]]; then
    for (( i=1; i<${#FIXED[@]}; i++ )); do
      FIXED_MASK+=(${FIXED_MASK[0]})
    done
  fi
  if [[ "${MASK_PROCEDURE,,}" == *"apply"* ]]; then
    for (( i=0; i<${#FIXED[@]}; i++ )); do
      TMOD=$(getField -i ${FIXED[${i}]} -f modality)
      fslmaths ${FIXED[${i}]} -mas ${FIXED_MASK[${i}]} ${DIR_SCRATCH}/FIXED_${i}_${TMOD}.nii.gz
      FIXED[${i}]=${DIR_SCRATCH}/FIXED_${i}_${TMOD}.nii.gz
    done
  fi
fi
if [[ "${MOVING_MASK[0]}" != "optional" ]] && \
   [[ "${FIXED_MASK[0]}" != "optional" ]] && \
   [[ ${#FIXED_MASK[@]} -ne ${#MOVING_MASK[@]} ]]; then
  echo "ERROR [INC ${FCN_NAME}] number of fixed and moving masks must match"
  exit 6
fi
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# generate output names --------------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>generate output names"; fi
PREP=$(getField -i ${PREFIX} -f prep)
if [[ -n ${PREP} ]]; then PREFIX=$(modField -i ${PREFIX} -r -f prep); fi
if [[ -z ${RECIPE_NAME} ]]; then RECIPE_NAME=coreg; fi
if [[ "${LABEL_FROM,,}" == "default" ]]; then LABEL_FROM=$(getSpace -i ${MOVING[0]}); fi
if [[ "${LABEL_TO,,}" == "default" ]]; then LABEL_TO=$(getSpace -i ${FIXED[0]}); fi
if [[ "${LABEL_REG,,}" == "default" ]]; then
  if [[ -n ${PREP} ]]; then
    LABEL_REG=prep-${PREP}+${RECIPE_NAME}+${LABEL_TO}
  else
    LABEL_REG=reg-${RECIPE_NAME}+${LABEL_TO}
  fi
fi

for (( i=0; i<${#MOVING[@]}; i++ )); do
  MOVING_OUTPUT+=(${PREFIX})
  if [[ -n ${PREP} ]]; then
    MOVING_OUTPUT[${i}]="${MOVING_OUTPUT[${i}]}_${LABEL_REG}"
  else
    MOVING_OUTPUT[${i}]="${MOVING_OUTPUT[${i}]}_${LABEL_REG}"
  fi
  TMOD=$(getField -i ${MOVING[${i}]} -f modality)
  MOVING_OUTPUT[${i}]="${MOVING_OUTPUT[${i}]}_${TMOD}.nii.gz"
done
if [[ "${VERBOSE}" == "true" ]]; then echo -ne " MOVING"; fi

APPLY_TO=(${APPLY_TO//,/ })
if [[ "${APPLY_TO[0]}" != "optional" ]]; then
  for (( i=0; i<${#APPLY_TO[@]}; i++ )); do
    APPLY_OUTPUT+=$(getBidsBase -s -i ${APPLY_TO[${i}]})
    TMOD=$(getField -i ${APPLY_TO[${i}]} -f modality)
    APPLY_OUTPUT[${i}]="${APPLY_OUTPUT[${i}]}_${LABEL_REG}_${TMOD}.nii.gz"
  done
  if [[ "${VERBOSE}" == "true" ]]; then echo -ne " EXTRA"; fi
fi

if [[ "${KEEP_FWD_XFM}" == "true" ]] || [[ "${KEEP_INV_XFM}" == "true" ]]; then
  LABEL_XFM=(${LABEL_XFM//,/ })
  if [[ "${LABEL_XFM[0]}" == "default" ]]; then
    if [[ "${TRANSFORM[@],,}" == *"bsplineexponential"* ]]; then
      LABEL_XFM[0]="bsplineExp"
    elif [[ "${TRANSFORM[@],,}" == *"exponential"* ]]; then
      LABEL_XFM[0]="exp"
    elif [[ "${TRANSFORM[@],,}" == *"bsplinesyn"* ]]; then
      LABEL_XFM[0]="bsplineSyn"
    elif [[ "${TRANSFORM[@],,}" == *"syn"* ]]; then
      LABEL_XFM[0]="syn"
    elif [[ "${TRANSFORM[@],,}" == *"timevaryingbsplinevelocityfield"* ]]; then
      LABEL_XFM[0]="timeVaryingBspline"
    elif [[ "${TRANSFORM[@],,}" == *"timevaryingvelocityfield"* ]]; then
      LABEL_XFM[0]="timeVarying"
    elif [[ "${TRANSFORM[@],,}" == *"bsplinedisplacementfield"* ]]; then
      LABEL_XFM[0]="bsplineDisp"
    elif [[ "${TRANSFORM[@],,}" == *"gaussiandisplacementfield"* ]]; then
      LABEL_XFM[0]="displacement"
    elif [[ "${TRANSFORM[@],,}" == *"bspline"* ]]; then
      LABEL_XFM[0]="bspline"
    else
      LABEL_XFM[0]="none"
    fi
    if [[ "${TRANSFORM[@],,}" == *"compositeaffine"* ]]; then
      LABEL_XFM[1]="affineComposite"
    elif [[ "${TRANSFORM[@],,}" == *"affine"* ]]; then
      LABEL_XFM[1]="affine"
    elif [[ "${TRANSFORM[@],,}" == *"similarity"* ]]; then
      LABEL_XFM[1]="similarity"
    elif [[ "${TRANSFORM[@],,}" == *"rigid"* ]]; then
      LABEL_XFM[1]="rigid"
    elif [[ "${TRANSFORM[@],,}" == *"translation"* ]]; then
      LABEL_XFM[1]="translation"
    else
      LABEL_XFM[1]="none"
    fi
  fi
fi
if [[ "${KEEP_FWD_XFM}" == "true" ]] || [[ "${KEEP_INV_XFM}" == "true" ]] ; then
  if [[ "${LABEL_XFM[1]}" != "none" ]]; then
    AFFINE_OUTPUT=${PREFIX}_mod-${MOD_STR}_from-${LABEL_FROM}_to-${LABEL_TO}_xfm-${LABEL_XFM[1]}.mat
  fi
  if [[ "${VERBOSE}" == "true" ]]; then echo -ne " XFM"; fi
fi
if [[ "${KEEP_FWD_XFM}" == "true" ]]; then
  if [[ "${LABEL_XFM[0]}" != "none" ]]; then
    FWD_OUTPUT=${PREFIX}_mod-${MOD_STR}_from-${LABEL_FROM}_to-${LABEL_TO}_xfm-${LABEL_XFM[0]}.nii.gz
  fi
fi
if [[ "${KEEP_INV_XFM}" == "true" ]]; then
  if [[ "${LABEL_XFM[0]}" != "none" ]]; then
    INV_OUTPUT=${PREFIX}_mod-${MOD_STR}_from-${LABEL_FROM}_to-${LABEL_TO}_xfm-${LABEL_XFM[0]}+inverse.nii.gz
  fi
fi
if [[ "${MAKE_OVERLAY_PNG}" == "true" ]]; then
  TNAME=${MOVING_OUTPUT[0]%%.*}
  PNG_OVERLAY_FILENAME=${TNAME}_overlay
  if [[ "${VERBOSE}" == "true" ]]; then echo -ne " PNG-OVERLAY"; fi
fi
if [[ "${MAKE_GRADIENT_PNG}" == "true" ]]; then
  TNAME=${MOVING_OUTPUT[0]%%.*}
  PNG_GRAD_FILENAME=${TNAME}_gradientMagDiff
  if [[ "${VERBOSE}" == "true" ]]; then echo -ne " PNG-GRADIENT"; fi
fi
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# show outputs for dry run -----------------------------------------------------
if [[ "${DRY_RUN}" == "true" ]] || [[ "${VERBOSE}" == "true" ]]; then
  echo ""
  echo "PARAMETERS:---------------------------------------------------------------------"
  for (( i=0; i<${#PARAMS_DEFAULT[@]}; i++ )); do
    VAR_NAME=${PARAMS_DEFAULT[${i}]^^}
    VAR_NAME=${VAR_NAME//-/_}
    eval "echo ${VAR_NAME}="'${'${VAR_NAME}'[@]}'
  done
  echo ""
  echo "OUTPUT:------------------------------------------------------------------"
  echo "TRANSFORMED IMAGES:"
  echo -e "\t${DIR_SAVE}"
  for (( i=0; i<${#MOVING[@]}; i++ )); do echo -e "\t\t${MOVING_OUTPUT[${i}]}"; done
  if [[ "${APPLY_TO[0]}" != "optional" ]]; then
    for (( i=0; i<${#APPLY_TO[@]}; i++ )); do echo -e "\t\t${APPLY_OUTPUT[${i}]}"; done
  fi
  if [[ "${KEEP_FWD_XFM}" == "true" ]] || [[ "${KEEP_INV_XFM}" == "true" ]]; then
    echo "TRANSFORMS:"
    echo -e "\t${DIR_XFM}"
    if [[ -n ${AFFINE_OUTPUT} ]]; then echo -e "\t\t${AFFINE_OUTPUT}"; fi
    if [[ -n ${FWD_OUTPUT} ]]; then echo -e "\t\t${FWD_OUTPUT}"; fi
    if [[ -n ${INV_OUTPUT} ]]; then echo -e "\t\t${INV_OUTPUT}"; fi
  fi
  if [[ "${MAKE_PNG}" == "true" ]]; then
    echo "PNG:"
    echo -e "\t${DIR_PNG}"
    echo -e "\t\t${PNG_OVERLAY_FILENAME}"
    echo -e "\t\t${PNG_GRAD_FILENAME}"
 fi
fi

### write ANTS registration function ===========================================
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>write coregistration function"; fi
antsCoreg="antsRegistration"
antsCoreg="${antsCoreg} --dimensionality ${DIMENSIONALITY}"
antsCoreg="${antsCoreg} --output ${DIR_SCRATCH}/xfm_"
if [[ "${SAVE_STATE}" != "optional" ]]; then
  antsCoreg="${antsCoreg} --save-state ${SAVE_STATE}"
fi
if [[ "${RESTORE_STATE}" != "optional" ]]; then
  antsCoreg="${antsCoreg} --restore-state ${RESTORE_STATE}"
fi
if [[ "${WRITE_COMPOSITE_TRANSFORM}" == "true" ]]; then
  antsCoreg="${antsCoreg} --write-composite-transform 1"
else  
  antsCoreg="${antsCoreg} --write-composite-transform 0"
fi
if [[ ${PRINT_SIMILARITY_MEASURE_INTERVAL} -ne 0 ]]; then
  antsCoreg="${antsCoreg} --print-similarity-measure-interval ${PRINT_SIMILARITY_MEASURE_INTERVAL}"
fi
if [[ ${WRITE_INTERNAL_VOLUMES} -ne 0 ]]; then
  antsCoreg="${antsCoreg} --write-internal-voumes ${WRITE_INTERNAL_VOLUMES}"
fi
if [[ "${COLLAPSE_OUTPUT_TRANSFORMS}" == "true" ]]; then
  antsCoreg="${antsCoreg} --collapse-output-transforms 1"
else
  antsCoreg="${antsCoreg} --collapse-output-transforms 0"
fi
if [[ "${INITIALIZE_TRANSFORMS_PER_STAGE}" == "true" ]]; then
  antsCoreg="${antsCoreg} --initialize-transforms-per-stage 1"
else
  antsCoreg="${antsCoreg} --initialize-transforms-per-stage 0"
fi
if [[ "${RESTRICT_DEFORMATION}" != "optional" ]]; then
  antsCoreg="${antsCoreg} --resrict-deformation ${RESTRICT_DEFORMATION}"
fi
if [[ "${INITIAL_FIXED_TRANSFORM}" == "default" ]]; then
  antsCoreg="${antsCoreg} --initial-fixed-transform [${MOVING[0]},${FIXED[0]},1]"
elif [[ "${INITIAL_FIXED_TRANSFORM}" != "optional" ]]; then
  INITIAL_FIXED_TRANSFORM=(${INITIAL_FIXED_TRANSFORM//;/ })
  for (( i=0; i<${#INITIAL_FIXED_TRANSFORM[@]}; i++ )); do
    antsCoreg="${antsCoreg} --initial-fixed-transform ${INITIAL_FIXED_TRANSFORM[${i}]}"
  done
fi
if [[ "${INITIAL_MOVING_TRANSFORM}" == "default" ]]; then
  antsCoreg="${antsCoreg} --initial-moving-transform [${FIXED[0]},${MOVING[0]},1]"
elif [[ "${INITIAL_MOVING_TRANSFORM}" != "optional" ]]; then
  INITIAL_MOVING_TRANSFORM=(${INITIAL_MOVING_TRANSFORM//;/ })
  for (( i=0; i<${#INITIAL_MOVING_TRANSFORM[@]}; i++ )); do
    antsCoreg="${antsCoreg} --initial-moving-transform ${INITIAL_MOVING_TRANSFORM[${i}]}"
  done
fi
if [[ "${MASK_PROCEDURE}" == "restrict" ]] \
&& [[ "${FIXED_MASK[0]}" != "optional" ]] \
&& [[ ${#FIXED_MASK[@]} -eq 1 ]]; then
  antsCoreg="${antsCoreg} --masks [${FIXED_MASK[0]},${MOVING_MASK[0]}]"
fi
for (( i=0; i<${#TRANSFORM[@]}; i++ )); do
  antsCoreg="${antsCoreg} --transform ${TRANSFORM[${i}]}"
  METRIC_STR=(${METRIC[${i}]//fixedImage,movingImage/ })
  for (( j=0; j<${#MOVING[@]}; j++ )); do
    antsCoreg="${antsCoreg} --metric ${METRIC_STR[0]}${FIXED[${j}]},${MOVING[${j}]}${METRIC_STR[1]}"
  done
  if [[ "${MASK_PROCEDURE}" == "restrict" ]] \
  && [[ "${FIXED_MASK[0]}" != "optional" ]] \
  && [[ ${#FIXED_MASK[@]} -gt 1 ]]; then
    antsCoreg="${antsCoreg} --masks [${FIXED_MASK[${i}]},${MOVING_MASK[${i}]}]"
  fi
  antsCoreg="${antsCoreg} --convergence ${CONVERGENCE[${i}]}"
  antsCoreg="${antsCoreg} --smoothing-sigmas ${SMOOTHING_SIGMAS[${i}]}"
  antsCoreg="${antsCoreg} --shrink-factors ${SHRINK_FACTORS[${i}]}"
done
antsCoreg="${antsCoreg} --use-histogram-matching ${USE_HISTOGRAM_MATCHING}"
if [[ "${USE_ESTIMATE_LEARNING_RATE_ONCE}" == "true" ]]; then
  antsCoreg="${antsCoreg} --use-estimate-learning-rate-once 1"
else
  antsCoreg="${antsCoreg} --use-estimate-learning-rate-once 0"
fi
if [[ "${WINSORIZE_IMAGE_INTENSITIES}" != "optional" ]]; then
  antsCoreg="${antsCoreg} --winsorize-image-intensities ${WINSORIZE_IMAGE_INTENSITIES}"
fi
if [[ "${FLOAT}" == "true" ]]; then
  antsCoreg="${antsCoreg} --float 1"
else
  antsCoreg="${antsCoreg} --float 0"
fi
if [[ "${ANTS_VERBOSE}" == "true" ]]; then
  antsCoreg="${antsCoreg} --verbose 1"
else
  antsCoreg="${antsCoreg} --verbose 0"
fi
antsCoreg="${antsCoreg} --random-seed ${RANDOM_SEED}"
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

if [[ "${DRY_RUN}" == "true" ]] || [[ "${VERBOSE}" == "true" ]]; then
  echo ""
  echo "ANTs Coregistration Call -------------------------------------------------------"
  echo ""
  echo "${antsCoreg}"
  echo ""
fi
if [[ "${DRY_RUN}" == "true" ]]; then
  exit 0
fi

# make directories ------------------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>make output directories"; fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
if [[ "${KEEP_FWD_XFM}" == "true" ]] || [[ "${KEEP_INV_XFM}" == "true" ]]; then mkdir -p ${DIR_XFM}; fi
if [[ "${MAKE_PNG}" == "true" ]]; then mkdir -p ${DIR_PNG}; fi
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# run coregistration -----------------------------------------------------------
if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>run coregistration"; fi
eval "${antsCoreg}"
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# apply transforms =============================================================
if [[ "${VERBOSE}" == "true" ]]; then echo -e ">>>apply transforms to MOVING"; fi
mkdir -p ${DIR_SAVE}
for (( i=0; i<${#MOVING[@]}; i++ )); do
  apply_xfm="antsApplyTransforms -d 3"
  if [[ "${INTERPOLATION}" == "default" ]]; then
    apply_xfm="${apply_xfm} -n BSpline[3]"
  else
    apply_xfm="${apply_xfm} -n ${INTERPOLATION}"
  fi
  apply_xfm="${apply_xfm} -i ${MOVING[${i}]}"
  apply_xfm="${apply_xfm} -o ${DIR_SAVE}/${MOVING_OUTPUT[${i}]}"
  if [[ -f ${DIR_SCRATCH}/xfm_1Warp.nii.gz ]]; then
    apply_xfm="${apply_xfm} -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz"
  fi
  if [[ -f ${DIR_SCRATCH}/xfm_0GenericAffine.mat ]]; then
    apply_xfm="${apply_xfm} -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat"
  fi
  apply_xfm="${apply_xfm} -r ${FIXED[0]}"
  if [[ "${VERBOSE}" == "true" ]]; then echo -e "${apply_xfm}"; fi
  eval ${apply_xfm}
done
if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi

# apply to extra images --------------------------------------------------------
if [[ "${APPLY_TO[0]}" != "optional" ]]; then
  if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>apply transforms to ADDITIONAL IMAGES"; fi
  for (( i=0; i<${#APPLY_TO[@]}; i++ )); do
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
    apply_xfm="${apply_xfm} -i ${APPLY_TO[${i}]}"
    apply_xfm="${apply_xfm} -o ${DIR_SAVE}/${APPLY_OUTPUT[${i}]}"
    if [[ -f ${DIR_SCRATCH}/xfm_1Warp.nii.gz ]]; then
      apply_xfm="${apply_xfm} -t ${DIR_SCRATCH}/xfm_1Warp.nii.gz"
    fi
    if [[ -f ${DIR_SCRATCH}/xfm_0GenericAffine.mat ]]; then
      apply_xfm="${apply_xfm} -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat"
    fi
    apply_xfm="${apply_xfm} -r ${FIXED[0]}"
    if [[ "${VERBOSE}" == "true" ]]; then echo -e "${apply_xfm}"; fi
    eval ${apply_xfm}
  done
  if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi
fi

# move results to desired destination ------------------------------------------
if [[ "${KEEP_FWD_XFM}" == "true" ]] || [[ "${KEEP_INV_XFM}" == "true" ]]; then
  if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>move transforms"; fi
fi
if [[ -f ${DIR_SCRATCH}/xfm_0GenericAffine.mat ]]; then
  mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat ${DIR_XFM}/${AFFINE_OUTPUT}
fi
if [[ -f ${DIR_SCRATCH}/xfm_1Warp.nii.gz ]]; then
  mv ${DIR_SCRATCH}/xfm_1Warp.nii.gz ${DIR_XFM}/${FWD_OUTPUT}
fi
if [[ -f ${DIR_SCRATCH}/xfm_1InverseWarp.nii.gz ]]; then
  mv ${DIR_SCRATCH}/xfm_1InverseWarp.nii.gz ${DIR_XFM}/${INV_OUTPUT}
fi
if [[ "${KEEP_FWD_XFM}" == "true" ]] || [[ "${KEEP_INV_XFM}" == "true" ]]; then
  if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi
fi

# plot output for review -------------------------------------------------------
if [[ "${MAKE_OVERLAY_PNG}" == "true" ]]; then
  if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>generate results PNG"; fi
  overlay_png="make3Dpng"
  overlay_png="${overlay_png} --bg ${FIXED[0]}"
  overlay_png=${overlay_png}' --bg-color "'${PNG_OVERLAY_BG_COLOR}'"'
  overlay_png="${overlay_png} --bg-alpha ${PNG_OVERLAY_BG_ALPHA}"
  overlay_png=${overlay_png}' --bg-thresh "'${PNG_OVERLAY_BG_THRESH}'"'
  overlay_png="${overlay_png} --fg ${DIR_SAVE}/${MOVING_OUTPUT[0]}"
  overlay_png=${overlay_png}' --fg-color "'${PNG_OVERLAY_FG_COLOR}'"'
  overlay_png="${overlay_png} --fg-alpha ${PNG_OVERLAY_FG_ALPHA}"
  overlay_png=${overlay_png}' --fg-thresh "'${PNG_OVERLAY_FG_THRESH}'"'
  overlay_png="${overlay_png} --fg-cbar"
  overlay_png=${overlay_png}' --layout "'${PNG_OVERLAY_LAYOUT}'"'
  overlay_png=${overlay_png}' --offset "'${PNG_OVERLAY_OFFSET}'"'
  overlay_png=${overlay_png}' --filename "'${PNG_OVERLAY_FILENAME}'"'
  overlay_png="${overlay_png} --dir-save ${DIR_PNG}"
  eval ${overlay_png}
  if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi
fi
if [[ "${MAKE_GRADIENT_PNG}" == "true" ]]; then
  if [[ "${VERBOSE}" == "true" ]]; then echo -ne ">>>generate results PNG"; fi
  FIXED_SZ=($(niiInfo -i ${FIXED[0]} -f spacing))
  VXL_SZ=$(echo "scale=1; ${FIXED_SZ[0]}*${FIXED_SZ[1]}*${FIXED_SZ[2]}" | bc -l)
  GRAD_SIGMA=$(echo "scale=1; ${VXL_SZ}/2" | bc -l)
  ImageMath 3 ${DIR_SCRATCH}/grad_fixed.nii.gz \
    Grad ${FIXED[0]} ${GRAD_SIGMA} 1
  ImageMath 3 ${DIR_SCRATCH}/grad_moving.nii.gz \
    Grad ${DIR_SAVE}/${MOVING_OUTPUT[0]} ${GRAD_SIGMA} 1  
  ImageMath 3 ${DIR_SCRATCH}/grad_moving_histMatch.nii.gz \
    HistogramMatch ${DIR_SCRATCH}/grad_moving.nii.gz ${DIR_SCRATCH}/grad_fixed.nii.gz
  ImageMath 3 ${DIR_SCRATCH}/grad_diff.nii.gz \
    - ${DIR_SCRATCH}/grad_moving.nii.gz ${DIR_SCRATCH}/grad_fixed.nii.gz
  grad_png="make3Dpng"
  grad_png="${grad_png} --bg ${DIR_SCRATCH}/grad_diff.nii.gz"
  grad_png=${grad_png}' --bg-color "'${PNG_GRAD_COLOR}'"'
  grad_png=${grad_png}' --layout "'${PNG_GRAD_LAYOUT}'"'
  grad_png=${grad_png}' --offset "'${PNG_GRAD_OFFSET}'"'
  grad_png=${grad_png}' --filename "'${PNG_GRAD_FILENAME}'"'
  grad_png="${grad_png} --dir-save ${DIR_PNG}"
  eval ${grad_png}
  if [[ "${VERBOSE}" == "true" ]]; then echo " DONE"; fi
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0


