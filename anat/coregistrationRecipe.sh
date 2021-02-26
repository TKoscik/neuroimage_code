#!/bin/bash -e
#===============================================================================
# Rigid coregistration of neuroimages
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
OPTS=$(getopt -o hvlp --long prefix:,\
moving:,moving-roi:,fixed:,fixed-roi:,\
interpolation:,\
dir-save:,dir-plot:,dir-scratch:,do-plot,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
MOVING=
MOVING_ROI=
FIXED=
FIXED_ROI=
XFM="rigid,affine,affine,syn,syn,bspline,custom"
XFM_INIT=
XFM_CUSTOM=
METRIC=
METRIC_CUSTOM=
INTERPOLATION=BSpline[3]
DIR_SAVE=
DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
DO_PLOT=false
DIR_PLOT=
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -p | --do-plot) DO_PLOT=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --moving) MOVING="$2" ; shift 2 ;;
    --moving-roi) MOVING_ROI="$2" ; shift 2 ;;
    --fixed) FIXED="$2" ; shift 2 ;;
    --fixed-roi) FIXED_ROI="$2" ; shift 2 ;;
    --interpolation) INTERPOLATION="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-plot) DIR_PLOT="$2" ; shift 2 ;;
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
  echo '  -p | --do-plot           generate png of output'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --fixed <value>          Optional target image to warp to, will'
  echo '                           use a template (HCPICBM) by default. This'
  echo '                           argument is only necessary if not using a'
  echo '                           premade template as the target of'
  echo '                           registration'
  echo '  --fixed-mask <value>     mask corresponding to specified fixed image'
  echo '  --moving <value>         Image to be warped to fixed image or template'
  echo '  --moving-mask <value>    mask for image to be warped, e.g., brain mask'
  echo '  --mask-dil <value>       Amount to dilate mask (to allow'
  echo '                           transformations to extend to edges of desired'
  echo '                           region); default=2 voxels'
  echo '  --interpolation <value>  Interpolation method to use, default=BSpline[3]'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --rigid-only             perform only rigid registration'
  echo '  --affine-only            perform rigid and affine registration only'
  echo '  --hardcore               perform rigid, affine, and BSplineSyN'
  echo '                           registration default is rigid, affine, SyN'
  echo '  --stack-xfm              stack affine and syn registrations after'
  echo '                           registration'
  echo '  --dir-save <value>       directory to save output, default varies by'
  echo '                           function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(getDir -i ${MOVING})
PID=$(getField -i ${MOVING} -f sub)
SID=$(getField -i ${MOVING} -f ses)
DIRPID=sub-${PID}
if [[ -n ${SID} ]]; then DIRPID=${DIRPID}/ses-${SID}; fi
if [[ -z ${PREFIX} ]]; then
  PREFIX=$(getBidsBase -s -i ${MOVING})
  PREP=$(getField -i ${PREFIX} -f prep)
  if [[ -n ${PREP} ]]; then
    PREP="${PREP}+"
    PREFIX=$(modField -i ${PREFIX} -r -f prep)
  fi
fi
DIR_XFM=${DIR_PROJECT}/derivatives/inc/xfm/${DIRPID}
if [[ -z "${DIR_SAVE}" ]]; then 
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/${DIRPID}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

# parse registration steps -----------------------------------------------------
XFM=(${XFM//,/ })
XFM_N=${#XFM[@]}

RIGID_XFM="-t Rigid[0.1] -c [2000x2000x2000x2000x2000,1e-6,10] -f 8x8x4x2x1 -s 4x3x2x1x0vox"
AFFINE_XFM="-t Affine[0.1] -c [2000x2000x2000x2000x2000,1e-6,10] -f 8x8x4x2x1 -s 4x3x2x1x0vox"
SYN_XFM="-t SyN[0.1,3,0] -c [100x70x50x20,1e-6,10] -f 8x4x2x1 -s 3x2x1x0vox"
BSPLINE_XFM+=("-t BsplineSyN[0.5,48,0] -c [100x70x50x20,1e-6,10] -f 8x4x2x1 -s 3x2x1x0vox")
BSPLINE_XFM+=("-t BsplineSyN[0.1,48,0] -c [20,1e-6,10] -f 1 -s 0vox")
if [[ -n ${XFM_CUSTOM} ]]; then CUSTOM_XFM=(${XFM_CUSTOM//;/ }); fi

MI_METRIC=("-m Mattes[" ",1,32,Regular,0.25]")
MI_HQ_METRIC=("-m Mattes[" ",1,64,Regular,0.30]")
CC_METRIC=("-m CC[${FIXED[${i}]},${MOVING[${i}]},1,4]")
CC_HQ_METRIC=("-m CC[" ",1,6]")
if [[ -n ${METRIC_CUSTOM} ]]; then CUSTOM_METRIC=(${METRIC_CUSTOM//;/ })

if [[ -n ${METRIC} ]]; then
  for (( i=0; i<${XFM_N}; i++ )); do
    if [[ "${XFM[${i}],,}" == "rigid" ]] ||
       [[ "${XFM[${i}],,}" == "affine" ]] ||
       [[ "${XFM[${i}],,}" == "custom" ]]; then
      METRIC+="mattes"
    elif [[ "${XFM[${i}],,}" == "syn" ]]; then
      METRIC+="cc"
    elif [[ "${XFM[${i}],,}" == "bspline" ]]; then
      METRIC+="cc"
      METRIC+="cchq"
    fi
  done
fi

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
if [[ -n ${XFM_INIT} ]]; then
  for (( i=0; i<${#XFM_INIT[@]}; i++ )); do
    coreg_fcn="${coreg_fcn} -r ${XFM_INIT[${i}]}"
  done
else
  coreg_fcn="${coreg_fcn} -r [${FIXED[0]},${MOVING[0]},1]"
fi
for (( i=0; i<${XFM_N}; i++ )); do
  if [[ "${XFM[${i}],,}" == "rigid" ]]; then
    coreg_fcn="${coreg_fcn} ${RIGID_STR}"
  elif [[ "${XFM[${i}],,}" == "affine" ]]; then
    coreg_fcn="${coreg_fcn} ${AFFINE_STR}"
  elif [[ "${XFM[${i}],,}" == "syn" ]]; then
    coreg_fcn="${coreg_fcn} ${SYN_STR}"
  elif [[ "${XFM[${i}],,}" == "bspline" ]]; then
    coreg_fcn="${coreg_fcn} ${BSPLINE_STR[0]}"
    coreg_fcn="${coreg_fcn} ${BSPLINE_STR[1]}"
  elif [[ "${XFM[${i}],,}" == "custom" ]]; then
    coreg_fcn="${coreg_fcn} ${CUSTOM_STR}"
  fi

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


