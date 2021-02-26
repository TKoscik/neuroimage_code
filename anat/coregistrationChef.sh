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
OPTS=$(getopt -o hvl --long recipe-json:,recipe-name:,\
fixed:,moving:,fixed-mask:,moving-mask:,init-xfm:,\
dimensonality:,random-seed:,float:,collapse-output-transforms:,\
initial-moving-transform:,transform:,metric:,convergence:,soothing-sigmas:,shrink-factors:,\
prefix:,mask-dilation:,roi-label:,xfm-label:,template:,space-source:,space-target:,\
interpolation:,apply-to:,\
dir-save:,dir-xfm:,dir-plot:,dir-scratch:,\
print-xfm,no-png,no-fwd-xfm,no-inv-xfm,\
verbose,help,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
RECIPE_JSON=
RECIPE_NAME=

FIXED=
MOVING=
FIXED_MASK=
MOVING_MASK=
INIT_XFM=

DIMENSIONALITY=
RANDOM_SEED=
FLOAT=
COLLAPSE_OUTPUT_XFMS=
INITIAL_MOVING_XFM=
TRANSFORM=
METRIC=
CONVERGENCE=
SMOOTHING_SIGMAS=
SHRINK_FACTORS=

PREFIX=
MASK_DILATION=
ROI_LABEL=
XFM_LABEL=
TEMPLATE=
SPACE_SOURCE=
SPACE_TARGET=
INTERPOLATION=
APPLY_TO=

DIR_SAVE=
DIR_XFM=
DIR_PNG=
DIR_SCRATCH=

PRINT_ANTS=false
NO_PNG=false
NO_FWD_XFM=false
NO_INV_XFM=false
VERBOSE=
HELP=

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --print-ants) PRINT_ANTS=true ; shift ;;
    --no-png) NO_PNG=true ; shift ;;
    --no-fwd-xfm) NO_FWD_XFM=true ; shift ;;
    --no-inv-xfm) NO_INV_XFM=true ; shift ;;
    --recipe-json) RECIPE_JSON="$2" ; shift 2 ;;
    --recipe-name) RECIPE_NAME="$2" ; shift 2 ;;
    --fixed) FIXED="$2" ; shift 2 ;;
    --moving) MOVING="$2" ; shift 2 ;;
    --fixed-mask) FIXED_MASK="$2" ; shift 2 ;;
    --moving-mask) MOVING_MASK="$2" ; shift 2 ;;
    --dimensonality) DIMENSIONALITY="$2" ; shift 2 ;;
    --random-seed) RANDOM_SEED="$2" ; shift 2 ;;
    --float) FLOAT="$2" ; shift 2 ;;
    --collapse-output-transforms) COLLAPSE_OUTPUT_XFMS="$2" ; shift 2 ;;
    --initial-moving-transform) INITIAL_MOVING_XFM="$2" ; shift 2 ;;
    --transform) TRANSFORM="$2" ; shift 2 ;;
    --metric) METRIC="$2" ; shift 2 ;;
    --convergence) CONVERGENCE="$2" ; shift 2 ;;
    --soothing-sigmas) SMOOTHING_SIGMAS="$2" ; shift 2 ;;
    --shrink-factors) SHRINK_FACTORS="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --mask-dilation) MASK_DILATION="$2" ; shift 2 ;;
    --roi-label) ROI_LABEL="$2" ; shift 2 ;;
    --xfm-label) XFM_LABEL="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space-source) SPACE_SOURCE="$2" ; shift 2 ;;
    --space-target) SPACE_TARGET="$2" ; shift 2 ;;
    --interpolation) INTERPOLATION="$2" ; shift 2 ;;
    --apply-to) APPLY_TO="$2" ; shift 2 ;;
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
# locate recipe ----------------------------------------------------------------
if [[ -n ${RECIPE_NAME} ]]; then
  if [[ -z ${RECIPE_JSON} ]]; then
    RECIPE_JSON=${INC_LUT}/coregistration_recipes.json
  else
    echo "WARNING [INC ${FCN_NAME}] Operating without a coregistration recipe, default values may be insufficient, all variables should be specified"
  fi
fi
if [[ ! -f ${RECIPE_JSON} ]]; fi
  echo "ERROR [INC ${FCN_NAME}] Recipe JSON not found. Aborting."
  exit 1
fi

