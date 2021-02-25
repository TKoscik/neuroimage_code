#!/bin/bash -e
#===============================================================================
# Coregistration of neuroimages
# Authors: Timothy R. Koscik
# Date: 2020-09-03
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
OPTS=$(getopt -o hvkln --long prefix:,\
moving:,interpolation:,template:,space-template:,space:,\
dir-save:,dir-scratch:,do-plot,do-echo,\
help,verbose,no-log -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
MOVING=
INTERPOLATION=BSpline[3]
TEMPLATE=HCPYA
SPACE_TEMPLATE=700um
SPACE=1mm
DIR_SAVE=
DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
DO_PLOT=false
DO_ECHO=false
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --moving) MOVING="$2" ; shift 2 ;;
    --interpolation) INTERPOLATION="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space_template) SPACE_TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --do-plot) DO_PLOT=true ; shift ;;
    --do-echo) DO_ECHO=true ; shift ;;
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
if [ -n "${SID}" ]; then DIRPID=${DIRPID}/ses-${SID}; fi
if [[ -z "${PREFIX}" ]]; then
  PREFIX=$(getBidsBase -s -i ${MOVING})
  PREP=$(getField -i ${PREFIX} -f prep)
  if [[ -n ${PREP} ]]; then
    PREP="${PREP}+"
    PREFIX=$(modField -i ${PREFIX} -r -f prep)
  fi
fi
DIR_XFM=${DIR_PROJECT}/derivatives/inc/xfm/${DIR_PID}
if [[ -z "${DIR_SAVE}" ]]; then 
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/anat/prep/${DIRPID}
fi
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_XFM}

# set fixed image --------------------------------------------------------------
## modality of input image
MOD=$(getField -i ${MOVING} -f modality)
## match modality of target fixed image, set histogram matching
FIXED_MOD=${MOD}
HIST_MATCH=1
if [[ "${MOD}" != "T1w" ]] && [[ "${MOD}" != "T2w" ]]; then
  FIXED_MOD="T1w"
  HIST_MATCH=0
fi

## check if template of specified size exists
DIR_TEMPLATE=${INC_TEMPLATE}/${TEMPLATE}/${SPACE_TEMPLATE}
if [[ ! -d ${DIR_TEMPLATE} ]]; then
  echo "ERROR [INC ${FCN_NAME}]: Template image and/or specified size not found."
  exit 186
fi
FIXED=${DIR_TEMPLATE}/${TEMPLATE}_${SPACE_TEMPLATE}_${MOD}.nii.gz

## resample template to match output size
if [[ "${SPACE_TEMPLATE}" != "${SPACE}" ]]; then
  RESIZE_STR=$(convSpacing -i ${SPACE})
  ResampleImage 3 ${FIXED} ${DIR_SCRATCH}/FIXED.nii.gz ${RESIZE_STR} 0 1
  FIXED=${DIR_SCRATCH}/FIXED.nii.gz
fi

# perform rigid only coregistration --------------------------------------------
antsRegistration -d 3 --float 1 --verbose ${VERBOSE} -u ${HIST_MATCH} -z 1 \
  -o ${DIR_SCRATCH}/xfm_ \
  -r [${FIXED},${MOVING},1] \
  -t Rigid[0.1] \
  -m Mattes[${FIXED},${MOVING},1,32,Regular,0.30] \
  -c [2000x2000x2000x2000x2000,1e-6,10] \
  -f 8x8x4x2x1 \
  -s 4x3x2x1x0vox

# apply transform to moving image ----------------------------------------------
antsApplyTransforms -d 3 -n ${INTERPOLATION} \
  -i ${MOVING} \
  -o ${DIR_SAVE}/${PREFIX}_prep-${PREP}align_${MOD}.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-rigid.mat

# rename and move transform ----------------------------------------------------
mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-rigid.mat

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
    --filename ${PREFIX}_desc-align_to-${TO}_img-${MOD} \
    --dir-save ${DIR_PLOT}
fi

if [[ "${DO_ECHO}" == "true" ]]; then
  ECHO_OUT+=(${DIR_SAVE}/${PREFIX}_prep-${PREP}align_${MOD}.nii.gz)
  ECHO_OUT+=(${DIR_XFM}/${PREFIX}_from-${FROM}_to-${TO}_xfm-rigid.mat)
  echo "${ECHO_OUT[@]}"
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0
