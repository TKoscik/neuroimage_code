#!/bin/bash -e
#===============================================================================
# Crop and Pad 3D images
# Authors: Timothy R. Koscik, PhD
# Date: 2021/08/24
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
OPTS=$(getopt -o hln --long prefix:,image:,clip:,pad:,dir-save:,dir-scratch:,\
help,no-log,keep,no-png -n 'parse-options' -- "$@")
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
IMAGE=
CLIP=0.1
PAD=20
DIR_SAVE=
DIR_SCRATCH=${INC_SCRATCH}/${OPERATOR}_${DATE_SUFFIX}
HELP=false
NO_PNG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -n | --no-png) NO_PNG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --crop) CROP="$2" ; shift 2 ;;
    --pad) PAD="$2" ; shift 2 ;;
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
  echo '  -h | --help              display command help'
  echo '  -l | --no-log            disable writing to output log'
  echo '  -k | --keep              keep mask from processing'
  echo '  -n | --no-png            disable PNG generation'
  echo '  --prefix  <optional>     new filename, without extension'
  echo '  --image                  file to crop and pad'
  echo '  --clip (default=0.1)     percentile value to use for clipping intensity'
  echo '                           (AFNIs clip level fraction). smaller values'
  echo '                           mean bigger masks'
  echo '  --pad (default=20)       number of voxels to pad each dimension with'
  echo '  --dir-save               location to save output'
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
if [[ -n ${SID} ]]; then ${PIDSTR}="${PIDSTR}_ses-${SID}"; fi
DIRPID=sub-${PID}
if [[ -n ${SID} ]]; then ${DIRPID}="${DIRPID}/ses-${SID}"; fi

if [[ -z ${PREFIX} ]]; then
  PREFIX=$(getBidsBase -i ${IMAGE})
  PREP=$(getField -i ${PREFIX} -f prep)
  if [[ -n ${PREP} ]]; then
    PREFIX=$(modField -i ${PREFIX} -m -f prep -v "${PREP}+crop${PAD}")
  else
    PREFIX=$(modField -i ${PREFIX} -a -f prep -v "crop${PAD}")
  fi
fi


if [[ -z ${DIR_SAVE} ]]; then
  FCN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
  FCN_TYPE=(${FCN_DIR//\// })
  DIR_SAVE=${DIR_PROJECT}/derivatives/inc/${FCN_TYPE[-1]}/prep/${DIRPID}
fi
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_SCRATCH}

# body of function here --------------------------------------------------------
MASK=${DIR_SCRATCH}/${PREFIX}_mask-clip.nii.gz
TIMG=${DIR_SCRATCH}/${PREFIX}.nii.gz

3dAutomask -q -prefix ${MASK} -clfrac ${CLIP} ${IMAGE}
XYZ=($(3dAutobox -noclust -input ${MASK} 2>&1))
Z=${XYZ[-1]}; Z=${Z//z=}; Z=(${Z//../ })
Y=${XYZ[-2]}; Y=${Y//y=}; Y=(${Y//../ })
X=${XYZ[-3]}; X=${X//x=}; X=(${X//../ })

fslroi ${IMAGE} ${TIMG} ${X[0]} ${X[1]} ${Y[0]} ${Y[1]} ${Z[0]} ${Z[1]}
fslroi ${MASK} ${MASK}  ${X[0]} ${X[1]} ${Y[0]} ${Y[1]} ${Z[0]} ${Z[1]}
if [[ ${PAD} -ne 0 ]]; then
  ImageMath 3 ${TIMG} PadImage ${TIMG} ${PAD}
  mv ${TIMG} ${DIR_SAVE}/
fi

if [[ "${NO_PNG}" == "false" ]]; then
  make3Dpng --bg ${DIR_SAVE}/${PREFIX}.nii.gz
fi


if [[ "${KEEP}" == "true" ]]; then
  ImageMath 3 ${MASK} PadImage ${MASK} ${PAD}
  CopyImageHeaderInformation ${DIR_SAVE}/${PREFIX}.nii.gz ${MASK} ${MASK} 1 1 1
  ConvertImage 3 ${MASK} ${MASK} 5
  mv ${MASK} ${DIR_SAVE}/
fi

#===============================================================================
# End of Function
#===============================================================================
exit 0