# read parameter names from recipe ---------------------------------------------
if [[ -n ${RECIPE_JSON} ]]; then
  RECIPES=($(jq -r '.coregistration_recipe | keys_unsorted' < ${RECIPE_JSON} | tr -d ' [],"'))
  if [[ " ${RECIPES[@]} " =~ " ${RECIPE_NAME} " ]]; then
    RECIPE_PARAMETERS=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.parameters | keys_unsorted' < ${RECIPE_JSON} | tr -d ' [],"'))
    RECIPE_REQUIRED=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.required | keys_unsorted' < ${RECIPE_JSON} | tr -d ' [],"'))
    RECIPE_OPTIONAL=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.optional | keys_unsorted' < ${RECIPE_JSON} | tr -d ' [],"'))
  else
    echo "ERROR [INC ${FCN_NAME}] Recipe not in JSON. Aborting."
    exit 2
  fi
fi

# parse basic required information about MOVING images -------------------------
MOVING=${MOVING//,/ }
MOVING_N=${#MOVING[@]}

# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(getDir -i ${MOVING[0]})
PID=$(getField -i ${MOVING[0]} -f sub)
SID=$(getField -i ${MOVING[0]} -f ses)
DIRPID=sub-${PID}
if [[ -n ${SID} ]]; then DIRPID=${DIRPID}/ses-${SID}; fi

# set file prefix for output ---------------------------------------------------
if [[ -z ${PREFIX} ]]; then
  if [[ " ${RECIPE_REQUIRED[@],,} " =~ " prefix " ]]; then
    echo "ERROR [INC ${FCN_NAME}] prefix required for ${RECIPE_NAME}"
    exit 3
  else
    PREFIX=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.optional.prefix' < ${RECIPE_JSON} | tr -d ' [],"'))
    if [[ "${PREFIX,,}" == "default" ]]; then
      PREFIX=$(getBidsBase -s -i ${MOVING[0]})
      PREP=$(getField -i ${PREFIX} -f prep)
      if [[ -n ${PREP} ]]; then
        PREP="${PREP}+"
        PREFIX=$(modField -i ${PREFIX} -r -f prep)
      fi
    fi
  fi
fi

# set locations for output -----------------------------------------------------
## make directories just before they are needed in case of crashing earlier
if [[ -z "${DIR_SAVE}" ]]; then
  if [[ " ${RECIPE_REQUIRED[@],,} " =~ " dir-save " ]]; then
    echo "ERROR [INC ${FCN_NAME}] dir-save required ${RECIPE_NAME}"
    exit 4
  else
    DIR_SAVE=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.optional."dir-save"' < ${RECIPE_JSON} | tr -d ' [],"'))
    if [[ "${DIR_SAVE,,}" == "default" ]] || [[ "${DIR_SAVE,,}" == "null" ]]; then
      DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/${DIRPID}
    fi
  fi
fi

if [[ -z "${DIR_XFM}" ]]; then
  if [[ " ${RECIPE_REQUIRED[@],,} " =~ " dir-xfm " ]]; then
    echo "ERROR [INC ${FCN_NAME}] dir-xfm required for ${RECIPE_NAME}"
    exit 5
  else
    DIR_XFM=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.optional."dir-xfm"' < ${RECIPE_JSON} | tr -d ' [],"'))
    if [[ "${DIR_XFM,,}" == "default" ]] || [[ "${DIR_XFM,,}" == "null" ]]; then
      DIR_XFM=${DIR_PROJECT}/derivatives/inc/xfm/${DIRPID}
    fi
  fi
fi

if [[ -z "${DIR_SCRATCH}" ]]; then
  if [[ " ${RECIPE_REQUIRED[@],,} " =~ " dir-xfm " ]]; then
    echo "ERROR [INC ${FCN_NAME}] dir-xfm required for ${RECIPE_NAME}"
    exit 6
  else
    DIR_SCRATCH=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.optional."dir-scratch"' < ${RECIPE_JSON} | tr -d ' [],"'))
    if [[ "${DIR_SCRATCH,,}" == "default" ]] || [[ "${DIR_SCRATCH,,}" == "null" ]]; then
      DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
    fi
  fi
fi

# parse transforms basics ------------------------------------------------------
if [[ -z ${TRANSFORM} ]]; then
  TRANSFORM=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.parameters.transform[]' < ${RECIPE_JSON} | tr -d ' "'))
  if [[ "${TRANSFORM}" == "null" ]]; then
    echo "ERROR [INC ${FCN_NAME}] transform required for all coregistrations"
    exit 7
  fi
else
  TRANSFORM=(${TRANSFORM//;/ })
fi

# parse additional MOVING files ------------------------------------------------
if [[ -z ${MOVING_MASK} ]]; then
  if [[ " ${RECIPE_REQUIRED[@],,} " =~ " moving-mask " ]]; then
    echo "ERROR [INC ${FCN_NAME}] moving-mask required for ${RECIPE_NAME}"
    exit 8
  fi
else
  MOVING_MASK=(${MOVING_MASK//,/ })
  if [[ ${#MOVING_MASK[@]} -ne 1 ]] || [[ ${#MOVING_MASK[@]} -ne ${#TRANSFORM[@]} ]]; then
    echo "ERROR [INC ${FCN_NAME}] moving-mask must be of length 1 or equal to the number of transforms"
    exit 9
  fi
fi

## get moving modalities
for (( i=0; i<${#MOVING[@]}; i++ )); do
  MOD+=($(getField -i ${MOVING[@]} -f modality))
done


# parse fixed images -----------------------------------------------------------
if [[ -z ${TEMPLATE} ]]; then
  if [[ -z ${FIXED} ]]; then
    if [[ " ${RECIPE_OPTIONAL[@],,} " =~ " template " ]]; then
      # using a template for registration recipe - - - -
      TEMPLATE=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.optional.template' < ${RECIPE_JSON} | tr -d ' [],"'))
      if [[ "${TEMPLATE}" == "null" ]]; then
        echo "ERROR [INC ${FCN_NAME}] ${RECIPE_NAME} requires a template, default not specified"
        exit 10
      fi
      # load template directory - - - -
      if [[ -z ${DIR_TEMPLATE} ]]; then
        DIR_TEMPLATE=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.optional."dir-template"' < ${RECIPE_JSON} | tr -d ' [],"'))
        if [[ "${DIR_TEMPLATE}" == "default" ]] || [[ "${DIR_TEMPLATE}" == "null" ]]; then
          DIR_TEMPLATE=${INC_TEMPLATE}
        fi
      fi
      if [[ ! -d ${DIR_TEMPLATE}/${TEMPLATE} ]]; then
        echo "ERROR [INC ${FCN_NAME}] template directory not found"
        exit 11
      fi
      # load and check template spacing - - - -
      if [[ -z ${SPACE_SOURCE} ]]; then
        SPACE_SOURCE=($(jq -r '.coregistration_recipe.'${RECIPE_NAME}'.optional."space-source"' < ${RECIPE_JSON} | tr -d ' [],"'))
        if [[ "${SPACE_SOURCE}" == "null" ]]; then
          if [[ -d ${INC_TEMPLATE}/${TEMPLATE}/700um ]]; then
            SPACE_SOURCE="700um"
          elif [[ -d ${INC_TEMPLATE}/${TEMPLATE}/1mm ]]; then
            SPACE_SOURCE="1mm"
          fi
        fi
      fi
      if [[ ! -d ${DIR_TEMPLATE}/${TEMPLATE}/${SPACE_SOURCE} ]]; then
        echo "ERROR [INC ${FCN_NAME}] ${DIR_TEMPLATE}/${TEMPLATE}/${SPACE_SOURCE} not found"
        exit 12
      fi
      # select FIXED images from template based on availability template folder and MOVING modality
      HIST_MATCH=1
      for (( i=0; i<${#MOVING[@]}; i++ )); do
        CHK_MOD=${DIR_TEMPLATE}/${TEMPLATE}/${SPACE_SOURCE}/${TEMPLATE}_${SPACE_SOURCE}_${MOD[${i}]}.nii.gz
        if [[ -f ${CHK_MOD} ]]; then
          FIXED+=(${CHK_MOD})
        else
          FIXED+=(${DIR_TEMPLATE}/${TEMPLATE}/${SPACE_SOURCE}/${TEMPLATE}_${SPACE_SOURCE}_T1w.nii.gz)
          HIST_MATCH=0
        fi
      done
    elif [[ " ${RECIPE_REQUIRED[@],,} " =~ " fixed " ]]; then
      echo "ERROR [INC ${FCN_NAME}] ${RECIPE_NAME} requires fixed image"
    else
      echo "ERROR [INC ${FCN_NAME}] coregistrations require either a template or a fixed image"
    fi
  else # use fixed
  fi
else # use template
fi


mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

# Coregistration from recipe ===================================================
## 1) identify if a file was provided or use standard LUT
###   -inputs: RECIPE_NAME
###            RECIPE_LUT, default=${DIR_INC}/lut/coregistration_recipes.json
## 2) find coregistration recipe
###   a) find coregistration_recipe field in JSON
###   b) find recipe name (in cases of multiple recipes in a file)
###   c) load recipe "ingredients"
## 3) translate recipe into antsRegistration call
## 4) apply transforms
## 5) rename and move outputs

XFM=(${XFM//,/ })
XFM_N=${#XFM[@]}


***** echo ${X} | sed 's/fixedImage/${FIXED[${i}]}/g'
done
## parse MOVING images ---------------------------------------------------------
MOVING=(${MOVING//;/ })
## repeat MOVING images in array if same images are to be used for each
## registration level
if [[ ${#MOVING[@]} -ne ${XFM_N} ]] && [[ ${#MOVING[@]} -eq 1 ]]; do
  for (( i=1; i<${XFM_N}; i++ )); do
    MOVING+=${MOVING[0]}
  done
done
## parse MOVING ROI masks, will default to no mask, if specified all ROIs for
## all levels must be included, NULL no mask
if [[ -n ${MOVING_ROI} ]]; then
  MOVING_ROI=(${MOVING_ROI//;/ })
fi

# parse FIXED images -----------------------------------------------------------
FIXED=(${FIXED//;/ })
## repeat FIXED images in array if same images are to be used for each
## registration level
if [[ ${#FIXED[@]} -ne ${XFM_N} ]] && [[ ${#FIXED[@]} -eq 1 ]]; do
  for (( i=1; i<${XFM_N}; i++ )); do
    FIXED+=${FIXED[0]}
  done
done
## parse FIXED ROI masks, will default to no mask, if specified all ROIs for
## all levels must be included, NULL no mask
if [[ -n ${FIXED_ROI} ]]; then
  FIXED_ROI=(${FIXED_ROI//;/ })
fi

# check modalities -------------------------------------------------------------
HIST_MATCH=0
for (( i=0; i<${XFM_N}; i++ )); do
  MOVING_TEMP=(${MOVING//,/ })
  FIXED_TEMP=(${FIXED//,/ })
  for (( j=0; j<${#MOVING_TEMP[@]}; j++ )); do
    MOVING_MOD=$(getField -i ${MOVING_TEMP[${j}]} -f modality)
    FIXED_MOD=$(getField -i ${FIXED_TEMP[${j}]} -f modality)
    if [[ "${MOVING_MOD}" != "${FIXED_MOD}" ]]; then
      HIST_MATCH=0
      break 2
    fi
  done
done

# perform rigid only coregistration --------------------------------------------
coreg_fcn="antsRegistration -d 3 --float 1"
coreg_fcn="${coreg_fcn} --verbose ${VERBOSE}"
coreg_fcn="${coreg_fcn} -u ${HIST_MATCH}"
coreg_fcn="${coreg_fcn} -z 1"
coreg_fcn="${coreg_fcn} -o ${DIR_SCRATCH}/xfm_"
## add in initial XFMs
if [[ -n ${XFM_INIT} ]]; then
  for (( i=0; i<${#XFM_INIT[@]}; i++ )); do
    coreg_fcn="${coreg_fcn} -r ${XFM_INIT[${i}]}"
  done
else
  coreg_fcn="${coreg_fcn} -r [${FIXED[0]},${MOVING[0]},1]"
fi
## add registration iterations 
for (( i=0; i<${XFM_N}; i++ )); do
  case "${XFM[${i}],,}" in 
    rigid) coreg_fcn="${coreg_fcn} ${RIGID_STR}" ;;
    affine) coreg_fcn="${coreg_fcn} ${AFFINE_STR}" ;;
    syn) coreg_fcn="${coreg_fcn} ${SYN_STR}" ;;
    bspline) coreg_fcn="${coreg_fcn} ${BSPLINE_STR}" ;;
    bspline-hq) coreg_fcn="${coreg_fcn} ${BSPLINE_HQ_STR[1]}" ;;
    custom) coreg_fcn="${coreg_fcn} ${CUSTOM_STR}";;
  esac
  

  TFIXED=(${FIXED//,/ })
  TMOVING=(${MOVING//,/ })
  for (( j=0; j<${#TMOVING[@]}; j++ )); do
    if [[ "${METRIC[${i}],,}" == *"mattes"* ]] || [[ "${METRIC[${i}],,}" == *"mi"* ]]; then
      if [[ "${METRIC[${i}],,}" == *"hq"* ]]; then
        coreg_fcn="${coreg_fcn} ${MI_METRIC[0]}${TFIXED[${j}]},${TMOVING[${j}]}${MI_METRIC[1]}"
      else
        coreg_fcn="${coreg_fcn} ${MI_HQ_METRIC[0]}${TFIXED[${j}]},${TMOVING[${j}]}${MI_HQ_METRIC[1]}"
      fi
    elif [[ "${METRIC[${i}],,}" == *"cc"* ]]; then
      if [[ "${METRIC[${i}],,}" == *"hq"* ]]; then
        coreg_fcn="${coreg_fcn} ${CC_METRIC[0]}${TFIXED[${j}]},${TMOVING[${j}]}${CC_METRIC[1]}"
      else
        coreg_fcn="${coreg_fcn} ${CC_HQ_METRIC[0]}${TFIXED[${j}]},${TMOVING[${j}]}${CC_HQ_METRIC[1]}"
      fi
    elif [[ "${METRIC[${i}],,}" == "custom" ]]; then
      TCUSTOM=(${CUSTOM_METRIC//;/ })
      coreg_fcn="${coreg_fcn} ${TCUSTOM[0]}${TFIXED[${j}]},${TMOVING[${j}]}${TCUSTOM[1]}"
    fi
  done

  if [[ -n ${FIXED_ROI} ]]; then
    if [[ -n ${MOVING_ROI} ]]; then
      coreg_fcn="${coreg_fcn} -x [${FIXED_ROI[${i}]},${MOVING_ROI[${i}]}]"
    else
      coreg_fcn="${coreg_fcn} -x ${FIXED_ROI[${i}]}"
    fi
  fi
done

# rename and move transform ----------------------------------------------------
FROM=$(getSpace -i ${MOVING})
TO=$(getSpace -i ${FIXED})

### The below won't work
rename "xfm" "${PREFIX}_from-${FROM}_to-${TO}_xfm" ${DIR_SCRATCH}/*
if [[ "${XFM[@]}" == *"affine"* ]]; then
  rename "_0GenericAffine" "-affine" ${DIR_SCRATCH}/*
else
  rename "_0GenericAffine" "-rigid" ${DIR_SCRATCH}/*
fi
if [[ "${XFM[@]}" == *"bspline"* ]]; then
  rename "_1Warp" "-bspline" ${DIR_SCRATCH}/*
  rename "_1InverseWarp" "-bspline" ${DIR_SCRATCH}/*
else
  rename "_1Warp" "-syn" ${DIR_SCRATCH}/*
  rename "_1InverseWarp" "-syn" ${DIR_SCRATCH}/*
fi
mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-rigid.mat

# apply transform to moving image ----------------------------------------------
antsApplyTransforms -d 3 \
  -n ${INTERPOLATION} \
  -i ${MOVING} \
  -o ${DIR_SAVE}/${PREFIX}_prep-${PREP}rigid_${MOD}.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-rigid.mat \
  -r ${FIXED}

# plot output for review -------------------------------------------------------
if [[ "${DO_PLOT}" == "true" ]]; then
  if [[ -z ${DIR_PLOT} ]]; then 
    DIR_PLOT=${DIR_PROJECT}/derivatives/inc/png/${DIRPID}
  fi
  mkdir -p ${DIR_PLOT}
  make3Dpng \
    --bg ${FIXED} --bg-color "#000000,#00FF00" --bg-thresh 2,98 \
    --fg ${MOVING} --fg-color "#000000,#FF00FF" --fg-thresh 2,98 --fg-cbar \
    --layout "5:x;7:y;7:z" --offset "0,0,0" \
    --filename ${PREFIX}_desc-rigid_to-${TO}_img-${MOD} \
    --dir-save ${DIR_PLOT}
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0


