#!/bin/bash

#===============================================================================
# Calculate Jacobian determinant of a deformation matrix
# Authors: Timothy R. Koscik, PhD
# Date: 2020-03-03
#===============================================================================
PROC_START=$(date +%Y-%m-%dT%H:%M:%S%z)
FCN_NAME=(`basename "$0"`)
DATE_SUFFIX=$(date +%Y%m%dT%H%M%S%N)
OPERATOR=$(whoami)
NO_LOG=false

# actions on exit, write to logs, clean scratch
function egress {
  EXIT_CODE=$?
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
OPTS=`getopt -o hvl --long prefix:,\
xfm:,interpolation:,from:,to:,ref-image:,\
log,geom,\
dir-save:,dir-scratch:,dir-code:,dir-template:,\
help,verbose,no-log -n 'parse-options' -- "$@"`
if [ $? != 0 ]; then
  echo "Failed parsing options" >&2
  exit 1
fi
eval set -- "$OPTS"

# Set default values for function ---------------------------------------------
PREFIX=
XFM=
INTERPOLATION=Linear
REF_IMAGE=NULL
LOG=0
GEOM=0
FROM=NULL
TO=NULL
DIR_SAVE=
DIR_SCRATCH=/Shared/inc_scratch/${OPERATOR}_${DATE_SUFFIX}
DIR_CODE=/Shared/inc_scratch/code
DIR_TEMPLATE=/Shared/nopoulos/nimg_core/templates_human
HELP=false
VERBOSE=0

while true; do
  case "$1" in
    -h | --help) HELP=true ; shift ;;
    -v | --verbose) VERBOSE=1 ; shift ;;
    -l | --no-log) NO_LOG=true ; shift ;;
    --prefix) PREFIX="$2" ; shift 2 ;;
    --xfm) XFM="$2" ; shift 2 ;;
    --interpolation) INTERPOLATION="$2" ; shift 2 ;;
    --ref-image) REF_IMAGE="$2" ; shift 2 ;;
    --log) LOG=1 ; shift ;;
    --geom) GEOM=1 ; shift ;;
    --from) FROM="$2" ; shift 2 ;;
    --to) TO="$2" ; shift 2 ;;
    --dir-save) DIR_SAVE="$2" ; shift 2 ;;
    --dir-scratch) DIR_SCRATCH="$2" ; shift 2 ;;
    --dir-code) DIR_CODE="$2" ; shift 2 ;;
    --dir-template) DIR_TEMPLATE="$2" ; shift 2 ;;
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
  echo 'Author: Timothy R. Koscik'
  echo 'Date:   2020-03-03'
  echo '------------------------------------------------------------------------'
  echo "Usage: ${FUNC_NAME}"
  echo '  -h | --help              display command help'
  echo '  -v | --verbose           add verbose output to log file'
  echo '  -k | --keep              keep preliminary processing steps'
  echo '  -l | --no-log            disable writing to output log'
  echo '  --prefix <value>         scan prefix,'
  echo '                           default: sub-123_ses-1234abcd'
  echo '  --xfm <value>            transforms to use to calculate the jacobian,'
  echo '                           must be input as a comma separated string'
  echo '                           in the reverse order that they'
  echo '                           are to be applied in (ANTs convention)'
  echo '  --interpolation          Interpolation algorithm to use if merging'
  echo '                           transforms, default=linear'
  echo '  --ref-image              a file that represents the reference space if'
  echo '                           mergin transforms'
  echo '  --log                    calculate log jacobian determinant, defaul=0'
  echo '  --geom                   calculate geometric determinant, default=0'
  echo '  --from <value>           label for starting space,'
  echo '  --to <value>             spacing of template to use, e.g., 1mm'
  echo '  --dir-save <value>       directory to save output, default varies by function'
  echo '  --dir-scratch <value>    directory for temporary workspace'
  echo '  --dir-code <value>       directory where INC tools are stored,'
  echo '                           default: ${DIR_CODE}'
  echo '  --dir-template <value>   directory where template image can be found,'
  echo '                           needed when combining multiple transforms.'
  echo '                           default is '${DIR_TEMPLATE}' and the template'
  echo '                           is determined by the "to" field in the'
  echo '                           filename, unless a specific template is provided'
  echo ''
  NO_LOG=true
  exit 0
