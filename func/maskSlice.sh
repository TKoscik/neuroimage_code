#!/bin/bash -e
#===============================================================================
# Generate Slice wise mask for each volume
# - created to mask out artefacts due to motion in mouse brains that ruin slices
#   not whole volumes
# Authors: Timothy R. Koscik, PhD
# Date: 2021-09-03
# CHANGELOG: 
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
    unset LOGSTR
    LOGSTR="${OPERATOR},${DIR_PROJECT},${PID},${SID},${HARDWARE},${KERNEL},${HPC_Q},${HPC_SLOTS},${FCN_NAME},${PROC_START},${PROC_STOP},${EXIT_CODE}"
    writeLog --benchmark --string ${LOGSTR}
  fi
}
trap egress EXIT

# Parse inputs -----------------------------------------------------------------
OPTS=$(getopt -o hvkl --long prefix:,\
image:,zmap:,zdir:,zthresh:,plane:,nthresh:,replace:,\
no-z,no-mask,no-clean,\
dir-z:,dir-mask:,dir-clean:,dir-scratch:,\
help,verbose,no-log,no-png -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
ZMAP=
ZDIR=abs
ZTHRESH=1.5
PLANE=z
NTHRESH=0.15
REPLACE=spline ###ADD OPTIONS FOR NAN, MEAN, MEDIAN, LINEAR, SPLINE, VALUE (to replace with time series median, or APPROX or SPLINE for interpolating)
NO_Z=false
NO_MASK=false
NO_CLEAN=false
DIR_Z=
DIR_MASK=
DIR_CLEAN=
DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
VERBOSE=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) ="$2" ; shift 2 ;;
    --zmap) ="$2" ; shift 2 ;;
    --zdir) ="$2" ; shift 2 ;;
    --zthresh) ="$2" ; shift 2 ;;
    --plane) ="$2" ; shift 2 ;;
    --nthresh) ="$2" ; shift 2 ;;
    --replace) ="$2" ; shift 2 ;;
    --no-z) NO_Z=true ; shift ;;
    --no-mask) NO_MASK=true ; shift ;;
    --no-clean) NO_CLEAN=true ; shift ;;
    --dir-z) DIR_Z="$2" ; shift 2 ;;
    --dir-mask) DIR_MASK="$2" ; shift 2 ;;
    --dir-clean) DIR_CLEAN="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix  <optional>     filename, without extension to use for file'
  echo '  --image                  4D NIfTI input file name'
  echo '  --zmap                   pre-generated z-map or other 4D map to use'
  echo '                           for thresholding the time series'
  echo '  --zdir                   direction for thresholding,'
  echo '                           options=(abs)/pos/neg'
  echo '  --zthresh                value for thresholding, default=1.5'
  echo '  --plane                  which plane to look at slices in, typically'
  echo '                           this is the acquisition plane, default=z'
  echo '  --nthresh                the percentage of voxels per slice inorder to'
  echo '                           flag the slice as an artefact, deafult=0.15'
  echo '  --replace                method or value to use for voxelwise'
  echo '                           replacement in 4D file. (calculated/'
  echo '                           interpolated values are on the 4th dimension'
  echo '                           of the data'
  echo '                           options: spline   cubic spline interpolation'
  echo '                                    (linear) linear interpolation'
  echo '                                    mean     mean of non-masked values'
  echo '                                    median   median of non-masked values'
  echo '                                    nan      non-numeric value'
  echo '                                    <value>  specific numeric value,'
  echo '  --no-z                   toggle not save z map, default is to save,'
  echo '                           will not save if zmap is provided'
  echo '  --no-mask                toggle to not save slice mask'
  echo '  --no-clean               toggle not save cleaned output'
  echo '  --dir-z                  location to save Z map, '
  echo '       default=${PROJECT}/derivatives/inc/func/tensor-z/'
  echo '  --dir-mask               location to save slice mask'
  echo '       default=${PROJECT}/derivatives/inc/func/mask/${PREFIX}_mask-slice.nii.gz'
  echo '  --dir-clean              location to save output'
  echo '       default=${PROJECT}/derivatives/inc/func/raw_sliceCleaned/'
  echo '  --dir-scratch            location for temporary files'
  echo ''
  NO_LOG=true
  exit 0
fi

#===============================================================================
# Start of Function
#===============================================================================
# Set up BIDs compliant variables and workspace --------------------------------
DIR_PROJECT=$(getDir -i ${IMAGE})
PID=$(getField -i ${IMAGE} -f sub)
SID=$(getField -i ${IMAGE} -f ses)
PIDSTR=sub-${PID}
DIRPID=sub-${PID}
if [[ -n ${SID} ]]; then PIDSTR="${PIDSTR}_ses-${SID}"; fi
if [[ -n ${SID} ]]; then DIRPID="${DIRPID}/ses-${SID}"; fi

if [[ -z ${PREFIX} ]]; then PREFIX=$(getBidsBase -i ${IMAGE} -s) fi

# if zmap provided disable saving z output, regardless of input ----------------
if [[ -n ${ZMAP} ]]; then NO_Z=true fi

# set default save directories -------------------------------------------------
if [[ "${NO_Z}" == "false" ]] &&\
   [[ "${NO_MASK}" == "false" ]] &&\
   [[ "${NO_CLEAN}" == "false" ]]; then
  echo "Please rethink what you are doing, you are saving nothing."
  exit 1
fi
FCN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
FCN_TYPE=(${FCN_DIR//\// })
if [[ "${NO_Z}" == "false" ]]; then
  if [[ -z ${DIR_Z} ]]; then
    DIR_Z=${DIR_PROJECT}/derivatives/inc/${FCN_TYPE[-1]}/tensor-z
  fi
  mkdir -p ${DIR_Z}
fi
if [[ "${NO_MASK}" == "false" ]]; then
  if [[ -z ${DIR_MASK} ]]; then
    DIR_MASK=${DIR_PROJECT}/derivatives/inc/${FCN_TYPE[-1]}/mask
  fi
  mkdir -p ${DIR_MASK}
fi
if [[ "${NO_CLEAN}" == "false" ]]; then
  if [[ -z ${DIR_CLEAN} ]]; then
    DIR_CLEAN=${DIR_PROJECT}/derivatives/inc/${FCN_TYPE[-1]}/clean-slice
  fi
  mkdir -p ${DIR_CLEAN}
fi


if [[ -z ${DIR_SAVE} ]]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/${FCN_TYPE[-1]}/prep/${DIRPID}
fi
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_SCRATCH}

# body of function here --------------------------------------------------------
## insert comments for important chunks
## use dashes as above to separate chunks of code visually
## move files to appropriate locations

#===============================================================================
# End of Function
#===============================================================================
exit 0



