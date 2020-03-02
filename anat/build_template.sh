#!/bin/bash -e

#===============================================================================
# Function Description
# Authors: <<author names>>
# Date: <<date>>
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvk --long researcher:,project:,group:,subject:,session:,prefix:,\
image:,mask:,maSK-dilation:,iterations:,resolution:,initial-template:,affine-only,hardcore,\
hpc-email:,hpc-msg:,hpc-q:,hpc-pe:,\
dir-save:,dir-scratch:,dir-nimgcore:,dir-pincsource:,\
help,verbose,keep -n 'parse-options' -- "$@"`
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
MASK=
MASK_DIL=3
ITERATIONS=5
RESOLUTION=
INIT_TEMPLATE=
AFFINE_ONLY=false
HARDCORE=false
HPC_EMAIL=false
HPC_MSG=false
HPC_Q=CCOM,UI,PINC
HPC_PE="smp 14"
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_NIMGCORE=/Shared/nopoulos/nimg_core
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
DRY_RUN=false
VERBOSE=0
KEEP=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -c | --dry-run) DRY-RUN=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    --researcher) RESEARCHER="$2" ; shift 2 ;;
    --project) PROJECT="$2" ; shift 2 ;;
    --group) GROUP="$2" ; shift 2 ;;
    --subject) SUBJECT="$2" ; shift 2 ;;
    --session) SESSION="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --image) IMAGE+="$2" ; shift 2 ;;
    --mask) MASK="$2" ; shift 2 ;;
    --mask-dilation) MASK_DIL="$2" ; shift 2 ;;
    --iterations) ITERATIONS="$2" ; shift 2 ;;
    --resolution) RESOLUTION="$2" ; shift 2 ;;
    --initial-template) INIT_TEMPLATE="$2" ; shift 2 ;;
    --affine-only) AFFINE_ONLY=true ; shift ;;
    --hardcore) HARDCORE=true ; shift ;;
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
  FUNC_NAME=(`basename "$0"`)
  echo ''
  echo '------------------------------------------------------------------------'
  echo "Iowa Neuroimage Processing Core: ${FUNC_NAME}"
  echo 'Author: <<author names>>'
  echo 'Date:   <<date of authorship>>'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo 'NOTE: This function should not be run as a qsub command, rather'
  echo '      qsub jobs will be submitted by the function as needed.'
  echo '      This means that it will not run if the function is called'
  echo '      from a compute node, only from a login node.'
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  --researcher <value>     directory containing the project,'
  echo '                           e.g. /Shared/koscikt'
  echo '  --project <value>        name of the project folder, e.g., iowa_black'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --subject <value>        subject identifer, e.g., 123'
  echo '  --session <value>        session identifier, e.g., 1234abcd'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --image <value>          images to use to build the template,'
  echo '                           multiple instances required, 1 per'
  echo '                           participant. Multiple modalities need'
  echo '                           to be a comma separated list,'
  echo '                           e.g., sub-01_T1w.nii.gz,sub-01_T2w.nii.gz'
  echo '                           missing images should be entered as NULL.'
  echo '                           Images must be coregistered within'
  echo '                           participants.'
  echo '  --mask <value>           full path to region mask to include in,'
  echo '                           hgiher-order stages of registration'
  echo '  --iterations <value>     number of iterations to generate '
  echo '                           template, default=5'
  echo '  --resolution <value>     resolution of final image in mm, '
  echo '                           e.g., 1x1x1. If no value is given the'
  echo '                           smallest voxels in each dimension across'
  echo '                           all inputs will determine the final'
  echo '                           resolution.'
  echo '  --initial-template <value>  the full path to a target image to'
  echo '                           use for the template. If none is'
  echo '                           provided an initial average and rigid'
  echo '                           registration  round will be completed'
  echo '                           to initialize the target template'
  echo '                           (recommended)'
  echo ' --affine-only             No non-linear registration steps.'
  echo '                           (potentially useful for building'
  echo '                           within-subject averages)'
  echo ' --hardcore                Use hardcore non-linear registration,'
  echo '                           may provide more-accurate fine-scale'
  echo '                           registrations, however much more'
  echo '                           time-consuming.'
  echo '  --dir-save <value>       directory to save output,'
  echo '                           default: ${RESEARCHER}/${PROJECT}/derivatives/template'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-nimgcore <value>   top level directory where INC tools,'
  echo '                           templates, etc. are stored,'
  echo '                           default: ${DIR_NIMGCORE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
fi

# Get time stamp for log -------------------------------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

# Setup directories ------------------------------------------------------------
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${RESEARCHER}/${PROJECT}/derivatives/template
fi
DIR_CODE=${RESEARCHER}/${PROJECT}/code/build_template_${DATE_SUFFIX}
DIR_LOG=${RESEARCHER}/${PROJECT}/log/hpc_output
DIR_IMAGE=${DIR_SCRATCH}/source_images
DIR_XFM=${DIR_SCRATCH}/xfm

mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_CODE}
mkdir -p ${DIR_LOG}
mkdir -p ${DIR_IMAGE}
mkdir -p ${DIR_XFM}

# set output prefix if not provided --------------------------------------------
if [ -z "${PREFIX}" ]; then
  PREFIX=${PROJECT}_template
fi

#===============================================================================
# Start of Function
#===============================================================================
# parse image outputs
## find number of modalities
TEMP=(${IMAGE[0]//,/ })
NUM_MOD=${#TEMP[@]}
NUM_IMAGE=${#IMAGE[@]}

# get image modality
for (( j=0; j<${NUM_MOD}; j++ )); do
  MOD_TEMP=(`basename "${TEMP[${j}]%.nii.gz}"`)
  MOD+=(${MOD_TEMP##*_})
done

# get final resolution if not given
if [ -z "${RESOLUTION}" ]; then
  xdim=999
  ydim=999
  zdim=999
  for (( i=0; i<${NUM_IMAGE}; i++ )); do
    IMAGE_TEMP=(${IMAGE[${i}]//,/ })
    for (( j =0; j<${NUM_MOD}; j++ )); do
      IFS=x read -r -a pixdim <<< $(PrintHeader ${IMAGE_TEMP[0]} 1)
      if (( $(echo "${pixdim[0]" < "${xdim}" | bc -l) )); then
        xdim=${pixdim[0]}
      fi
      if (( $(echo "${pixdim[1]" < "${ydim}" | bc -l) )); then
        ydim=${pixdim[1]}
      fi
      if (( $(echo "${pixdim[2]" < "${zdim}" | bc -l) )); then
        zdim=${pixdim[2]}
      fi
    done
  done
  RESOLUTION=(`echo "${xdim}x${ydim}x${zdim}"`)
fi

# resample images to target resolution -----------------------------------------
JOB_RESAMPLE=${DIR_CODE}/${PREFIX}_resample_images.job
SH_RESAMPLE=${DIR_CODE}/${PREFIX}_resample_images.sh

echo "#!/bin/bash -e" > ${JOB_RESAMPLE}
echo "child_script=${SH_RESAMPLE}" >> ${JOB_RESAMPLE}
echo 'sg - '${GROUP}' -c "chmod +x "'${SH_RESAMPLE} >> ${JOB_RESAMPLE}
echo 'sg - '${GROUP}' -c "bash "'${SH_RESAMPLE} >> ${JOB_RESAMPLE}

echo "" > ${SH_RESAMPLE}
for (( i=0; i<${NUM_IMAGE}; i++ )); do
  IMAGE_TEMP=(${IMAGE[${i}]//,/ })
  for (( j=0; j<${NUM_MOD}; j++ )); do
    TEMP_NAME=(`basename "${IMAGE_TEMP[${j}]}"`)
    echo "ResampleImage 3 ${IMAGE_TEMP[${j}]} ${DIR_IMAGE}/${TEMP_NAME} ${RESOLUTION} 0 0 6" >> ${SH_RESAMPLE}
  done
  if [ -z ${MASK} ]; then
    TEMP_NAME=(`basename "${IMAGE_TEMP[0]}"`)
    TEMP_MASK=(`basename "${MASK[${i}]}%.nii.gz"`)
    echo "antsApplyTransforms -d 3 -n NearestNeighbor -i ${MASK[${i}]} -o ${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz -r ${DIR_IMAGE}/${TEMP_NAME}" >> ${SH_RESAMPLE}
    echo "ImageMath 3 ${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz MD ${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz ${MASK_DIL}" >> ${SH_RESAMPLE}
  fi
done

# Generate average image (run as necessary) ------------------------------------
JOB_AVERAGE=${DIR_CODE}/${PREFIX}_generate_average.job
SH_AVERAGE=${DIR_CODE}/${PREFIX}_generate_average.sh

echo "#!/bin/bash -e" > ${JOB_AVERAGE}
echo "child_script=${SH_AVERAGE}" >> ${JOB_AVERAGE}
echo 'sg - '${GROUP}' -c "chmod +x "'${SH_AVERAGE} >> ${JOB_AVERAGE}
echo 'sg - '${GROUP}' -c "bash "'${SH_AVERAGE} >> ${JOB_AVERAGE}

echo "" > ${SH_AVERAGE}
for (( j=0; j<${NUM_MOD}; j++ )); do
  echo "AverageImages 3 ${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz 1 ${DIR_IMAGE}/*${MOD[${j}]}.nii.gz" >> ${SH_AVERAGE}
done
echo "ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask.nii.gz MajorityVoting ${DIR_IMAGE}/*MASK.nii.gz" >> ${SH_AVERAGE}
echo "ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask.nii.gz MD ${DIR_SCRATCH}/${PREFIX}_mask.nii.gz 3" >> ${SH_AVERAGE}


# Register images to template
for (( i=0; i<${NUM_IMAGE}; i++ )); do
  IMAGE_TEMP=(${IMAGE[${i}]//,/ })

  JOB_REGISTER+=${DIR_CODE}/${PREFIX}_register_image-${i}.job
  SH_REGISTER+=${DIR_CODE}/${PREFIX}_register_image-${i}.sh

  echo "#!/bin/bash -e" > ${JOB_REGISTER}
  echo "child_script=${SH_REGISTER}" >> ${JOB_REGISTER}
  echo 'sg - '${GROUP}' -c "chmod +x "'${SH_REGISTER} >> ${JOB_REGISTER}
  echo 'sg - '${GROUP}' -c "bash "'${SH_REGISTER} >> ${JOB_REGISTER}
  
  echo "" > ${SH_REGISTER}
  echo "antsRegistration" >> ${SH_REGISTER}
  echo "-d 3 --float 1 --verbose ${VERBOSE} -u 1 -z 1" >> ${SH_REGISTER}
  echo "-o ${DIR_XFM}/xfm${i}_" >> ${SH_REGISTER}
  echo "-r [${DIR_SCRATCH}/${PREFIX}_${MOD[0]}.nii.gz,${IMAGE_TEMP[0]},1]" >> ${SH_REGISTER}
  echo "-t Rigid[0.2]" >> ${SH_REGISTER}
  for (( j=0; j<${NUM_MOD}; j++ )); do
    echo "-m Mattes[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,32,Regular,0.25]" >> ${SH_REGISTER}
  done
  echo "-x [NULL,NULL]" >> ${SH_REGISTER}
  echo "-c [2000x2000x2000x2000x2000,1e-6,10]" >> ${SH_REGISTER}
  echo "-f 8x8x4x2x1" >> ${SH_REGISTER}
  echo "-s 4x3x2x1x0vox" >> ${SH_REGISTER}
  echo "-t Affine[0.5]" >> ${SH_REGISTER}
  for (( j=0; j<${NUM_MOD}; j++ )); do
    echo "-m Mattes[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,32,Regular,0.30]" >> ${SH_REGISTER}
  done
  echo "-x [NULL,NULL]" >> ${SH_REGISTER}
  echo "-c [2000x2000x2000x2000x2000,1e-6,10]" >> ${SH_REGISTER}
  echo "-f 8x8x4x2x1" >> ${SH_REGISTER}
  echo "-s 4x3x2x1x0vox" >> ${SH_REGISTER}
  echo "-t Affine[0.1]" >> ${SH_REGISTER}
  for (( j=0; j<${NUM_MOD}; j++ )); do
    echo "-m Mattes[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,64,Regular,0.30]" >> ${SH_REGISTER}
  done
  if [ -z ${MASK} ]; then
    echo "-x[${DIR_SCRATCH}/${PREFIX}_mask.nii.gz,${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz]" >> ${SH_REGISTER}
  else
    echo "-x [NULL,NULL]" >> ${SH_REGISTER}
  fi
  echo "-c [2000x2000x2000x2000x2000,1e-6,10]" >> ${SH_REGISTER}
  echo "-f 8x8x4x2x1" >> ${SH_REGISTER}
  echo "-s 4x3x2x1x0vox" >> ${SH_REGISTER}
  if [[ "${AFFINE_ONLY}" == "false" ]]; then
    if [[ "${HARDCORE}" == "false" ]]; then
      echo "-t SyN[0.1,3,0]" >> ${SH_REGISTER}
      for (( j=0; j<${NUM_MOD}; j++ )); do
        echo "-m CC[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,4]" >> ${SH_REGISTER}
      done
      if [ -z ${MASK} ]; then
        echo "-x[${DIR_SCRATCH}/${PREFIX}_mask.nii.gz,${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz]" >> ${SH_REGISTER}
      else
        echo "-x [NULL,NULL]" >> ${SH_REGISTER}
      fi
      echo "-c [100x70x50x20,1e-6,10]" >> ${SH_REGISTER}
      echo "-f 8x8x4x2x1" >> ${SH_REGISTER}
      echo "-s 3x2x1x0vox" >> ${SH_REGISTER}
    else
      echo "-t BsplineSyN[0.5,48,0]" >> ${SH_REGISTER}
      for (( j=0; j<${NUM_MOD}; j++ )); do
        echo "-m CC[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,4]" >> ${SH_REGISTER}
      done
      if [ -z ${MASK} ]; then
        echo "-x[${DIR_SCRATCH}/${PREFIX}_mask.nii.gz,${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz]" >> ${SH_REGISTER}
      else
        echo "-x [NULL,NULL]" >> ${SH_REGISTER}
      fi
      echo "-c [2000x1000x1000x100x40,1e-6,10]" >> ${SH_REGISTER}
      echo "-f 8x6x4x2x1" >> ${SH_REGISTER}
      echo "-s 4x3x2x1x0vox" >> ${SH_REGISTER}
      echo "t BsplineSyN[0.1,48,0]" >> ${SH_REGISTER}
      for (( j=0; j<${NUM_MOD}; j++ )); do
        echo "-m CC[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,6]" >> ${SH_REGISTER}
      done
      if [ -z ${MASK} ]; then
        echo "-x[${DIR_SCRATCH}/${PREFIX}_mask.nii.gz,${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz]" >> ${SH_REGISTER}
      else
        echo "-x [NULL,NULL]" >> ${SH_REGISTER}
      fi
      echo "-c [20,1e-6,10]" >> ${SH_REGISTER}
      echo "-f 1" >> ${SH_REGISTER}
      echo "-s 0vox" >> ${SH_REGISTER}
      echo "" >> ${SH_REGISTER}
    fi
  fi
  for (( j=0; j<${NUM_MOD}; j++ )); do
    TEMP_NAME=(`basename "${IMAGE_TEMP[${j}]}"`)
    echo "antsApplyTransforms -d 3 -n BSpline[3]" >> ${SH_REGISTER}
    echo "-i ${IMAGE_TEMP[${j}]}" >> ${SH_REGISTER}
    echo "-o ${DIR_IMAGE}/${TEMP_NAME}" >> ${SH_REGISTER}
    if [[ "${AFFINE_ONLY}" == "false" ]]; then
      echo "-t ${DIR_XFM}/xfm${i}_1Warp.nii.gz" >> ${SH_REGISTER}
    fi
    echo "-t ${DIR_XFM}/xfm${i}_0GenericAffine.nii.gz" >> ${SH_REGISTER}
    echo "-r ${DIR_SCRATCH}/${PREFIX}_${MOD[0]}.nii.gz" >> ${SH_REGISTER}
    echo "" >> ${SH_REGISTER}
  done
done


# Iterate through scripts
HPC_STRING=""
if [[ "${HPC_EMAIL}" != "false" ]]; then
  HPC_STRING="${HPC_STRING} -M ${HPC_EMAIL}"
  if [ "${HPC_MSG}" != "false" ]; then
    HPC_STRING="${HPC_STRING} -m ${HPC_MSG}"
  else
    HPC_STRING="${HPC_STRING} -m bes"
  fi
fi
HPC_STRING="${HPC_STRING} -q ${HPC_Q} -pe ${HPC_PE}"
HPC_STRING="${HPC_STRING} -j y"
HPC_STRING="${HPC_STRING} -o ${DIR_LOG}"

QSUB_RESAMPLE="HOLD_RESAMPLE=(`qsub -terse ${HPC_STRING} ${JOB_RESAMPLE}`)"
eval ${QSUB_RESAMPLE}

if [ -z "${INIT_TEMPLATE}" ]; then
  QSUB_AVG0="HOLD_AVG0=(`qsub -terse -hold_jid ${HOLD_RESAMPLE} ${JOB_AVERAGE}`)"
  eval ${QSUB_AVG0}
else
  for (( j=0; j<${NUM_MOD}; j++ )); do
    cp ${INIT_TEMPLATE[${j}]} ${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz
  done
fi

#### START HERE TOMORROW #################

for (( k=0; k<${ITERATIONS}; k++ )) do
  for (( i=0; i<${NUM_IMAGE}; i ++ ))
  QSUB_REG='$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$ HOLD_REGID${k}+=(`qsub -terse ${HPC_STRING} -hold_jid ${HOLD_AVERAGE}${k} ${JOB_REGISTER[${i}]}`)"
  eval ${QSUB_CALL}

  # Re-Average Brain
  JOB_LS=
  for (( i=0; i<${N_ATLAS}; i++ )); do
    eval '${JOB_LS},${HOLD_REGID'${k}'[${i}]}'
  done
  JOB_LS=${JOB_LS:1}

  QSUB_CALL="HOLD_AVERAGE${k}=(`qsub -terse ${HPC_STRING} -hold_jid ${JOB_LS} ${JOB_AVERAGE}`)"
  eval ${QSUB_CALL}
done

# move files to appropriate locations

#===============================================================================
# End of Function
#===============================================================================

# Clean workspace --------------------------------------------------------------
# edit directory for appropriate modality prep folder
if [[ "${KEEP}" == "true" ]]; then
  mkdir -p ${RESEARCHER}/${PROJECT}/derivatives/func/prep/sub-${SUBJECT}/ses-${SESSION}
  mv ${DIR_SCRATCH}/* ${RESEARCHER}/${PROJECT}/derivatives/func/prep/sub-${SUBJECT}/ses-${SESSION}/
  rmdir ${DIR_SCRATCH}
else
  rm ${DIR_SCRATCH}/*
  rmdir ${DIR_SCRATCH}
fi

# Write log entry on conclusion ------------------------------------------------
LOG_FILE=${RESEARCHER}/${PROJECT}/log/sub-${SUBJECT}_ses-${SESSION}.log
date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}