fi

#==============================================================================
# Start of function
#==============================================================================

# Set up BIDs compliant variables and workspace
XFM=(${XFM//,/ })
N_XFM=${#XFM[@]}
DIR_PROJECT=`${DIR_CODE}/bids/get_dir.sh -i ${XFM[0]}`
SUBJECT=`${DIR_CODE}/bids/get_field.sh -i ${XFM[0]} -f "sub"`
SESSION=`${DIR_CODE}/bids/get_field.sh -i ${XFM[0]} -f "ses"`
if [ -z "${PREFIX}" ]; then
  PREFIX=sub-${SUBJECT}_ses-${SESSION}
fi

mkdir -p ${DIR_SCRATCH}

# parse xfm names for FROM and TO
if [[ "${FROM}" == "NULL" ]]; then
  FROM=`${DIR_CODE}/bids/get_field.sh -i ${XFM[0]} -f "from"`
fi
if [[ "${TO}" == "NULL" ]]; then
  TO=`${DIR_CODE}/bids/get_field.sh -i ${XFM[-1]} -f "to"`
fi

XFM_TEMP=
for (( i=${N_XFM}-1; i>=0; i-- )); do
  xfm_temp=`${DIR_CODE}/bids/get_field.sh -i ${XFM[${i}]} -f "xfm"`
  XFM_TEMP+=(${xfm_temp})
done
XFM_NAME=$(IFS=+ ; echo "${XFM_TEMP[*]}")
XFM_NAME=${XFM_NAME:1}

# create save directory
if [ -z "${DIR_SAVE}" ]; then
  DIR_SAVE=${DIR_PROJECT}/derivatives/anat/jac_from-${FROM}_to-${TO}_xfm-${XFM_NAME}
fi
mkdir -p ${DIR_SAVE}

# create temporary stack of transforms
if [[ "${N_XFM}" > 1 ]]; then
  if [[ "${REF_IMAGE}" == "NULL" ]]; then
    TEMP=(${TO//+/ })
    REF_IMAGE=${DIR_TEMPLATE}/${TEMP[0]}/${TEMP[1]}/${TEMP[0]}_${TEMP[1]}_T1w.nii.gz
  fi
  xfm_fcn="antsApplyTransforms"
  xfm_fcn="${xfm_fcn} -d 3 -v ${VERBOSE}"
  xfm_fcn="${xfm_fcn} -o [${DIR_SCRATCH}/${PREFIX}_from-${FROM}_to-${TO}_xfm-stack.nii.gz,1]"
  xfm_fcn="${xfm_fcn} -n ${INTERPOLATION}"
  for (( i=0; i<${N_XFM}; i++ )); do
    xfm_fcn="${xfm_fcn} -t ${XFM[${i}]}"
  done
  xfm_fcn="${xfm_fcn} -r ${REF_IMAGE}"
  eval ${xfm_fcn}
  XFM_JAC=${DIR_SCRATCH}/${PREFIX}_from-${FROM}_to-${TO}_xfm-stack.nii.gz
else
  XFM_JAC=${XFM}
fi


# Create Jacobian Determinant imgae
CreateJacobianDeterminantImage 3 \
  ${XFM_JAC} \
  ${DIR_SAVE}/${PREFIX}_from-${FROM}_to-${TO}_xfm-${XFM_NAME}_jac.nii.gz \
  ${LOG} ${GEOM}

# keep stack xfm if desired
if [[ "${KEEP}" == "true" ]]; then
  DIR_XFM=${DIR_PROJECT}/derivatives/xfm
  mkdir -p ${DIR_XFM}
  mv ${DIR_SCRATCH}/${PREFIX}_from-${FROM}_to-${TO}_xfm-stack.nii.gz ${DIR_XFM}/
fi

#==============================================================================
# End of function
#==============================================================================
exit 0

