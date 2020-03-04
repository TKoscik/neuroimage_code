#!/bin/bash

OPTS=`getopt -hvk --long researcher:,project:,group:,subject:,session:,prefix:,space:,template:,dir-scratch:,dir-nimgcore:,dir-pincsource:,keep,help,verbose -n 'parse-options' -- "$@"`
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
SPACE=
TEMPLATE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
KEEP=false
VERBOSE=0
HELP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --space) SPACE="$2" ; shift 2 ;;
    --template) TEMPLATE="$2" ; shift 2 ;;
    --dir-scratch) SCRATCH="$2" ; shift 2 ;;
    --dir-nimgcore) DIR_NIMGCORE="$2" ; shift 2 ;;
    --dir-pincsource) DIR_PINCSOURCE="$2" ; shift 2 ;;
    -- ) shift ; break ;;
    * ) break ;;
  esac
done

# Usage Help ------------------------------------------------------------------


#==============================================================================
# 
#==============================================================================

mkdir -p ${DIR_SCRATCH}

DIR_PREP=${RESEARCHER}/${PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}
DIR_TENSOR=${RESEARCHER}/${PROJECT}/derivatives/dwi/tensor/sub-${SUBJECT}/ses-${SESSION}
DIR_XFM=${RESEARCHER}/${PROJECT}/derivatives/xfm/sub-${SUBJECT}/ses-${SESSION}
DIR_TEMPLATE=${DIR_NIMGCORE}/templates_human
DIR_TEMPLATE_SCALARS=${RESEARCHER}/${PROJECT}/derivatives/dwi/scalars_${SPACE}_${TEMPLATE}



unset xfm
rm ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${SPACE}+${TEMPLATE}_xfm-stack.nii.gz
REF_IMAGE=${DIR_TEMPLATE}/${SPACE}/${TEMPLATE}/${SPACE}_${TEMPLATE}_T1w.nii.gz
antsApplyTransforms -d 3 \
  -o [${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${SPACE}+${TEMPLATE}_xfm-stack.nii.gz,1] \
  -t ${DIR_XFM}/${PREFIX}_from-T1w+rigid_to-${SPACE}+${TEMPLATE}_xfm-stack.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-syn.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-T2w+rigid_xfm-affine.mat \
  -r ${REF_IMAGE}



unset xfm
xfm[0]=${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${SPACE}+${TEMPLATE}_xfm-stack.nii.gz
REF_IMAGE=${DIR_TEMPLATE}/${SPACE}/${TEMPLATE}/${SPACE}_${TEMPLATE}_T1w.nii.gz
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_FA.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/FA/${PREFIX}_reg-${SPACE}+${TEMPLATE}_FA.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${SPACE}+${TEMPLATE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_MD.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/MD/${PREFIX}_reg-${SPACE}+${TEMPLATE}_MD.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${SPACE}+${TEMPLATE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_L1.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/AD/${PREFIX}_reg-${SPACE}+${TEMPLATE}_AD.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${SPACE}+${TEMPLATE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_RD.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/RD/${PREFIX}_reg-${SPACE}+${TEMPLATE}_RD.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${SPACE}+${TEMPLATE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}
antsApplyTransforms -d 3 \
  -i ${DIR_TENSOR}/All_Scalar_S0.nii.gz \
  -o ${DIR_TEMPLATE_SCALARS}/S0/${PREFIX}_reg-${SPACE}+${TEMPLATE}_S0.nii.gz \
  -t ${DIR_XFM}/${PREFIX}_from-dwi+b0_to-${SPACE}+${TEMPLATE}_xfm-stack.nii.gz \
  -r ${REF_IMAGE}



rm ${DIR_SCRATCH}/*
rmdir ${DIR_SCRATCH}

chgrp -R ${GROUP} ${DIR_PREP} > /dev/null 2>&1
chmod -R g+rw ${DIR_PREP} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_TEMPLATE_SCALARS} > /dev/null 2>&1
chmod -R g+rw ${DIR_TEMPLATE_SCALARS} > /dev/null 2>&1
chgrp -R ${GROUP} ${DIR_XFM} > /dev/null 2>&1
chmod -R g+rw ${DIR_XFM} > /dev/null 2>&1

