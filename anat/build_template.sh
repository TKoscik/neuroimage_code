#!/bin/bash -e

#===============================================================================
# Script to Bulid a template from a set of NIfTI images
# Authors: Timothy R. Koscik, PhD
# Date: 2020-04-07
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvkl --long group:,prefix:,\
image:,mask:,mask-dilation:,iterations:,resolution:,initial-template:,affine-only,hardcore,\
hpc-email:,hpc-msg:,hpc-q:,hpc-pe:,\
dir-save:,dir-scratch:,dir-code:,,dir-pincsource:,\
help,verbose,keep,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=Research-INC_img_core
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
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
DRY_RUN=false
VERBOSE=0
KEEP=false
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -c | --dry-run) DRY-RUN=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -k | --keep) KEEP=true ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
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
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
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
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
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
  echo '                           higher-order stages of registration'
  echo '  --mask-dilation <value>  Amount to dilate mask to avoid edge'
  echo '                           effects of registration'
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
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${IMAGE[0]}`

if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/template
fi
DIR_JOB=${DIR_PROJECT}/code/build_template_${DATE_SUFFIX}
DIR_LOG=${DIR_PROJECT}/log/hpc_output
DIR_IMAGE=${DIR_SCRATCH}/source_images
DIR_XFM=${DIR_SCRATCH}/xfm

mkdir -p ${DIR_SCRATCH}
mkdir -p ${DIR_SAVE}
mkdir -p ${DIR_JOB}
mkdir -p ${DIR_LOG}
mkdir -p ${DIR_IMAGE}
mkdir -p ${DIR_XFM}

# set output prefix if not provided --------------------------------------------
if [ -z "${PREFIX}" ]; then
  PROJECT=`${DIR_CODE}/code/bids/get_project.sh -i ${IMAGE[0]}`
  PREFIX=${PROJECT}_template
fi

#===============================================================================
# Start of Function
#===============================================================================
#------------------------------------------------------------------------------
# parse image outputs
#------------------------------------------------------------------------------
# find number of modalities
TEMP=(${IMAGE[0]//,/ })
NUM_MOD=${#TEMP[@]}
NUM_IMAGE=${#IMAGE[@]}

# get image modalities
for (( j=0; j<${NUM_MOD}; j++ )); do
  MOD+=(`${DIR_CODE}/bids/get_field.sh -i ${${TEMP[${j}]} -f "modality"`)
done

# get target resolution if not given
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

#------------------------------------------------------------------------------
# resample images to target resolution
#------------------------------------------------------------------------------
JOB_RESAMPLE=${DIR_JOB}/${PREFIX}_resample_images.job
SH_RESAMPLE=${DIR_JOB}/${PREFIX}_resample_images.sh

echo "#!/bin/bash -e" > ${JOB_RESAMPLE}
echo "child_script=${SH_RESAMPLE}" >> ${JOB_RESAMPLE}${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz
echo 'sg - '${GROUP}' -c "chmod +x ${child_script}"' >> ${JOB_RESAMPLE}
echo 'sg - '${GROUP}' -c "bash ${child_script}"' >> ${JOB_RESAMPLE}

echo "" > ${SH_RESAMPLE}
echo "proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)" >> ${SH_RESAMPLE}
for (( i=0; i<${NUM_IMAGE}; i++ )); do
  IMAGE_TEMP=(${IMAGE[${i}]//,/ })
  for (( j=0; j<${NUM_MOD}; j++ )); do
    TEMP_NAME=(`basename "${IMAGE_TEMP[${j}]}"`)
    echo "ResampleImage 3 ${IMAGE_TEMP[${j}]} ${DIR_IMAGE}/${TEMP_NAME} ${RESOLUTION} 0 0 6" >> ${SH_RESAMPLE}
  done
  if [ -n ${MASK} ]; then
    TEMP_NAME=(`basename "${IMAGE_TEMP[0]}"`)
    TEMP_MASK=(`basename "${MASK[${i}]}%.nii.gz"`)
    echo "antsApplyTransforms -d 3 -n NearestNeighbor -i ${MASK[${i}]} -o ${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz -r ${DIR_IMAGE}/${TEMP_NAME}" >> ${SH_RESAMPLE}
    echo "ImageMath 3 ${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz MD ${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz ${MASK_DIL}" >> ${SH_RESAMPLE}
  fi
  echo "" >> ${SH_RESAMPLE}
done
if [[ "${NO_LOG}" == "false" ]]; then
  echo "LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log" >> ${SH_RESAMPLE}
  echo 'date +"task:resample_images,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> '${LOG_FILE} >> ${SH_RESAMPLE}
fi
echo "" >> ${SH_RESAMPLE}
echo "" >> ${SH_RESAMPLE}

#------------------------------------------------------------------------------
# Generate average image (run as necessary)
#------------------------------------------------------------------------------
JOB_AVERAGE=${DIR_JOB}/${PREFIX}_generate_average.job
SH_AVERAGE=${DIR_JOB}/${PREFIX}_generate_average.sh

echo "#!/bin/bash -e" > ${JOB_AVERAGE}
echo "child_script=${SH_AVERAGE}" >> ${JOB_AVERAGE}
echo 'sg - '${GROUP}' -c "chmod +x ${child_script}"' >> ${JOB_AVERAGE}
echo 'sg - '${GROUP}' -c "bash ${child_script}"' >> ${JOB_AVERAGE}
echo "" >> ${JOB_AVERAGE}
echo "" >> ${JOB_AVERAGE}

echo "" > ${SH_AVERAGE}
echo "proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)" >> ${SH_AVERAGE}
echo "" >> ${SH_AVERAGE}
for (( j=0; j<${NUM_MOD}; j++ )); do
  echo "AverageImages 3 ${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz 1 ${DIR_IMAGE}/*${MOD[${j}]}.nii.gz" >> ${SH_AVERAGE}
done
echo "" >> ${SH_AVERAGE}
if [ -n ${MASK} ]; then
  echo "ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask.nii.gz MajorityVoting ${DIR_IMAGE}/*MASK.nii.gz" >> ${SH_AVERAGE}
  echo "ImageMath 3 ${DIR_SCRATCH}/${PREFIX}_mask.nii.gz MD ${DIR_SCRATCH}/${PREFIX}_mask.nii.gz 3" >> ${SH_AVERAGE}
  echo "" >> ${SH_AVERAGE}
fi
if [[ "${NO_LOG}" == "false" ]]; then
  echo "LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log" >> ${SH_AVERAGE}
  echo 'date +"task:average_images,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> '${LOG_FILE} >> ${SH_AVERAGE}
fi
echo "" >> ${SH_AVERAGE}
echo "" >> ${SH_AVERAGE}

#------------------------------------------------------------------------------
# Register images to template
#------------------------------------------------------------------------------
for (( i=0; i<${NUM_IMAGE}; i++ )); do
  IMAGE_TEMP=(${IMAGE[${i}]//,/ })

  JOB_REGISTER+=${DIR_JOB}/${PREFIX}_register_image-${i}.job
  SH_REGISTER+=${DIR_JOB}/${PREFIX}_register_image-${i}.sh

  echo "#!/bin/bash -e" > ${JOB_REGISTER[${i}]}
  echo "child_script=${SH_REGISTER}" >> ${JOB_REGISTER[${i}]}
  echo 'sg - '${GROUP}' -c "chmod +x ${child_script}"' >> ${JOB_REGISTER[${i}]}
  echo 'sg - '${GROUP}' -c "bash ${child_script}"' >> ${JOB_REGISTER[${i}]}
  echo "" >> ${JOB_REGISTER[${i}]}
  echo "" >> ${JOB_REGISTER[${i}]}
  
  echo "" > ${SH_REGISTER[${i}]}
  echo "proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)" >> ${SH_REGISTER[${i}]}
  echo "" >> ${SH_REGISTER[${i}]}
  echo "antsRegistration" >> ${SH_REGISTER[${i}]}
  echo "-d 3 --float 1 --verbose ${VERBOSE} -u 1 -z 1" >> ${SH_REGISTER[${i}]}
  echo "-o ${DIR_XFM}/xfm${i}_" >> ${SH_REGISTER[${i}]}
  echo "-r [${DIR_SCRATCH}/${PREFIX}_${MOD[0]}.nii.gz,${IMAGE_TEMP[0]},1]" >> ${SH_REGISTER[${i}]}
  echo "-t Rigid[0.2]" >> ${SH_REGISTER[${i}]}
  for (( j=0; j<${NUM_MOD}; j++ )); do
    if [[ "${IMAGE_TEMP[${j}]}" -ne "NULL" ]]; then
      echo "-m Mattes[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,32,Regular,0.25]" >> ${SH_REGISTER[${i}]}
    fi
  done
  echo "-x [NULL,NULL]" >> ${SH_REGISTER[${i}]}
  echo "-c [2000x2000x2000x2000x2000,1e-6,10]" >> ${SH_REGISTER[${i}]}
  echo "-f 8x8x4x2x1" >> ${SH_REGISTER[${i}]}
  echo "-s 4x3x2x1x0vox" >> ${SH_REGISTER[${i}]}
  echo "-t Affine[0.5]" >> ${SH_REGISTER[${i}]}
  for (( j=0; j<${NUM_MOD}; j++ )); do
    if [[ "${IMAGE_TEMP[${j}]}" -ne "NULL" ]]; then
      echo "-m Mattes[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,32,Regular,0.30]" >> ${SH_REGISTER[${i}]}
    fi
  done
  echo "-x [NULL,NULL]" >> ${SH_REGISTER[${i}]}
  echo "-c [2000x2000x2000x2000x2000,1e-6,10]" >> ${SH_REGISTER[${i}]}
  echo "-f 8x8x4x2x1" >> ${SH_REGISTER[${i}]}
  echo "-s 4x3x2x1x0vox" >> ${SH_REGISTER[${i}]}
  echo "-t Affine[0.1]" >> ${SH_REGISTER[${i}]}
  for (( j=0; j<${NUM_MOD}; j++ )); do    
    if [[ "${IMAGE_TEMP[${j}]}" -ne "NULL" ]]; then
      echo "-m Mattes[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,64,Regular,0.30]" >> ${SH_REGISTER[${i}]}
    fi
  done
  if [ -n ${MASK} ]; then
    echo "-x [${DIR_SCRATCH}/${PREFIX}_mask.nii.gz,${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz]" >> ${SH_REGISTER[${i}]}
  else
    echo "-x [NULL,NULL]" >> ${SH_REGISTER[${i}]
  fi
  echo "-c [2000x2000x2000x2000x2000,1e-6,10]" >> ${SH_REGISTER[${i}]}
  echo "-f 8x8x4x2x1" >> ${SH_REGISTER[${i}]}
  echo "-s 4x3x2x1x0vox" >> ${SH_REGISTER[${i}]}
  if [[ "${AFFINE_ONLY}" == "false" ]]; then
    if [[ "${HARDCORE}" == "false" ]]; then
      echo "-t SyN[0.1,3,0]" >> ${SH_REGISTER[${i}]}
      for (( j=0; j<${NUM_MOD}; j++ )); do
        if [[ "${IMAGE_TEMP[${j}]}" -ne "NULL" ]]; then
          echo "-m CC[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,4]" >> ${SH_REGISTER[${i}]}
        fi
      done
      if [ -n ${MASK} ]; then
        echo "-x [${DIR_SCRATCH}/${PREFIX}_mask.nii.gz,${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz]" >> ${SH_REGISTER[${i}]}
      else
        echo "-x [NULL,NULL]" >> ${SH_REGISTER[${i}]}
      fi
      echo "-c [100x70x50x20,1e-6,10]" >> ${SH_REGISTER[${i}]}
      echo "-f 8x8x4x2x1" >> ${SH_REGISTER[${i}]}
      echo "-s 3x2x1x0vox" >> ${SH_REGISTER[${i}]}
    else
      echo "-t BsplineSyN[0.5,48,0]" >> ${SH_REGISTER[${i}]}
      for (( j=0; j<${NUM_MOD}; j++ )); do
        if [[ "${IMAGE_TEMP[${j}]}" -ne "NULL" ]]; then
          echo "-m CC[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,4]" >> ${SH_REGISTER[${i}]}
        fi
      done
      if [ -n ${MASK} ]; then
        echo "-x [${DIR_SCRATCH}/${PREFIX}_mask.nii.gz,${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz]" >> ${SH_REGISTER[${i}]}
      else
        echo "-x [NULL,NULL]" >> ${SH_REGISTER[${i}]}
      fi
      echo "-c [2000x1000x1000x100x40,1e-6,10]" >> ${SH_REGISTER[${i}]}
      echo "-f 8x6x4x2x1" >> ${SH_REGISTER[${i}]}
      echo "-s 4x3x2x1x0vox" >> ${SH_REGISTER[${i}]}
      echo "t BsplineSyN[0.1,48,0]" >> ${SH_REGISTER[${i}]}
      for (( j=0; j<${NUM_MOD}; j++ )); do
        if [[ "${IMAGE_TEMP[${j}]}" -ne "NULL" ]]; then
          echo "-m CC[${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz,${IMAGE_TEMP[${j}]},1,6]" >> ${SH_REGISTER[${i}]}
        fi
      done
      if [ -n ${MASK} ]; then
        echo "-x [${DIR_SCRATCH}/${PREFIX}_mask.nii.gz,${DIR_IMAGE}/${TEMP_MASK}_MASK.nii.gz]" >> ${SH_REGISTER[${i}]}
      else
        echo "-x [NULL,NULL]" >> ${SH_REGISTER[${i}]}
      fi
      echo "-c [20,1e-6,10]" >> ${SH_REGISTER[${i}]}
      echo "-f 1" >> ${SH_REGISTER[${i}]}
      echo "-s 0vox" >> ${SH_REGISTER[${i}]}
      echo "" >> ${SH_REGISTER[${i}]}
    fi
  fi
  for (( j=0; j<${NUM_MOD}; j++ )); do
    if [[ "${IMAGE_TEMP[${j}]}" -ne "NULL" ]]; then
      TEMP_NAME=(`basename "${IMAGE_TEMP[${j}]}"`)
      echo "antsApplyTransforms -d 3 -n BSpline[3]" >> ${SH_REGISTER[${i}]}
      echo "-i ${IMAGE_TEMP[${j}]}" >> ${SH_REGISTER[${i}]}
      echo "-o ${DIR_IMAGE}/${TEMP_NAME}" >> ${SH_REGISTER[${i}]}
      if [[ "${AFFINE_ONLY}" == "false" ]]; then
        echo "-t ${DIR_XFM}/xfm${i}_1Warp.nii.gz" >> ${SH_REGISTER[${i}]}
      fi
      echo "-t ${DIR_XFM}/xfm${i}_0GenericAffine.nii.gz" >> ${SH_REGISTER[${i}]}
      echo "-r ${DIR_SCRATCH}/${PREFIX}_${MOD[0]}.nii.gz" >> ${SH_REGISTER[${i}]}
      echo "" >> ${SH_REGISTER[${i}]}
    fi
  done
  if [[ "${NO_LOG}" == "false" ]]; then
    echo "LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log" >> ${SH_REGISTER[${i}]}
    echo 'date +"task:register_images'${i}'_to_average,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> '${LOG_FILE} >> ${SH_REGISTER[${i}]}
  fi
  echo "" >> ${SH_REGISTER[${i}]}
  echo "" >> ${SH_REGISTER[${i}]}
done

#------------------------------------------------------------------------------
# Move files and clean up workspace
#------------------------------------------------------------------------------
JOB_CLEAN=${DIR_JOB}/${PREFIX}_clean_workspace.job
SH_CLEAN=${DIR_JOB}/${PREFIX}_clean_workspace.sh

echo "#!/bin/bash -e" > ${JOB_CLEAN}
echo "child_script=${SH_REGISTER}" >> ${JOB_CLEAN}
echo 'sg - '${GROUP}' -c "chmod +x ${child_script}"' >> ${JOB_CLEAN}
echo 'sg - '${GROUP}' -c "bash ${child_script}"' >> ${JOB_CLEAN}
echo "" >> ${JOB_CLEAN}
echo "" >> ${JOB_CLEAN}
  
echo "" > ${SH_CLEAN}
echo "proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)" >> ${SH_CLEAN}
echo "" >> ${SH_CLEAN}
echo "mv ${DIR_SCRATCH}/${PREFIX}_* ${DIR_SAVE}/" >> ${SH_CLEAN}
if [[ "${KEEP}" == "true" ]]; then
  echo "mkdir -p ${RESEARCHER}/${PROJECT}/template/prep/${PREFIX}" >> ${SH_CLEAN}
  echo "mv ${DIR_SCRATCH}/* ${RESEARCHER}/${PROJECT}/template/prep/${PREFIX}/" >> ${SH_CLEAN}
  echo "rmdir ${DIR_SCRATCH}" >> ${SH_CLEAN}
else
  echo "rm ${DIR_SCRATCH}/source_images/*" >> ${SH_CLEAN}
  echo "rm ${DIR_SCRATCH}/xfm/*" >> ${SH_CLEAN}
  echo "rmdir ${DIR_SCRATCH}/source_images" >> ${SH_CLEAN}
  echo "rmdir ${DIR_SCRATCH}/xfm" >> ${SH_CLEAN}
  echo "rmdir ${DIR_SCRATCH}" >> ${SH_CLEAN}
fi
if [[ "${NO_LOG}" == "false" ]]; then
  echo "LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log" >> ${SH_CLEAN}
  echo 'date +"task:clean_template_build_workspace,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> '${LOG_FILE} >> ${SH_CLEAN}
  echo 'date +"task:build_template,start:"'${proc_start}'",end:%Y-%m-%dT%H:%M:%S%z" >> '${LOG_FILE} >> ${SH_CLEAN}
fi
echo "" >> ${SH_CLEAN}
echo "" >> ${SH_CLEAN}

#------------------------------------------------------------------------------
# Iterate through scripts
#------------------------------------------------------------------------------
# set high performance computing options
HPC_OPTS=""
if [[ "${HPC_EMAIL}" != "false" ]]; then
  HPC_OPTS="${HPC_OPTS} -M ${HPC_EMAIL}"
  if [ "${HPC_MSG}" != "false" ]; then
    HPC_OPTS="${HPC_OPTS} -m ${HPC_MSG}"
  else
    HPC_OPTS="${HPC_OPTS} -m bes"
  fi
fi
HPC_OPTS="${HPC_OPTS} -q ${HPC_Q} -pe ${HPC_PE}"
HPC_OPTS="${HPC_OPTS} -j y"
if [[ "${NO_LOG}" == "false" ]]; then
  HPC_OPTS="${HPC_OPTS} -o ${DIR_LOG}"
fi

# Run resample images
QSUB_RESAMPLE="HOLD_RESAMPLE=(`qsub -terse ${HPC_OPTS} ${JOB_RESAMPLE}`)"
eval ${QSUB_RESAMPLE}

# mask / copy initial templates
if [ -z "${INIT_TEMPLATE}" ]; then
  QSUB_AVG0="HOLD_AVG0=(`qsub -terse -hold_jid ${HOLD_RESAMPLE} ${JOB_AVERAGE}`)"
  eval ${QSUB_AVG0}
else
  for (( j=0; j<${NUM_MOD}; j++ )); do
    cp ${INIT_TEMPLATE[${j}]} ${DIR_SCRATCH}/${PREFIX}_${MOD[${j}]}.nii.gz
  done
fi

# iterate over registrations to template and averaging
for (( k=0; k<${ITERATIONS}; k++ )); do
  for (( i=0; i<${NUM_IMAGE}; i ++ )); do
    QSUB_REG='HOLD_REGID'${k}'+=(`qsub -terse '${HPC_OPTS}' -hold_jid ${HOLD_AVG'${k}'} '${JOB_REGISTER[${i}]}'`)'
    eval ${QSUB_REG}
  done

  # Re-Average Brain
  JOB_LS=
  for (( i=0; i<${N_ATLAS}; i++ )); do
    eval '${JOB_LS},${HOLD_REGID'${k}'[${i}]}'
  done
  JOB_LS=${JOB_LS:1}

  NEXT_VAL=$((k+1))
  QSUB_CALL="HOLD_AVG${NEST_VAL}=(`qsub -terse ${HPC_OPTS} -hold_jid ${JOB_LS} ${JOB_AVERAGE}`)"
  eval ${QSUB_CALL}
done

QSUB_END='(`qsub ${HPC_OPTS} -hold_jid ${HOLD_AVG'${NEXT_VAL}'} '${JOB_CLEAN}'`)'
eval ${QSUB_END}

#===============================================================================
# End of Function
#===============================================================================
# moving files, cleaning workspace, and logging is in sub jobs

