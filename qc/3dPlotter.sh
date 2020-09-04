#!/bin/bash -e
 
#===============================================================================
# Creates a 3D interactive plot of an image, with or without a overlay in a HTML file
# Authors: Josh Cochran
# Date: 4/30/2020
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
DEBUG=false
NO_LOG=false
 
# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
  if [[ "${DEBUG}" == "false" ]]; then
    if [[ -d ${DIR_SCRATCH} ]]; then
      if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
        rm -R ${DIR_SCRATCH}/*
      fi
      rmdir ${DIR_SCRATCH}
    fi
  fi
  LOG_STRING=`date +"${OPERATOR}\t${FCN_NAME}\t${PROC_START}\t%Y-%m-%dT%H:%M:%S%z\t${EXIT_CODE}"`
  if [[ "${NO_LOG}" == "false" ]]; then
    FCN_LOG=/Shared/inc_scratch/log/benchmark_${FCN_NAME}.log
    if [[ ! -f ${FCN_LOG} ]]; then
      echo -e 'operator\tfunction\tstart\tend\texit_status' > ${FCN_LOG}
    fi
    echo -e ${LOG_STRING} >> ${FCN_LOG}
    if [[ -v ${DIR_PROJECT} ]]; then
      PROJECT_LOG=${DIR_PROJECT}/log/${PREFIX}.log
      if [[ ! -f ${PROJECT_LOG} ]]; then
        echo -e 'operator\tfunction\tstart\tend\texit_status' > ${PROJECT_LOG}
      fi
      echo -e ${LOG_STRING} >> ${PROJECT_LOG}
    fi
  fi
}
trap egress EXIT
 
# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hckl --long image:,mask:,name:,\
dir-save:,dir-scratch:,dir-code:,dir-template:,dir-pincsource:,\
help,debug,dry-run,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"
 
# Set default values for function ---------------------------------------------
IMAGE=
MASK=
DIR_SAVE=
NAME=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
DRY_RUN=false
VERBOSE=0
KEEP=false
 
while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -c | --dry-run) DRY-RUN=true ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --name) NAME="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-template) DIR_TEMPLATE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
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
  echo '  -c | --dry-run           test run of function'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --image <value>          base image'
  echo '  --mask <value>           overlay image'
  echo '  --name <value>           output name of the file'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-template <value>   directory where INC templates are stored,'
  echo '                           default: ${DIR_TEMPLATE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  NO_LOG=true
  exit 0
fi
 
# Set up BIDs compliant variables and workspace --------------------------------
mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
#===============================================================================
# Start of Function
#===============================================================================
 
#NAME=$( basename ${IMAGE} )
#NAME=${NAME::-7}

source /Shared/pinc/sharedopt/apps/sourcefiles/anaconda3_source.sh 2019.10

job=${DIR_SCRATCH}/3dPlot.py

if [ -z "${MASK}" ]; then

echo "from nilearn import plotting" >> ${job}
echo "import os" >> ${job}
echo "import nibabel as nib" >> ${job}
echo "" >> ${job}
echo "T1Variable= nib.load(os.path.join('"${IMAGE}"'))" >> ${job}
echo "html_view = plotting.view_img(T1Variable)" >> ${job}
echo "html_view.save_as_html('"${DIR_SAVE}/${NAME}".html')" >> ${job}

python ${job}

else

echo "from nilearn import plotting" >> ${job}
echo "import os" >> ${job}
echo "import nibabel as nib" >> ${job}
echo "" >> ${job}
echo "overlayVariable = nib.load(os.path.join('"${MASK}"'))" >> ${job}
echo "T1Variable= nib.load(os.path.join('"${IMAGE}"'))" >> ${job}
echo "" >> ${job}
echo "html_view = plotting.view_img(overlayVariable, bg_img=T1Variable)" >> ${job}
echo "html_view.save_as_html('"${DIR_SAVE}/${NAME}".html')" >> ${job}

python ${job}

fi

#===============================================================================
# End of Function
#===============================================================================
 
# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${DIR_PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}/
fi
 
# Exit function ---------------------------------------------------------------
exit 0

