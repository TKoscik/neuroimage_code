#!/bin/bash

#------------------------------------------------------------------------------
# Set Up Software
#------------------------------------------------------------------------------
module load OpenBLAS
nimg_core_root=/Shared/nopoulos/nimg_core
source /Shared/pinc/sharedopt/apps/sourcefiles/ants_source.sh
ants_version=$(echo "${ANTSPATH}" | cut -d "/" -f9)
fsl_version=6.0.1_multicore
source /Shared/pinc/sharedopt/apps/sourcefiles/fsl_source.sh ${fsl_version}


#------------------------------------------------------------------------------
# Specify Analysis Variables
#------------------------------------------------------------------------------
RESEARCHER=/Shared/
PROJECT=
SUBJECT=
SESSION=
SPACE=
TEMPLATE=
GROUP=Research-
PREFIX=sub-${SUBJECT}_ses-${SESSION}
SMOOTHING=0

#------------------------------------------------------------------------------

DIR_DWI_CODE=/Shared/nopoulos/nimg_core/code/dwi
DIR_RAW=${RESEARCHER}/${PROJECT}/nifti/sub-${SUBJECT}/ses-${SESSION}/dwi
DIR_SAVE=${RESEARCHER}/${PROJECT}/derivatives/dwi/prep/sub-${SUBJECT}/ses-${SESSION}

#------------------------------------------------------------------------------

${DIR_DWI_CODE}/fix_dimensions.sh \
--group ${GROUP} \
--dir-raw ${DIR_RAW}

${DIR_DWI_CODE}/extract_b0.sh \
--group ${GROUP} \
--dir-raw ${DIR_RAW}

${DIR_DWI_CODE}/acquisition_params.sh \
--group ${GROUP} \
--dir-raw ${DIR_RAW}

${DIR_DWI_CODE}/run_topup.sh \
--group ${GROUP} \
--dir-save ${DIR_SAVE}

${DIR_DWI_CODE}/registration+bex.sh \
--group ${GROUP} \
--dir-save ${DIR_SAVE}

${DIR_DWI_CODE}/run_eddy.sh \
--group ${GROUP} \
--dir-save ${DIR_SAVE}

${DIR_DWI_CODE}/scalars_dtifit.sh \
--group ${GROUP} \
--smoothing ${SMOOTHING} \
--dir-save ${DIR_SAVE}

${DIR_DWI_CODE}/regToNative.sh \
--group ${GROUP} \
--dir-save ${DIR_SAVE}

${DIR_DWI_CODE}/stack+applyTransforms.sh \
--group ${GROUP} \
--template ${TEMPLATE} \
--space ${SPACE} \
--dir-save ${DIR_SAVE}


