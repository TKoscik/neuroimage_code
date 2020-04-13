#!/bin/bash

#===============================================================================
# Calculate Jacobian determinant of a deformation matrix
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-03
#===============================================================================

# Parse inputs -----------------------------------------------------------------
OPTS=`getopt -o hvl --long group:,prefix:,\
xfm:,interpolation:,from:,to:,\
log-jac,geom-jac,\
dir-save:,dir-scratch:,dir-code:,dir-pincsource:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# actions on exit, e.g., cleaning scratch on error ----------------------------
function egress {
  if [[ -d ${DIR_SCRATCH} ]]; then
    if [[ "$(ls -A ${DIR_SCRATCH})" ]]; then
      rm -R ${DIR_SCRATCH}/*
    fi
    rmdir ${DIR_SCRATCH}
  fi
}
trap egress EXIT

# Set default values for function ---------------------------------------------
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
GROUP=
PREFIX=
XFM=
INTERPOLATION=Linear
LOG_JAC=0
GEOM_JAC=0
FROM=NULL
TO=NULL
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/scratch_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_PINCSOURCE=/Shared/pinc/sharedopt/apps/sourcefiles
HELP=false
VERBOSE=0
NO_LOG=false

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --group) GROUP="$2" ; shift 2 ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --xfm) XFM+="$2" ; shift 2 ;;
    --interpolation) INTERPOLATION="$2" ; shift 2 ;;
    --log-jac) LOG_JAC=1 ; shift ;;
    --geom-jac) GEOM_JAC=1 ; shift ;;
    --from) FROM="$2" ; shift 2 ;;
    --to) TO="$2" ; shift 2 ;;
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
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --group <value>          group permissions for project,'
  echo '                           e.g., Research-kosciklab'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --xfm <value>            transforms to use to calculate the jacobian,'
  echo '                           must be input in the reverse order that they'
  echo '                           are to be applied in (ANTs convention)'
  echo '  --from <value>           label for starting space,'
  echo '  --to <value>          spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-pincsource <value> directory for PINC sourcefiles'
  echo '                           default: ${DIR_PINCSOURCE}'
  echo ''
  exit 0
fi

# Set up BIDs compliant variables and workspace --------------------------------
proc_start=$(date +%Y-%m-%dT%H:%M:%S%z)

DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${INPUT_FILE}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${INPUT_FILE} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

mkdir -p ${DIR_SCRATCH}

#==============================================================================
# Start of function
#==============================================================================
N_XFM=${#XFM[@]}
# parse xfm names for FROM and TO
if [[ "${FROM}" == "NULL" ]]; then
  FROM=`${DIR_CODE}/bids/get_field.sh -i ${XFM[0]} -f "from"`
  xfm_from=`${DIR_CODE}/bids/get_field.sh -i ${XFM[0]} -f "xfm"`
  FROM="${FROM}+${xfm_from}"
fi
if [[ "${TO}" == "NULL" ]]; then
  TO=`${DIR_CODE}/bids/get_field.sh -i ${XFM[-1]} -f "to"`
  xfm_to=`${DIR_CODE}/bids/get_field.sh -i ${XFM[-1]} -f "xfm"`
  TO="${TO}+${xfm_to}"
fi

# create save directory
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/jac_from-${FROM}_to-${TO}
fi
mkdir -p ${DIR_SAVE}

# create temporary stack of transforms
xfm_fcn="antsApplyTransforms"
xfm_fcn="${xfm_fcn} -d 3 -v ${VERBOSE}"
xfm_fcn="${xfm_fcn} -o [${DIR_SCRATCH}/${PREFIX}_from-${FROM}_to-${TO}_xfm-stack.nii.gz,1]"
xfm_fcn="${xfm_fcn} -n ${INTERPOLATION}"
for (( i=0; i<${N_XFM}; i++ )); do
  xfm_fcn="${xfm_fcn} -t ${XFM[$[{i}]}"
done
eval ${xfm_fcn}

# Create Jacobian Determinant imgae
CreateJacobianDeterminantImage 3 \
  ${DIR_SCRATCH}/${PREFIX}_from-${FROM}_to-${TO}_xfm-stack.nii.gz \
  ${DIR_SAVE}/${PREFIX}_from-${FROM}_to-${TO}_jac.nii.gz \
  ${LOG_JAC} ${GEOM_JAC}

# Clean up workspace
if [[ "${KEEP}" == "true" ]]; then
  DIR_XFM=${DIR_PROJECT}/derivatives/xfm
  mkdir -p ${DIR_XFM}
  mv ${DIR_SCRATCH}/${PREFIX}_from-${FROM}_to-${TO}_xfm-stack.nii.gz ${DIR_XFM}/
  rmdir ${DIR_SCRATCH}
else
  rm ${DIR_SCRATCH}/*
  rmdir ${DIR_SCRATCH}
fi

#==============================================================================
# End of function
#==============================================================================
if [[ "${NO_LOG}" == "false" ]]; then
  LOG_FILE=${DIR_PROJECT}/log/${PREFIX}.log
  date +"task:$0,start:"${proc_start}",end:%Y-%m-%dT%H:%M:%S%z" >> ${LOG_FILE}
fi

exit 0

