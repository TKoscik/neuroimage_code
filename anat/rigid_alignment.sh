#!/bin/bash -e

#===============================================================================
# Rigid Alignment of Images to Template
# Authors: Timothy R. Koscik, PhD
# Date: 2020-02-23
# Software: ANTs
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hv --long researcher:,project:,group:,subject:,session:,prefix:,\
image:,modality:,template:,space:,target:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose -n 'parse-options' -- "$@"`
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
TEMPLATE=HCPICBM
SPACE=1mm
TARGET=T1w
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix_ PREFIX="$2" ; shift 2 ;;
    --image) IMAGE="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --target) TARGET="$2" ; shift 2 ;;
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
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: $0"
  echo 'Author: <<author names>>'
  echo 'Date:   <<date of authorship>>'
  echo '------------------------------------------------------------------------'
  echo "Usage: $0.sh \"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  --researcher <value>     directory containing the project,'
  echo '                           e.g. /Shared/koscikt'
  echo '  --project <value>        name of the project folder, e.g., iowa_black'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --subject <value>        subject identifer, e.g., 123'
  echo '  --session <value>        session identifier, e.g., 1234abcd'
  echo '  --image <value>          full path to image to align'
  echo '  --template <value>       name of template to use (if necessary),'
  echo '                           e.g., HCPICBM'
  echo '  --space <value>          spacing of template to use, e.g., 1mm'
  echo '  --target <value>         Modality of image to warp to, e.g., T1w'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: /Shared/nopoulos/nimg_core'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                       default: /Shared/pinc/sharedopt/apps/sourcefiles'
  echo ''
fi

# Get time stamp for log -------------------------------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

# Setup directories ------------------------------------------------------------
mkdir -p ${DIR_SCRATCH}
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${RESEARCHER}/${PROJECT}/derivatives/anat/prep/sub-${SUBJECT}/ses-${SESSION}
fi
mkdir -p ${DIR_SAVE}
DIR_XFM=${RESEARCHER}/${PROJECT}/derivatives/xfm
mkdir -p ${DIR_XFM}

# set output prefix if not provided --------------------------------------------
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

#===============================================================================
# Rigid Alignment
#===============================================================================
# get image modality from filename ---------------------------------------------
MOD=(${IMAGE})
MOD=(`basename "${MOD%.nii.gz}"`)
MOD=(${MOD##*_})

# resample template image to the spacing of the image --------------------------
DIR_TEMPLATE=${DIR_NIMGCORE}/templates_human/${TEMPLATE}/${SPACE}
IFS=x read -r -a pixdim <<< $(PrintHeader ${IMAGE} 1)
FIXED=${DIR_SCRATCH}/fixed_image.nii.gz
ResampleImage 3 ${FIXED} \
  ${DIR_TEMPLATE}/${TEMPLATE}_${SPACE}_${TARGET}.nii.gz \
  ${pixdim[0]}x${pixdim[1]}x${pixdim[2]} 0 0 6
  
# rigid registration -----------------------------------------------------------
if [[ "${MOD}" == "${TARGET}" ]]; then
  HIST_MATCH=1
else
  HIST_MATCH=0
fi
antsRegistration \
  -d 3 --float 1 --verbose ${VERBOSE} -u ${HIST_MATCH} -z 1 \
  -r [${FIXED},${IMAGE},1] \
  -t Rigid[0.1] \
  -m MI[${FIXED},${IMAGE},1,32,Regular,0.25] \
  -c [2000x2000x1000x1000,1e-6,10] \
  -f 8x4x2x1 \
  -s 3x2x1x0vox \
  -o ${DIR_SCRATCH}/xfm_

# apply transform --------------------------------------------------------------
antsApplyTransforms -d 3 \
  -i ${IMAGE} \
  -o ${DIR_SCRATCH}/${PREFIX}_prep-rigid_${MOD}.nii.gz \
  -t ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
  -n BSpline[3] \
  -r ${FIXED}

# move files to appropriate locations ------------------------------------------
mv ${DIR_SCRATCH}/xfm_0GenericAffine.mat \
  ${DIR_XFM}/${PREFIX}_from-${MOD}+raw_to-${TEMPLATE}+native_xfm-rigid.mat
mv ${DIR_SCRATCH}/${PREFIX}_prep-rigid.nii.gz \
  ${DIR_SAVE}/${PREFIX}_reg-${TEMPLATE}+native_${MOD}.nii.gz

#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

# Write log entry on conclusion ------------------------------------------------
LOG_FILE=${RESEARCHER}/${PROJECT}/log/sub-${SUBJECT}_ses-${SESSION}.log
date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}

